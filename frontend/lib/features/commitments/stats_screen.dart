import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'commitment_widgets.dart';
import 'commitments_api.dart';

// OWNER: Turki - my level, points, grace days and the points log
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final _api = CommitmentsApi(context.read<ApiClient>());
  int _version = 0;
  bool _earning = false;

  Future<JsonMap> _load() async {
    final values = await Future.wait<Object>([_api.stats(), _api.graceDays(), _api.pointLogs()]);
    return {'stats': values[0], 'grace': values[1], 'points': values[2]};
  }

  Future<void> _earn() async {
    setState(() => _earning = true);
    try {
      await _api.earnGraceDay();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showMessage(context, 'بدّلت ١٥٠ نقطة ببطاقة عفو.');
      setState(() => _version++);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _earning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: AsyncView<JsonMap>(
        key: ValueKey(_version),
        load: _load,
        builder: (context, data, reload) {
          final s = data['stats'] as JsonMap;
          final grace = data['grace'] as List<JsonMap>;
          final points = data['points'] as List<JsonMap>;
          final p = (s['points'] ?? 0) as int;
          final toGrace = (s['pointsToGraceDay'] ?? 150) as int;
          final available = (s['availableGraceDays'] ?? 0) as int;
          final capacity = (s['graceDayCapacity'] ?? 0) as int;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _LevelHeader(stats: s),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Tile(
                              label: 'النقاط',
                              value: Text(arabicDigits(p), style: _big(context, c.success)),
                              footer: '${arabicDigits(toGrace.clamp(0, 150))} على بطاقة العفو الجاية',
                              bar: (150 - toGrace).clamp(0, 150) / 150,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Tile(
                              label: 'بطاقات العفو',
                              value: Wrap(spacing: 4, runSpacing: 4, children: [
                                for (var i = 0; i < (capacity < available ? available : capacity).clamp(1, 6); i++)
                                  Icon(i < available ? Icons.confirmation_number_rounded : Icons.confirmation_number_outlined,
                                      size: 26, color: i < available ? c.pardon : c.pardonSoft),
                              ]),
                              footer: '${arabicDigits(available)} من ${arabicDigits(capacity)} · بطاقة بالأسبوع',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Tile(
                              label: 'أسابيع كاملة',
                              value: Text(arabicDigits(s['fullWeeks'] ?? 0), style: _big(context, c.ink)),
                              footer: '${arabicDigits(s['activeCommitments'] ?? 0)} تعهّدات شغّالة',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Tile(
                              label: 'تبرّعت للخير',
                              value: RiyalAmount(s['totalDonated'] as num?, style: _big(context, c.goldText)),
                              footer: 'لإحسان وجمعيات الخير',
                            ),
                          ),
                        ],
                      ),
                      if (p >= 150) ...[
                        const SizedBox(height: Space.s3),
                        AtButton('بدّل ١٥٠ نقطة ببطاقة عفو',
                            kind: AtButtonKind.outline,
                            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                            loading: _earning,
                            onPressed: _earn),
                      ],
                      const SizedBox(height: Space.s4),
                      FeatureBanner(
                        icon: Icons.auto_awesome_rounded,
                        title: 'ملخص الشهر',
                        subtitle: 'شهرك في قصص',
                        colors: [c.pardon, const Color(0xFF3A2A8F)],
                        onTap: () => context.push('/wrapped'),
                      ),
                      SectionHeader('بطاقات العفو', count: arabicDigits(grace.length)),
                      if (grace.isEmpty)
                        _Quiet(icon: Icons.confirmation_number_outlined, line: 'كل ١٥٠ نقطة = بطاقة عفو')
                      else
                        ...grace.map((g) => Padding(padding: const EdgeInsets.only(bottom: Space.s2), child: _GraceDayTile(day: g))),
                      SectionHeader('سجل النقاط', count: arabicDigits(points.length)),
                      if (points.isEmpty)
                        _Quiet(icon: Icons.stars_outlined, line: 'كل إثبات مقبول = +١٠')
                      else
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
                          child: Column(children: points.map((p) => _PointRow(log: p)).toList()),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

TextStyle _big(BuildContext context, Color color) =>
    Theme.of(context).textTheme.headlineMedium!.copyWith(color: color, fontWeight: FontWeight.w800, fontSize: 26, height: 1.3);

// the navy top (design: Profile): back, my level big, the weeks to the next one, the four levels
class _LevelHeader extends StatelessWidget {
  final JsonMap stats;

  const _LevelHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    const ink = Color(0xFFEDF1FA);
    const soft = Color(0xFFB7C5E8);
    final level = stats['level'] as String?;
    final next = stats['nextLevel'] as String?;
    final toNext = (stats['weeksToNextLevel'] ?? 0) as int;
    final streak = (stats['consecutiveWeeks'] ?? 0) as int;
    final reached = levelOrder.indexOf(level ?? '');
    final progress = next == null ? 1.0 : (streak / (streak + toNext).clamp(1, 999)).clamp(0, 1).toDouble();
    return Container(
      decoration: BoxDecoration(color: c.deep, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Material(
                    color: c.deepRaised,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.maybePop(context),
                      child: const SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back_rounded, color: ink)),
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  Text('مستواي', style: text.headlineSmall!.copyWith(color: ink, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: Space.s5),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: c.deep, spreadRadius: 5), const BoxShadow(color: Color(0xFF8FB4FF), spreadRadius: 9)],
                    ),
                    child: LevelBadge(level, size: 84, showName: false),
                  ),
                  const SizedBox(width: Space.s5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(levelsAr[level] ?? '${level ?? '-'}', style: text.headlineMedium!.copyWith(color: ink, fontWeight: FontWeight.w800)),
                        Text(streak > 0 ? '${arabicDigits(streak)} أسابيع كاملة ورا بعض' : 'أول أسبوع كامل يبدأ عدّادك',
                            style: text.labelSmall!.copyWith(color: soft)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.full),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: Motion.reward,
                            curve: Motion.easeOut,
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              backgroundColor: c.deepRaised,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF8FB4FF)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          next == null ? 'أعلى مستوى، كفو' : '${arabicDigits(toNext)} أسابيع وتصير «${levelsAr[next] ?? next}»',
                          style: text.labelSmall!.copyWith(color: const Color(0xFFE3EAFB)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s5),
              // the ladder
              Row(
                children: [
                  for (final (i, l) in levelOrder.indexed)
                    Expanded(
                      child: Column(
                        children: [
                          Opacity(
                            opacity: i > reached ? 0.55 : 1,
                            child: Container(
                              decoration: i == reached
                                  ? const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF8FB4FF), spreadRadius: 3)])
                                  : null,
                              child: LevelBadge(l, size: 34, showName: false, dimmed: i > reached),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(levelsAr[l] ?? l,
                              style: text.labelSmall!.copyWith(
                                fontSize: 11,
                                color: i == reached ? Colors.white : soft,
                                fontWeight: i == reached ? FontWeight.w700 : FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// a white stat card: a small label, a big value, one short line, maybe a bar
class _Tile extends StatelessWidget {
  final String label;
  final Widget value;
  final String footer;
  final double? bar;

  const _Tile({required this.label, required this.value, required this.footer, this.bar});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
        boxShadow: [BoxShadow(color: c.line, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall),
          const SizedBox(height: 4),
          value,
          if (bar != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.full),
              child: LinearProgressIndicator(value: bar, minHeight: 6, backgroundColor: c.surfaceSunken, valueColor: AlwaysStoppedAnimation(c.accent)),
            ),
          ],
          const SizedBox(height: 6),
          Text(footer, style: text.labelSmall!.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

// an empty list: an icon and one line
class _Quiet extends StatelessWidget {
  final IconData icon;
  final String line;

  const _Quiet({required this.icon, required this.line});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.line)),
      child: Row(
        children: [
          IconTile(icon, size: 40, fg: c.inkSubtle, bg: c.surfaceSunken),
          const SizedBox(width: Space.s3),
          Expanded(child: Text(line, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: c.inkMuted))),
        ],
      ),
    );
  }
}

class _GraceDayTile extends StatelessWidget {
  final JsonMap day;

  const _GraceDayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final used = day['usedAt'] != null;
    final expiresAt = DateTime.tryParse('${day['expiresAt']}');
    final expired = !used && expiresAt != null && expiresAt.isBefore(DateTime.now());
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(graceSourcesAr[day['source']] ?? '${day['source']}', style: text.titleSmall),
                Text(
                  used ? 'استخدمته ${arabicDigits(day['usedAt'])}' : 'ينتهي ${arabicDigits(day['expiresAt'] ?? '-')}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (used)
            const StatusBadge('مستخدم')
          else if (expired)
            const StatusBadge('انتهى', kind: BadgeKind.danger)
          else
            const StatusBadge('متاح', kind: BadgeKind.success),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final JsonMap log;

  const _PointRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final points = (log['points'] ?? 0) as int;
    final date = '${log['createdAt'] ?? ''}'.split('T').first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pointReasonsAr[log['reason']] ?? '${log['reason']}', style: text.labelLarge),
                if (date.isNotEmpty) Text(arabicDigits(date), style: text.labelSmall),
              ],
            ),
          ),
          Text(
            '${points > 0 ? '+' : ''}${arabicDigits(points)}',
            textDirection: TextDirection.ltr,
            style: text.titleSmall!.copyWith(color: points < 0 ? c.danger : c.success),
          ),
        ],
      ),
    );
  }
}
