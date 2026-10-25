import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_widgets.dart';

// the competition with another group (the backend is GroupMatchService):
// the owner challenges a similar group (suggested by the AI) or a group by its invite code,
// the other owner accepts, the match is the next full week, on Sunday the group with the higher % of times done wins
class MatchTab extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final bool isOwner;

  const MatchTab({super.key, required this.api, required this.groupId, required this.isOwner});

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchData {
  final bool hasGoal;
  final List<Map<String, dynamic>> matches;

  _MatchData(this.hasGoal, this.matches);
}

class _MatchTabState extends State<MatchTab> with AutomaticKeepAliveClientMixin {
  Key _key = UniqueKey();

  @override
  bool get wantKeepAlive => true;

  Future<_MatchData> _load() async {
    final results = await Future.wait([widget.api.activeGoal(widget.groupId), widget.api.matches(widget.groupId)]);
    final matches = results[1] as List<Map<String, dynamic>>;
    // the open ones first, then the newest
    const order = {'PENDING': 0, 'ACTIVE': 1, 'FINISHED': 2, 'DECLINED': 3};
    matches.sort((a, b) {
      final byStatus = (order[a['status']] ?? 9).compareTo(order[b['status']] ?? 9);
      return byStatus != 0 ? byStatus : (b['id'] as int? ?? 0).compareTo(a['id'] as int? ?? 0);
    });
    return _MatchData(results[0] != null, matches);
  }

  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _findOpponent() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ChallengeSheet(api: widget.api, groupId: widget.groupId),
    );
    if (sent == true && mounted) {
      showMessage(context, 'وصل التحدي، ننتظر رد منشئ المجموعة الثانية');
      _reload();
    }
  }

  Future<void> _respond(Map<String, dynamic> match, bool accept) async {
    if (!accept && !await confirm(context, 'ترفض التحدي؟', 'ما راح تبدأ منافسة مع ${match['challengerName']}.')) return;
    try {
      await widget.api.respondMatch(match['id'] as int, accept);
      if (!mounted) return;
      showMessage(context, accept ? 'قبلتوا التحدي، المنافسة تبدأ الأحد الجاي' : 'رفضتوا التحدي');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return AsyncView<_MatchData>(
      key: _key,
      load: _load,
      builder: (context, data, reload) {
        final open = data.matches.any((m) => m['status'] == 'PENDING' || m['status'] == 'ACTIVE');
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(Space.s4),
            children: [
              const _RulesCard(),
              const SizedBox(height: Space.s4),
              if (!data.hasGoal)
                Text('لازم يكون عند مجموعتكم هدف شغّال عشان تتحدون مجموعة ثانية.', style: text.bodySmall, textAlign: TextAlign.center)
              else if (widget.isOwner)
                AtButton(open ? 'تحدّ مجموعة ثانية' : 'ابحث عن مجموعة تتحداها',
                    icon: const Icon(Icons.sports_kabaddi_outlined), kind: open ? AtButtonKind.outline : AtButtonKind.primary, onPressed: _findOpponent)
              else
                Text('منشئ المجموعة هو اللي يرسل التحدي ويرد عليه.', style: text.bodySmall, textAlign: TextAlign.center),
              if (data.matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: Space.s8),
                  child: EmptyView(message: 'ما فيه منافسات للحين', icon: Icons.emoji_events_outlined),
                )
              else ...[
                const SectionTitle('المنافسات'),
                for (final m in data.matches) ...[
                  _MatchCard(
                    match: m,
                    groupId: widget.groupId,
                    canRespond: widget.isOwner && m['status'] == 'PENDING' && m['opponentId'] == widget.groupId,
                    onAccept: () => _respond(m, true),
                    onDecline: () => _respond(m, false),
                  ),
                  const SizedBox(height: Space.s3),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    Widget line(IconData icon, String value) => Padding(
          padding: const EdgeInsets.only(top: Space.s2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: c.primary),
            const SizedBox(width: Space.s2),
            Expanded(child: Text(value, style: text.bodySmall)),
          ]),
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تحدّوا مجموعة ثانية', style: text.titleMedium),
          line(Icons.groups_outlined, 'نقترح عليكم مجموعات أهدافها شبه هدفكم، أو تتحدون مجموعة بكود دعوتها.'),
          line(Icons.calendar_month_outlined, 'المنافسة أسبوع كامل، تبدأ الأحد اللي بعد ما توافق المجموعة الثانية.'),
          line(Icons.percent, 'الفايز اللي تكمّل نسبة أعلى من مرات هدفها. الفايز ياخذ ${arabicDigits(100)} نقطة.'),
          line(Icons.check_circle_outline, 'لو كل أعضاء المجموعة كمّلوا مراتهم تاخذ ${arabicDigits(30)} نقطة زيادة.'),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final int groupId;
  final bool canRespond;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _MatchCard({required this.match, required this.groupId, required this.canRespond, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final weChallenged = match['challengerId'] == groupId;
    final us = '${weChallenged ? match['challengerName'] : match['opponentName']}';
    final them = '${weChallenged ? match['opponentName'] : match['challengerName']}';
    final ourScore = (weChallenged ? match['challengerScore'] : match['opponentScore']) as int? ?? 0;
    final theirScore = (weChallenged ? match['opponentScore'] : match['challengerScore']) as int? ?? 0;
    final status = '${match['status']}';
    final dates = match['startDate'] == null ? '' : 'من ${dayAr(match['startDate'])} إلى ${dayAr(match['endDate'])}';

    final (String label, Color color) = switch (status) {
      'PENDING' => ('بانتظار الرد', c.goldText),
      'ACTIVE' => ('شغّالة', c.primary),
      'FINISHED' => ('انتهت', c.inkSubtle),
      _ => ('مرفوضة', c.danger),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('ضد $them', style: text.titleMedium)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.sm)),
              child: Text(label, style: text.labelSmall!.copyWith(color: color)),
            ),
          ]),
          const SizedBox(height: Space.s2),
          if (status == 'PENDING')
            Text(
              weChallenged
                  ? 'أرسلتوا التحدي، ننتظر رد منشئ مجموعة $them.'
                  : canRespond
                      ? 'مجموعة $them تتحداكم أسبوع كامل. تقبلون؟'
                      : 'مجموعة $them تتحداكم، ننتظر رد منشئ المجموعة.',
              style: text.bodySmall,
            ),
          if (canRespond) ...[
            const SizedBox(height: Space.s3),
            Row(children: [
              Expanded(child: AtButton('قبول', icon: const Icon(Icons.check), onPressed: onAccept)),
              const SizedBox(width: Space.s2),
              Expanded(child: AtButton('رفض', kind: AtButtonKind.outline, onPressed: onDecline)),
            ]),
          ],
          if (status == 'ACTIVE')
            Text('$dates. النتيجة تطلع يوم الأحد بعد نهاية الأسبوع، كمّلوا مراتكم!', style: text.bodySmall),
          if (status == 'FINISHED') ...[
            Text(dates, style: text.labelSmall),
            const SizedBox(height: Space.s3),
            _ScoreBar(name: us, score: ourScore, color: c.shadda, bold: true),
            const SizedBox(height: Space.s2),
            _ScoreBar(name: them, score: theirScore, color: c.inkSubtle),
            const SizedBox(height: Space.s3),
            Text(
              match['winnerName'] == null
                  ? 'تعادل!'
                  : match['winnerName'] == us
                      ? 'فزتوا 🏆 وأخذتوا ${arabicDigits(100)} نقطة'
                      : 'فازت $them، المرة الجاية لكم',
              style: text.titleSmall,
            ),
            if (match['leastProcrastinatingName'] != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.s1),
                child: Text('الأقل تسويف: ${match['leastProcrastinatingName']} (إثباتاتهم أبكر بالأسبوع)', style: text.bodySmall),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  final bool bold;

  const _ScoreBar({required this.name, required this.score, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(name, style: bold ? text.labelLarge : text.bodySmall)),
        Text('${arabicDigits(score)}٪', style: text.labelLarge),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sm),
        child: LinearProgressIndicator(value: (score / 100).clamp(0.0, 1.0), minHeight: 8, color: color, backgroundColor: color.withValues(alpha: 0.15)),
      ),
    ]);
  }
}

