import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_ui.dart';
import 'group_widgets.dart';

// the competition with another group (design: GroupVS, a navy focus page; the backend is GroupMatchService):
// the owner challenges a similar group (suggested by the AI) or a group by its invite code,
// the other owner accepts, the match is the next full week, on Sunday the group with the higher % of times done wins
class MatchTab extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final bool isOwner;
  final int? me;
  final VoidCallback? onChanged; // the header shows the competition

  const MatchTab({super.key, required this.api, required this.groupId, required this.isOwner, this.me, this.onChanged});

  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchData {
  final bool hasGoal;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> board; // my group this week

  _MatchData(this.hasGoal, this.matches, this.board);
}

// the navy page colors (the same in light and dark)
const _navy = Color(0xFF0A1A3A);
const _navyRaised = Color(0xFF13285A);
const _navyLine = Color(0xFF22386B);
const _onNavy = Color(0xFFEDF1FA);
const _navyMuted = Color(0xFFB7C5E8);
const _navySubtle = Color(0xFF8E9FC9);
const _navyAccent = Color(0xFF7DA6FF);
const _orange = Color(0xFFF57C1F);

class _MatchTabState extends State<MatchTab> with AutomaticKeepAliveClientMixin {
  Key _key = UniqueKey();

  @override
  bool get wantKeepAlive => true;

  Future<_MatchData> _load() async {
    final results = await Future.wait<Object?>([widget.api.activeGoal(widget.groupId), widget.api.matches(widget.groupId)]);
    final matches = results[1] as List<Map<String, dynamic>>;
    // the running one first, then the waiting ones, then the newest
    const order = {'ACTIVE': 0, 'PENDING': 1, 'FINISHED': 2, 'DECLINED': 3};
    matches.sort((a, b) {
      final byStatus = (order[a['status']] ?? 9).compareTo(order[b['status']] ?? 9);
      return byStatus != 0 ? byStatus : (b['id'] as int? ?? 0).compareTo(a['id'] as int? ?? 0);
    });
    final hasGoal = results[0] != null;
    var board = <Map<String, dynamic>>[];
    if (hasGoal) {
      try {
        board = await widget.api.board(widget.groupId);
      } catch (_) {}
    }
    return _MatchData(hasGoal, matches, board);
  }

  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _respond(Map<String, dynamic> match, bool accept) async {
    if (!accept && !await confirm(context, 'ترفض التحدي؟', 'ما راح تبدأ منافسة مع ${match['challengerName']}.', yes: 'ارفض')) return;
    try {
      await widget.api.respondMatch(match['id'] as int, accept);
      if (!mounted) return;
      showMessage(context, accept ? 'قبلتوا التحدي، المنافسة تبدأ الأحد' : 'رفضتوا التحدي');
      _reload();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showGroupError(context, e);
    }
  }

