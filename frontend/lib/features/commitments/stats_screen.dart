import 'package:flutter/material.dart';
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
      showMessage(context, 'بدّلت ١٥٠ نقطة بيوم سماح.');
      setState(() => _version++);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _earning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مستواي ونقاطي'),
        actions: [
          IconButton(
            tooltip: 'ملخص الشهر',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => context.push('/wrapped'),
          ),
        ],
      ),
      body: AsyncView<JsonMap>(
        key: ValueKey(_version),
        load: _load,
        builder: (context, data, reload) {
          final s = data['stats'] as JsonMap;
          final grace = data['grace'] as List<JsonMap>;
          final points = data['points'] as List<JsonMap>;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                _LevelCard(stats: s),
                const SizedBox(height: Space.s3),
                _PointsCard(stats: s, earning: _earning, onEarn: _earn),
                SectionTitle('أيام السماح (${arabicDigits(s['availableGraceDays'] ?? 0)} من ${arabicDigits(s['graceDayCapacity'] ?? 0)})'),
                Text('تنصرف تلقائياً أول ما تضيع مرة، وكل يوم ينتهي بعد ٤ أسابيع. يوم واحد بالأسبوع.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Space.s2),
                if (grace.isEmpty)
                  const AppCard(child: Text('ما عندك أيام سماح للحين.'))
                else
                  ...grace.map((g) => Padding(padding: const EdgeInsets.only(bottom: Space.s2), child: _GraceDayTile(day: g))),
                const SectionTitle('سجل النقاط'),
                if (points.isEmpty)
                  const AppCard(child: Text('كل مرة ينقبل إثباتها = +١٠ نقاط.'))
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
                    child: Column(children: points.map((p) => _PointRow(log: p)).toList()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final JsonMap stats;

  const _LevelCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final s = stats;
    final next = s['nextLevel'] as String?;
    final toNext = (s['weeksToNextLevel'] ?? 0) as int;
    final streak = (s['consecutiveWeeks'] ?? 0) as int;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: c.gold, size: 28),
              const SizedBox(width: Space.s2),
              Expanded(child: Text(levelsAr[s['level']] ?? '${s['level']}', style: text.headlineMedium)),
              StatusBadge('${arabicDigits(streak)} أسابيع متتالية', kind: BadgeKind.streak),
            ],
          ),
          const SizedBox(height: Space.s2),
          Text(
            next == null
                ? 'وصلت أعلى مستوى 💪 لك تعهد واحد بدون حجز.'
                : 'باقي ${arabicDigits(toNext)} أسابيع كاملة وتصير ${levelsAr[next] ?? next}. أسبوع فيه تقصير ينزّلك مستوى.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Space.s3),
          InfoRow('أسابيع كاملة', Text(arabicDigits(s['fullWeeks'] ?? 0), style: text.labelLarge)),
          InfoRow('تعهّدات شغّالة', Text(arabicDigits(s['activeCommitments'] ?? 0), style: text.labelLarge)),
          InfoRow('تبرعت لإحسان', RiyalAmount(s['totalDonated'] as num?, style: text.titleSmall)),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final JsonMap stats;
  final bool earning;
  final VoidCallback onEarn;

  const _PointsCard({required this.stats, required this.earning, required this.onEarn});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final points = (stats['points'] ?? 0) as int;
    final toGrace = (stats['pointsToGraceDay'] ?? 150) as int;
    // the automatic switch stops when the member is full, then he can switch by himself
    final canSwitch = points >= 150;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(arabicDigits(points), style: text.titleLarge!.copyWith(color: c.primary)),
              const SizedBox(width: Space.s2),
              Padding(padding: const EdgeInsets.only(bottom: Space.s2), child: Text('نقطة', style: text.bodySmall)),
            ],
          ),
          const SizedBox(height: Space.s2),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(
              value: ((150 - toGrace) / 150).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: c.surfaceSunken,
              color: c.gold,
            ),
          ),
          const SizedBox(height: Space.s1),
          Text('باقي ${arabicDigits(toGrace)} نقطة ليوم سماح (١٥٠ نقطة = يوم)', style: text.labelSmall),
          if (canSwitch) ...[
            const SizedBox(height: Space.s3),
            AtButton('بدّل ١٥٠ نقطة بيوم سماح', kind: AtButtonKind.outline, loading: earning, onPressed: onEarn),
          ],
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