// the owner picks an opponent: the AI suggestions, or a group by its invite code
class _ChallengeSheet extends StatefulWidget {
  final GroupApi api;
  final int groupId;

  const _ChallengeSheet({required this.api, required this.groupId});

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  final _code = TextEditingController();
  List<Map<String, dynamic>>? _suggestions;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    try {
      final list = await widget.api.matchSuggestions(widget.groupId);
      if (mounted) setState(() => _suggestions = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _error = errorText(e);
        });
      }
    }
  }

  Future<void> _challenge({int? groupId, String? code}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.challenge(widget.groupId, opponentGroupId: groupId, inviteCode: code);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final suggestions = _suggestions;
    return SheetBody(
      title: 'مين تتحدون؟',
      error: _error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('مجموعات أهدافها شبه هدفكم', style: text.labelLarge),
          const SizedBox(height: Space.s2),
          if (suggestions == null)
            const Padding(padding: EdgeInsets.all(Space.s4), child: Center(child: CircularProgressIndicator()))
          else if (suggestions.isEmpty)
            Text('ما لقينا مجموعات شبهكم الحين، تقدرون تتحدون مجموعة بكود دعوتها.', style: text.bodySmall)
          else
            for (final s in suggestions)
              Container(
                margin: const EdgeInsets.only(bottom: Space.s2),
                padding: const EdgeInsets.all(Space.s3),
                decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['name']}', style: text.titleSmall),
                      Text(
                        '${s['goalTitle'] ?? ''} · ${proofMethodsAr[s['proofMethod']] ?? ''} · ${arabicDigits(s['membersCount'] ?? 0)} أعضاء',
                        style: text.labelSmall,
                      ),
                      if (s['reason'] != null && s['reason'] != 'Similar group goals')
                        Text('${s['reason']}', style: text.bodySmall),
                      Text('التشابه ${arabicDigits(s['compatibilityScore'] ?? 0)}٪', style: text.labelSmall!.copyWith(color: c.primary)),
                    ]),
                  ),
                  const SizedBox(width: Space.s2),
                  AtButton('تحدّ', expand: false, loading: _busy, onPressed: _busy ? null : () => _challenge(groupId: s['groupId'] as int)),
                ]),
              ),
          const SizedBox(height: Space.s4),
          Text('أو بكود دعوة المجموعة', style: text.labelLarge),
          const SizedBox(height: Space.s2),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'مثلًا AB12CD34'),
          ),
          const SizedBox(height: Space.s3),
          AtButton('أرسل التحدي', loading: _busy, onPressed: _busy
              ? null
              : () {
                  final code = _code.text.trim();
                  if (code.isEmpty) {
                    setState(() => _error = 'اكتب كود دعوة المجموعة');
                    return;
                  }
                  _challenge(code: code);
                }),
        ],
      ),
    );
  }
}