  // "باقي ٣ أيام" / "تبدأ ١/١١" for the running match
  static String? _when(Map<String, dynamic>? match) {
    if (match == null || match['status'] != 'ACTIVE') return null;
    if (_notStarted(match)) return 'تبدأ ${dayAr(match['startDate'])}';
    final end = DateTime.tryParse('${match['endDate']}');
    if (end == null) return null;
    final left = end.difference(_today()).inDays + 1;
    return left <= 1 ? 'آخر يوم' : 'باقي ${arabicDigits(left)} أيام';
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _notStarted(Map<String, dynamic> match) {
    final start = DateTime.tryParse('${match['startDate']}');
    return start != null && _today().isBefore(start);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: _navy,
      child: AsyncView<_MatchData>(
        key: _key,
        load: () => inArabic(_load()),
        builder: (context, data, reload) {
          final active = data.matches.where((m) => m['status'] == 'ACTIVE').firstOrNull;
          final featured = active ?? data.matches.where((m) => m['status'] == 'FINISHED').firstOrNull;
          final incoming = data.matches.where((m) => m['status'] == 'PENDING' && m['opponentId'] == widget.groupId).toList();
          final outgoing = data.matches.where((m) => m['status'] == 'PENDING' && m['challengerId'] == widget.groupId).toList();
          final past = data.matches.where((m) => !identical(m, featured) && (m['status'] == 'FINISHED' || m['status'] == 'DECLINED')).toList();
          // one competition at a time: a running one or a challenge we sent closes the door
          final busy = active != null || outgoing.isNotEmpty;
          // the pill on the title: the days of the running match, or that the shown match is over
          final when = _when(featured) ??
              (featured?['status'] == 'FINISHED' ? 'انتهت ${dayAr(featured!['endDate'])}' : null);
          // our live % this week (the scores are written on Sunday)
          final required = data.board.fold<int>(0, (s, r) => s + ((r['required'] as int?) ?? 0));
          final completed = data.board.fold<int>(0, (s, r) => s + ((r['completed'] as int?) ?? 0));
          final live = required == 0 ? null : (completed * 100 / required).round();
          final started = active != null && !_notStarted(active);
          var i = 0;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s8),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المنافسة', style: text.headlineSmall!.copyWith(color: _onNavy, fontWeight: FontWeight.w800)),
                          Text('أسبوع كامل · الفايز أعلى نسبة إنجاز', style: text.labelSmall!.copyWith(color: _navySubtle)),
                        ],
                      ),
                    ),
                    if (when != null) Pill(when, fg: _onNavy, bg: _navyRaised),
                  ],
                ),
                const SizedBox(height: Space.s3),
                Appear(
                  index: i++,
                  child: featured != null
                      ? _VsHero(match: featured, groupId: widget.groupId, liveOurs: started ? live : null)
                      : _EmptyHero(busy: outgoing.isNotEmpty),
                ),
                if (featured != null) ...[
                  const SizedBox(height: 14),
                  Appear(
                    index: i++,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _NavyCard(
                            label: 'الأقل تسويف',
                            value: featured['status'] == 'FINISHED' ? '${featured['leastProcrastinatingName'] ?? 'تعادل'}' : 'يطلع الأحد',
                            note: 'إثباتاتهم أبكر بالأسبوع · +${arabicDigits(50)}',
                          ),
                        ),
                        const SizedBox(width: Space.s2),
                        Expanded(
                          child: _NavyCard(
                            label: 'الجائزة',
                            value: '+${arabicDigits(100)} نقطة',
                            valueColor: _navyAccent,
                            note: featured['status'] == 'FINISHED' ? _result(featured) : 'لنقاط المجموعة الفايزة',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (started && data.board.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, Space.s4, 4, Space.s2),
                    child: Text('مساهمة مجموعتك', style: text.titleSmall!.copyWith(color: _onNavy, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  for (final r in data.board) ...[
                    Appear(index: i++, child: _ContributionRow(row: r, isMe: r['memberId'] == widget.me)),
                    const SizedBox(height: Space.s2),
                  ],
                ],
                for (final m in incoming) ...[
                  const SizedBox(height: Space.s3),
                  Appear(
                    index: i++,
                    child: _PendingCard(
                      match: m,
                      groupId: widget.groupId,
                      canRespond: widget.isOwner,
                      blockedBy: active == null ? null : 'ما تقدرون تقبلون: عندكم منافسة حاليّة',
                      onAccept: () => _respond(m, true),
                      onDecline: () => _respond(m, false),
                    ),
                  ),
                ],
                for (final m in outgoing) ...[
                  const SizedBox(height: Space.s3),
                  Appear(index: i++, child: _PendingCard(match: m, groupId: widget.groupId, canRespond: false, onAccept: () {}, onDecline: () {})),
                ],
                const SizedBox(height: Space.s4),
                Appear(
                  index: i++,
                  child: widget.isOwner
                      ? _ChallengePanel(
                          api: widget.api,
                          groupId: widget.groupId,
                          // why the owner cannot challenge now, short
                          locked: !data.hasGoal
                              ? 'ما عندكم هدف شغّال'
                              : active != null
                                  ? 'عندكم منافسة حاليّة'
                                  : outgoing.isNotEmpty
                                      ? 'في انتظار الرد على تحدي مرسل'
                                      : null,
                          onSent: () {
                            showMessage(context, 'وصل التحدي، ننتظر رد منشئ المجموعة الثانية');
                            _reload();
                          },
                        )
                      : _LockedNote(
                          icon: Icons.person_outline_rounded,
                          text: 'منشئ المجموعة هو اللي يتحدى المجموعات ويرد على التحديات. شجّعوه!',
                        ),
                ),
                const SizedBox(height: Space.s3),
                const _RulesCard(),
                if (past.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, Space.s5, 4, Space.s2),
                    child: Text('منافسات قبل', style: text.titleSmall!.copyWith(color: _onNavy, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  for (final m in past) ...[
                    _PastMatch(match: m, groupId: widget.groupId),
                    const SizedBox(height: Space.s2),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _result(Map<String, dynamic> m) {
    final weChallenged = m['challengerId'] == widget.groupId;
    final us = '${weChallenged ? m['challengerName'] : m['opponentName']}';
    if (m['winnerName'] == null) return 'تعادل!';
    return m['winnerName'] == us ? 'فزتوا وأخذتوها 🏆' : 'المرة الجاية لكم';
  }
}

// a message on the navy page with a lock or a person
class _LockedNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LockedNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _navyRaised, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: _navyLine)),
      child: Row(
        children: [
          Icon(icon, color: _navyAccent),
          const SizedBox(width: Space.s3),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: _navyMuted, height: 1.6))),
        ],
      ),
    );
  }
}

// the owner challenges: a group by its invite code, or one the AI suggests
class _ChallengePanel extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final String? locked; // why the owner cannot challenge now
  final VoidCallback onSent;

  const _ChallengePanel({required this.api, required this.groupId, required this.locked, required this.onSent});

  @override
  State<_ChallengePanel> createState() => _ChallengePanelState();
}

class _ChallengePanelState extends State<_ChallengePanel> {
  final _code = TextEditingController();
  List<Map<String, dynamic>>? _suggestions;
  bool _suggesting = false;
  bool _sending = false;
  int? _challenging;
  String? _error;
  bool _why = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    setState(() {
      _suggesting = true;
      _error = null;
    });
    try {
      final list = await widget.api.matchSuggestions(widget.groupId);
      if (mounted) setState(() => _suggestions = list);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _challenge({int? groupId, String? code}) async {
    setState(() {
      _error = null;
      if (groupId != null) _challenging = groupId;
      if (code != null) _sending = true;
    });
    try {
      await widget.api.challenge(widget.groupId, opponentGroupId: groupId, inviteCode: code);
      if (mounted) widget.onSent();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() {
        _challenging = null;
        _sending = false;
      });
    }
  }

  void _sendCode() {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'اكتب كود دعوة المجموعة اللي تبي تتحداها');
      return;
    }
    FocusScope.of(context).unfocus();
    _challenge(code: code);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final locked = widget.locked;
    final suggestions = _suggestions;
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: _navyRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: locked == null ? _navyAccent.withValues(alpha: 0.5) : _navyLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(locked == null ? Icons.sports_kabaddi_rounded : Icons.lock_rounded, color: locked == null ? _orange : _navySubtle),
              const SizedBox(width: Space.s2),
              Expanded(child: Text('تحدّوا مجموعة', style: text.titleMedium!.copyWith(color: _onNavy, fontWeight: FontWeight.w800))),
            ],
          ),
          if (locked != null) ...[
            const SizedBox(height: Space.s2),
            Row(
              children: [
                Text('ما تقدرون تتحدون الحين: ', style: text.bodySmall!.copyWith(color: _navySubtle)),
                Flexible(child: Pill(locked, fg: const Color(0xFFF5A55A), bg: const Color(0xFF3A2A16))),
              ],
            ),
          ] else ...[
            const SizedBox(height: Space.s3),
            Text('بكود دعوة المجموعة', style: text.labelMedium!.copyWith(color: _navyMuted)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: text.titleMedium!.copyWith(color: _onNavy, letterSpacing: 2),
                    cursorColor: _navyAccent,
                    onSubmitted: (_) => _sendCode(),
                    decoration: InputDecoration(
                      hintText: 'AB12CD34',
                      hintStyle: text.titleMedium!.copyWith(color: _navySubtle.withValues(alpha: 0.6), letterSpacing: 2),
                      filled: true,
                      fillColor: _navy,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: const BorderSide(color: _navyLine)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: const BorderSide(color: _navyLine)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: const BorderSide(color: _navyAccent, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: Space.s2),
                SizedBox(width: 104, child: _LightButton('تحدّ', icon: Icons.bolt_rounded, loading: _sending, onPressed: _sending ? null : _sendCode)),
              ],
            ),
            const SizedBox(height: Space.s4),
            Row(
              children: [
                Expanded(child: Container(height: 1, color: _navyLine)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: Space.s2), child: Text('أو', style: text.labelSmall!.copyWith(color: _navySubtle))),
                Expanded(child: Container(height: 1, color: _navyLine)),
              ],
            ),
            const SizedBox(height: Space.s3),
            Material(
              color: const Color(0xFF2A2160),
              borderRadius: BorderRadius.circular(Radii.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.lg),
                onTap: _suggesting ? null : _suggest,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  alignment: Alignment.center,
                  child: _suggesting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCFC3FA)))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFCFC3FA)),
                          const SizedBox(width: 6),
                          Text(suggestions == null ? 'اقترح علي مجموعات بالذكاء' : 'اقترح مرة ثانية',
                              style: text.labelLarge!.copyWith(color: const Color(0xFFCFC3FA), fontWeight: FontWeight.w700)),
                        ]),
                ),
              ),
            ),
            // on what the AI suggests (GroupMatchService.suggestOpponents)
            TextButton.icon(
              onPressed: () => setState(() => _why = !_why),
              style: TextButton.styleFrom(foregroundColor: _navySubtle),
              icon: Icon(_why ? Icons.expand_less_rounded : Icons.help_outline_rounded, size: 18),
              label: const Text('على أي أساس يقترح الذكاء؟'),
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.easeOut,
              child: !_why
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: Space.s2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in [
                            'المجموعة عندها هدف شغّال وفيها عضوين أو أكثر، ومو بينكم تحدي مفتوح.',
                            'الذكاء يقارن هدفكم بهدفهم ويعطي نسبة تشابه (مثل القراءة والمذاكرة متشابهة، والقراءة والحديد لا).',
                            'تنقص النسبة ٣ عن كل فرق مرة بالأسبوع، و٢ عن كل فرق عضو، عشان تكون المنافسة عادلة.',
                            'نعرض اللي نسبتها ٦٥٪ أو أكثر، أفضل ٥ بس.',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: _navyAccent)),
                                const SizedBox(width: Space.s2),
                                Expanded(child: Text(line, style: text.bodySmall!.copyWith(color: _navyMuted, height: 1.6))),
                              ]),
                            ),
                        ],
                      ),
                    ),
            ),
            if (suggestions != null && suggestions.isEmpty)
              Text('ما لقينا مجموعات قريبة منكم الحين. جرّبوا بكود دعوة مجموعة أصحابكم.', style: text.bodySmall!.copyWith(color: _navyMuted), textAlign: TextAlign.center),
            if (suggestions != null)
              for (final (i, g) in suggestions.indexed) ...[
                Appear(
                  index: i,
                  child: _Suggestion(
                    group: g,
                    loading: _challenging == g['groupId'],
                    onChallenge: _challenging != null ? null : () => _challenge(groupId: g['groupId'] as int),
                  ),
                ),
                const SizedBox(height: Space.s2),
              ],
          ],
          if (_error != null) ...[
            const SizedBox(height: Space.s2),
            Container(
              padding: const EdgeInsets.all(Space.s3),
              decoration: BoxDecoration(color: const Color(0xFF3A1D1B), borderRadius: BorderRadius.circular(Radii.md)),
              child: Text(_error!, style: text.bodySmall!.copyWith(color: const Color(0xFFF2857A))),
            ),
          ],
        ],
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool loading;
  final VoidCallback? onChallenge;

  const _Suggestion({required this.group, required this.loading, required this.onChallenge});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final score = (group['compatibilityScore'] as int?) ?? 0;
    final reason = '${group['reason'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TeamAvatar(name: '${group['name'] ?? ''}', color: teamColor(group['groupId']), size: 40),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${group['name'] ?? ''}', style: text.titleSmall!.copyWith(color: _onNavy, fontWeight: FontWeight.w700)),
                    Text(
                      '${group['goalTitle'] ?? ''} · ${arabicDigits(group['membersCount'] ?? 0)} أعضاء',
                      style: text.labelSmall!.copyWith(color: _navySubtle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // the similarity ring
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: score / 100),
                        duration: Motion.sign,
                        curve: Motion.easeOut,
                        builder: (context, v, _) => CircularProgressIndicator(value: v, strokeWidth: 4, color: _navyAccent, backgroundColor: _navyRaised),
                      ),
                    ),
                    Text('${arabicDigits(score)}٪', style: text.labelSmall!.copyWith(color: _onNavy, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty && reason != 'Similar group goals') ...[
            const SizedBox(height: Space.s2),
            Text(reason, style: text.bodySmall!.copyWith(color: _navyMuted)),
          ],
          const SizedBox(height: Space.s2),
          _LightButton('تحدّهم', icon: Icons.sports_kabaddi_rounded, loading: loading, onPressed: onChallenge),
        ],
      ),
    );
  }
}

// our side and theirs, «ضد» in the middle
class _VsHero extends StatelessWidget {
  final Map<String, dynamic> match;
  final int groupId;
  final int? liveOurs; // our % this week while it runs (the scores are written on Sunday)

  const _VsHero({required this.match, required this.groupId, this.liveOurs});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final weChallenged = match['challengerId'] == groupId;
    final theirId = weChallenged ? match['opponentId'] : match['challengerId'];
    final us = '${weChallenged ? match['challengerName'] : match['opponentName']}';
    final them = '${weChallenged ? match['opponentName'] : match['challengerName']}';
    final finished = match['status'] == 'FINISHED';
    final ours = finished ? (weChallenged ? match['challengerScore'] : match['opponentScore']) as int? : liveOurs;
    final theirs = finished ? (weChallenged ? match['opponentScore'] : match['challengerScore']) as int? : null;
    final ourColor = teamColor(groupId);
    var theirColor = teamColor(theirId);
    if (theirColor == ourColor) theirColor = AtColors.team(AtColors.teams.indexOf(ourColor) + 1);
    final motion = !reduceMotion(context);

    Widget side(String name, int? score, String? note, Color color, bool winner, EdgeInsetsGeometry padding, double from) {
      final content = Container(
        color: color,
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                TeamAvatar(name: name, color: color, size: 60, onColor: true),
                if (finished && winner)
                  const PositionedDirectional(top: -12, end: -12, child: Pulse(scale: 1.2, child: Text('🏆', style: TextStyle(fontSize: 24)))),
              ],
            ),
            const SizedBox(height: 6),
            // a long name takes two lines instead of being cut
            Text(name,
                style: text.labelLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            score == null
                ? Text('؟', style: text.displayLarge!.copyWith(color: Colors.white70, fontSize: 42, height: 1))
                : CountUp(score, suffix: '٪', style: text.displayLarge!.copyWith(color: Colors.white, fontSize: 42, height: 1)),
            if (note != null) Text(note, style: text.labelSmall!.copyWith(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
      if (!motion) return content;
      // the two sides slide in and meet in the middle
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 600),
        curve: Motion.easeOut,
        builder: (context, t, child) => FractionalTranslation(translation: Offset(from * t, 0), child: child),
        child: content,
      );
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final running = !finished;
    return Semantics(
      label: '$us ${ours ?? ''}٪ ضد $them ${theirs ?? ''}٪',
      child: SizedBox(
        height: 230,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: side(us, ours, running ? 'نسبتكم الحين' : null, ourColor, match['winnerName'] == us,
                        const EdgeInsetsDirectional.only(end: 20, start: 8), rtl ? 1 : -1),
                  ),
                  Expanded(
                    child: side(them, theirs, running ? 'تنكشف الأحد' : null, theirColor, match['winnerName'] == them,
                        const EdgeInsetsDirectional.only(start: 20, end: 8), rtl ? -1 : 1),
                  ),
                ],
              ),
              Center(
                child: Pulse(
                  scale: running ? 1.1 : 1,
                  period: const Duration(milliseconds: 900),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _orange,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _navy, spreadRadius: 6)],
                    ),
                    child: Text('ضد', style: text.titleMedium!.copyWith(color: _navy, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  final bool busy; // we sent a challenge and wait

  const _EmptyHero({required this.busy});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s5, vertical: Space.s8),
      decoration: BoxDecoration(color: _navyRaised, borderRadius: BorderRadius.circular(26)),
      child: Column(
        children: [
          Pulse(scale: 1.1, child: Icon(busy ? Icons.hourglass_top_rounded : Icons.emoji_events_rounded, size: 48, color: busy ? _orange : _navyAccent)),
          const SizedBox(height: Space.s3),
          Text(busy ? 'ننتظر ردّهم' : 'ما فيه منافسة الحين', style: text.titleMedium!.copyWith(color: _onNavy, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(busy ? 'أول ما يقبلون تبدأ المنافسة الأحد الجاي.' : 'تحدّوا مجموعة ثانية أسبوع كامل، واللي تكمّل نسبة أعلى تفوز.',
              style: text.bodySmall!.copyWith(color: _navySubtle), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _NavyCard extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final Color valueColor;

  const _NavyCard({required this.label, required this.value, required this.note, this.valueColor = _onNavy});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(color: _navyRaised, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall!.copyWith(color: _navyMuted)),
          Text(value, style: text.titleMedium!.copyWith(color: valueColor, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(note, style: text.labelSmall!.copyWith(color: _navySubtle)),
        ],
      ),
    );
  }
}

// one member of my group: his done times this week
class _ContributionRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isMe;

  const _ContributionRow({required this.row, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final required = (row['required'] as int?) ?? 0;
    final completed = (row['completed'] as int?) ?? 0;
    final share = required == 0 ? 0.0 : (completed / required).clamp(0.0, 1.0);
    final name = '${row['name'] ?? ''}';
    return Semantics(
      label: '${isMe ? 'أنت' : name} $completed من $required',
      child: Row(
        children: [
          MemberAvatar(name, size: 34, ring: isMe ? _navyAccent : null, gap: _navy),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.full),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 12,
                backgroundColor: _navyRaised,
                color: share >= 0.7 || completed == required ? _navyAccent : const Color(0xFFF57C1F),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text('${arabicDigits(completed)}/${arabicDigits(required)}', style: text.labelMedium!.copyWith(color: _onNavy, fontWeight: FontWeight.w700), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// a challenge waiting for an answer
class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final int groupId;
  final bool canRespond;
  final String? blockedBy; // why we cannot accept now
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PendingCard({required this.match, required this.groupId, required this.canRespond, required this.onAccept, required this.onDecline, this.blockedBy});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final weChallenged = match['challengerId'] == groupId;
    final them = '${weChallenged ? match['opponentName'] : match['challengerName']}';
    final theirId = weChallenged ? match['opponentId'] : match['challengerId'];
    final theirTimes = weChallenged ? match['opponentTimesPerWeek'] : match['challengerTimesPerWeek'];
    final ourTimes = weChallenged ? match['challengerTimesPerWeek'] : match['opponentTimesPerWeek'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navyRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: !weChallenged && canRespond ? Border.all(color: _orange, width: 2) : Border.all(color: _navyLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TeamAvatar(name: them, color: teamColor(theirId), size: 40),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weChallenged ? 'تحدّيتوا $them' : 'تحدّي جديد من $them', style: text.titleSmall!.copyWith(color: _onNavy, fontWeight: FontWeight.w700)),
                    Text(
                      weChallenged
                          ? 'ننتظر رد منشئ مجموعتهم، والمنافسة تبدأ الأحد اللي بعد ما يقبلون.'
                          : canRespond
                              ? 'أسبوع كامل يبدأ الأحد الجاي. تقبلون؟'
                              : 'منافسة جديدة غير اللي فوق، ومنشئ مجموعتكم هو اللي يقبلها أو يرفضها.',
                      style: text.labelSmall!.copyWith(color: _navySubtle),
                    ),
                  ],
                ),
              ),
              const Pill('بانتظار الرد', fg: Color(0xFFF5A55A), bg: Color(0xFF3A2A16)),
            ],
          ),
          // who they are: their name and how many times a week their goal asks, next to ours
          const SizedBox(height: Space.s3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(them,
                        style: text.labelLarge!.copyWith(color: _onNavy, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      const Icon(Icons.repeat_rounded, size: 14, color: _navySubtle),
                      const SizedBox(width: 4),
                      Text(theirTimes == null ? 'ما عندهم هدف الحين' : '${arabicDigits(theirTimes)} مرات بالأسبوع',
                          style: text.labelSmall!.copyWith(color: _navySubtle)),
                    ]),
                  ]),
                ),
                if (ourTimes != null) ...[
                  const SizedBox(width: 8),
                  Text('إحنا ${arabicDigits(ourTimes)} مرات', style: text.labelSmall!.copyWith(color: _navyMuted)),
                ],
              ],
            ),
          ),
          if (!weChallenged && canRespond && blockedBy != null) ...[
            const SizedBox(height: Space.s2),
            Text(blockedBy!, style: text.labelSmall!.copyWith(color: const Color(0xFFF5A55A))),
          ],
          if (!weChallenged && canRespond) ...[
            const SizedBox(height: Space.s3),
            Row(
              children: [
                Expanded(child: _LightButton('قبول', icon: Icons.check_rounded, onPressed: blockedBy == null ? onAccept : null)),
                const SizedBox(width: Space.s2),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: _navyMuted, minimumSize: const Size.fromHeight(48)),
                    onPressed: onDecline,
                    child: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PastMatch extends StatelessWidget {
  final Map<String, dynamic> match;
  final int groupId;

  const _PastMatch({required this.match, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final weChallenged = match['challengerId'] == groupId;
    final us = '${weChallenged ? match['challengerName'] : match['opponentName']}';
    final them = '${weChallenged ? match['opponentName'] : match['challengerName']}';
    final ours = weChallenged ? match['challengerScore'] : match['opponentScore'];
    final theirs = weChallenged ? match['opponentScore'] : match['challengerScore'];
    final declined = match['status'] == 'DECLINED';
    final won = match['winnerName'] == us;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.s3),
      decoration: BoxDecoration(color: _navyRaised, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ضد $them', style: text.labelLarge!.copyWith(color: _onNavy)),
                Text(
                  declined
                      ? 'انرفض التحدي'
                      : match['startDate'] == null
                          ? ''
                          : '${dayAr(match['startDate'])} - ${dayAr(match['endDate'])}',
                  style: text.labelSmall!.copyWith(color: _navySubtle),
                ),
              ],
            ),
          ),
          if (!declined && ours != null && theirs != null)
            Text('${arabicDigits(ours)}٪ – ${arabicDigits(theirs)}٪', style: text.titleSmall!.copyWith(color: won ? _navyAccent : _onNavy, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget line(IconData icon, String value) => Padding(
          padding: const EdgeInsets.only(top: Space.s2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: _navyAccent),
            const SizedBox(width: Space.s2),
            Expanded(child: Text(value, style: text.bodySmall!.copyWith(color: _navyMuted))),
          ]),
        );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      // a Material (not a colored box) so the tile's ink and background show on it
      child: Material(
        color: _navyRaised,
        borderRadius: BorderRadius.circular(Radii.lg),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          iconColor: _onNavy,
          collapsedIconColor: _navyMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text('كيف تمشي المنافسة؟', style: text.labelLarge!.copyWith(color: _onNavy)),
          children: [
            line(Icons.groups_outlined, 'نقترح عليكم مجموعات أهدافها شبه هدفكم، أو تتحدون مجموعة بكود دعوتها.'),
            line(Icons.calendar_month_outlined, 'المنافسة أسبوع كامل، تبدأ الأحد اللي بعد ما توافق المجموعة الثانية.'),
            line(Icons.looks_one_outlined, 'منافسة وحدة بس بنفس الوقت، ولازم أهداف المجموعتين تكمّل لين نهاية أسبوع المنافسة.'),
            line(Icons.bolt_outlined, 'الأقل تسويف (إثباتاتهم أبكر بالأسبوع) ياخذ ${arabicDigits(50)} نقطة.'),
            line(Icons.percent, 'الفايز اللي تكمّل نسبة أعلى من مرات هدفها. الفايز ياخذ ${arabicDigits(100)} نقطة.'),
            line(Icons.check_circle_outline, 'لو كل أعضاء المجموعة كمّلوا مراتهم تاخذ ${arabicDigits(30)} نقطة زيادة.'),
          ],
        ),
      ),
    );
  }
}

// the light button on the navy page (stands on a dark 4px edge)
class _LightButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const _LightButton(this.label, {this.icon, required this.onPressed, this.loading = false});

  @override
  State<_LightButton> createState() => _LightButtonState();
}

class _LightButtonState extends State<_LightButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1C46C9);
    final enabled = widget.onPressed != null && !widget.loading;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: widget.onPressed == null && !widget.loading ? 0.45 : 1,
          child: AnimatedContainer(
            duration: Motion.fast,
            constraints: const BoxConstraints(minHeight: 50),
            margin: EdgeInsets.only(top: _down ? 4 : 0, bottom: _down ? 0 : 4),
            padding: const EdgeInsets.symmetric(horizontal: Space.s3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: _down ? null : [BoxShadow(color: edgeOf(_navy), offset: const Offset(0, 4))],
            ),
            child: widget.loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: blue))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[Icon(widget.icon, color: blue, size: 20), const SizedBox(width: 6)],
                      Flexible(
                        child: Text(widget.label,
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: blue, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
