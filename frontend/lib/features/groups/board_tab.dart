import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../proofs/activity_proof_entry.dart';
import 'group_activity.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_ui.dart';
import 'group_widgets.dart';

// the board (design: GroupBoard): the pardon points, today's alerts, the goal, the ranking of the week (with «نبّه»),
// and the proof button stuck at the bottom.
// when there is no goal (design: GroupVote): the proposals, the votes, and the owner sets the next goal
class BoardTab extends StatefulWidget {
  final GroupApi api;
  final Map<String, dynamic> group;
  final bool isOwner;
  final int? me;
  final VoidCallback onChanged; // reloads the whole group page
  final VoidCallback onInvite; // opens the invite code

  const BoardTab({super.key, required this.api, required this.group, required this.isOwner, required this.me, required this.onChanged, required this.onInvite});

  @override
  State<BoardTab> createState() => _BoardTabState();
}

class _BoardData {
  final Map<String, dynamic>? goal;
  final List<Map<String, dynamic>> board;
  final List<Map<String, dynamic>> proposals;
  final List<Map<String, dynamic>> alerts;
  final Map<int, String> titles; // memberId -> the title of last week

  _BoardData(this.goal, this.board, this.proposals, this.alerts, this.titles);
}

class _BoardTabState extends State<BoardTab> with AutomaticKeepAliveClientMixin {
  _BoardData? _data;
  String? _error;
  Timer? _timer;
  bool _proving = false;
  int get _groupId => widget.group['id'] as int;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
    // live: the votes of the others, and the goal as soon as the owner sets it
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<_BoardData> _load() async {
    final api = widget.api;
    final goal = await api.activeGoal(_groupId);
    final alerts = await api.myAlertsToday(_groupId);
    if (goal == null) return _BoardData(null, const [], await api.proposals(_groupId), alerts, const {});
    final results = await Future.wait([
      api.board(_groupId),
      api.latestTitles(_groupId).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    final titles = <int, String>{};
    for (final t in results[1]) {
      final id = t['memberId'] as int?;
      if (id != null) titles.putIfAbsent(id, () => '${t['title']}');
    }
    return _BoardData(goal, results[0], const [], alerts, titles);
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final data = await _load();
      if (!mounted) return;
      final goalStarted = _data != null && _data!.goal == null && data.goal != null;
      setState(() {
        _data = data;
        _error = null;
      });
      if (goalStarted) widget.onChanged(); // the header (active goal) changes too
    } catch (e) {
      if (mounted && !silent) setState(() => _error = errorText(e));
    }
  }

  // I did my task: opens its proof (the same steps as the today page), then the board refreshes
  Future<void> _prove() async {
    setState(() => _proving = true);
    try {
      final task = await widget.api.myTask(_groupId);
      if (!mounted) return;
      await openActivityProof(context, task);
      await _refresh(silent: true);
    } catch (e) {
      if (mounted) showGroupError(context, e);
    } finally {
      if (mounted) setState(() => _proving = false);
    }
  }

  // the white sheet at the bottom with «سوّيت المهمة؟ وثّق إنجازك»
  Widget? _proveSheet(_BoardData data) {
    final mine = data.board.where((r) => r['memberId'] == widget.me).toList();
    if (data.goal == null || mine.isEmpty) return null; // not in this goal (joined after it started, or left)
    final left = (mine.first['remaining'] as int?) ?? 0;
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: const [BoxShadow(color: Color(0x1410245E), blurRadius: 20, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
          child: AtButton(
            left == 0 ? 'خلّصت مهام هالأسبوع' : 'سوّيت المهمة؟ وثّق إنجازك',
            icon: Icon(left == 0 ? Icons.check_circle : Icons.task_alt),
            onPressed: left == 0 || _proving ? null : _prove,
            loading: _proving,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    if (data == null) return _error != null ? ErrorView(message: _error!, onRetry: _refresh) : const LoadingView();
    final members = (widget.group['membersCount'] as int?) ?? 0;
    final sheet = _proveSheet(data);
    final ranked = _ranked(data.board);
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.s4, 14, Space.s4, Space.s6),
              children: [
                if (widget.group['pointsForGraceDay'] != null)
                  PardonBanner(points: (widget.group['points'] as int?) ?? 0, target: widget.group['pointsForGraceDay'] as int),
                for (final a in data.alerts.where((a) => !GroupActivity.instance.dismissed.contains(a['id']))) ...[
                  const SizedBox(height: 10),
                  _AlertBanner(
                    alert: a,
                    onDismiss: () async {
                      await GroupActivity.instance.dismissAlert(a['id'] as int);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
                if (data.goal != null) ...[
                  const SizedBox(height: 10),
                  _GoalCard(goal: data.goal!, board: data.board),
                  if (data.goal!['proofMethod'] == 'LOCATION') _MyPlaceCard(api: widget.api, groupId: _groupId),
                  const GroupSection('ترتيب هالأسبوع', note: 'يتحدّث مع كل إثبات'),
                  if (sheet == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s3),
                      child: _InfoNote(
                        icon: Icons.info_outline_rounded,
                        text: 'أنت مو داخل هالهدف، تدخل مع الهدف الجاي. تقدر تشجّع المجموعة وتنبّههم.',
                      ),
                    ),
                  for (final (i, row) in ranked.indexed) ...[
                    Appear(
                      index: i,
                      child: _LeaderRow(
                        row: row,
                        place: i + 1,
                        isMe: row['memberId'] == widget.me,
                        title: data.titles[row['memberId']],
                        onAlert: () => _alert(row),
                      ),
                    ),
                    const SizedBox(height: Space.s2),
                  ],
                  Center(child: TextButton(onPressed: () => _showHistory(context), child: const Text('أهداف المجموعة السابقة'))),
                ] else
                  _ProposalsSection(
                    api: widget.api,
                    groupId: _groupId,
                    isOwner: widget.isOwner,
                    membersCount: members,
                    onInvite: widget.onInvite,
                    proposals: data.proposals,
                    onChanged: _refresh,
                    onGoalSet: () {
                      _refresh();
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          ),
        ),
        if (sheet != null) sheet,
      ],
    );
  }

  // the most done first
  static List<Map<String, dynamic>> _ranked(List<Map<String, dynamic>> board) {
    double done(Map<String, dynamic> r) {
      final required = (r['required'] as int?) ?? 0;
      return required == 0 ? 0 : ((r['completed'] as int?) ?? 0) / required;
    }

    return [...board]..sort((a, b) => done(b).compareTo(done(a)));
  }

  Future<void> _alert(Map<String, dynamic> row) async {
    try {
      final res = await widget.api.sendAlert(_groupId, row['memberId'] as int);
      if (!mounted) return;
      showMessage(context, res['isCollective'] == true ? 'انضم تنبيهك لتنبيهات المجموعة' : 'وصل التنبيه لـ ${row['name']}');
    } catch (e) {
      if (mounted) showGroupError(context, e);
    }
  }

  Future<void> _showHistory(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SheetBody(
        title: 'أهداف المجموعة',
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.api.goalHistory(_groupId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 160, child: LoadingView());
            if (snap.hasError) return ErrorView(message: errorText(snap.error!));
            final goals = snap.data!;
            if (goals.isEmpty) return const EmptyView(message: 'ما فيه أهداف للحين.');
            return Column(
              children: [
                for (final g in goals)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${g['title'] ?? ''}'),
                    subtitle: Text('${dayAr(g['startDate'])} - ${dayAr(g['endDate'])}'),
                    trailing: StatusBadge(g['status'] == 'ACTIVE' ? 'شغّال' : 'انتهى', kind: g['status'] == 'ACTIVE' ? BadgeKind.success : BadgeKind.neutral),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.infoSoft, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.info),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: c.ink, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// «تنبيه من سارة»
class _AlertBanner extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onDismiss;

  const _AlertBanner({required this.alert, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
      decoration: BoxDecoration(color: c.urgentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.urgent, shape: BoxShape.circle),
            child: Icon(Icons.notifications_active_rounded, size: 20, color: c.onUrgent),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['isCollective'] == true ? 'تنبيه من المجموعة' : 'تنبيه من ${alert['senderName'] ?? ''}',
                    style: text.labelLarge!.copyWith(color: c.urgentText, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${alert['message'] ?? ''}', style: text.bodySmall!.copyWith(color: c.ink)),
                Text(timeAr(alert['sentAt']), style: text.labelSmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'احذف التنبيه',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 20, color: c.inkSubtle),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ---------- the active goal (a white card) ----------
class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final List<Map<String, dynamic>> board;

  const _GoalCard({required this.goal, required this.board});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final finished = board.where((r) => (r['remaining'] as int? ?? 1) == 0).length;
    Widget chip(IconData icon, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.full)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: c.inkSubtle),
            const SizedBox(width: 4),
            Text(label, style: text.labelSmall!.copyWith(color: c.inkMuted, fontWeight: FontWeight.w600)),
          ]),
        );
    return RaisedCard(
      radius: Radii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('هدف المجموعة', style: text.labelSmall)),
              if (board.isNotEmpty)
                Pill('${arabicDigits(finished)} من ${arabicDigits(board.length)} كمّلوا', fg: c.success, bg: c.successSoft),
            ],
          ),
          const SizedBox(height: 2),
          Text('${goal['title'] ?? ''}', style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
          if ('${goal['details'] ?? ''}'.isNotEmpty) Text('${goal['details']}', style: text.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip(Icons.verified_outlined, proofMethodsAr[goal['proofMethod']] ?? '${goal['proofMethod']}'),
              chip(Icons.repeat_rounded, '${arabicDigits(goal['timesPerWeek'])} مرات بالأسبوع'),
              chip(Icons.calendar_month_outlined, '${arabicDigits(goal['totalWeeks'])} أسابيع'),
              chip(difficultyOf(goal) == 'HARD' ? Icons.local_fire_department_rounded : Icons.person_rounded, 'تحدي ${difficultyAr[difficultyOf(goal)]}'),
              if (goal['targetMinutes'] != null) chip(Icons.timer_outlined, '${arabicDigits(goal['targetMinutes'])} دقيقة'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: c.warningSoft, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    difficultyOf(goal) == 'HARD'
                        ? 'لو أحد سوّف: هو يتبرّع بالمبلغ، والباقين بنصه (٥ أقل شي)'
                        : 'اللي يسوّف هو اللي يتبرّع',
                    style: text.labelMedium!.copyWith(color: c.inkMuted, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: Space.s2),
                RiyalAmount(goal['amountPerTime'] as num?, color: c.goldText, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- one member in the ranking ----------
class _LeaderRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final int place;
  final bool isMe;
  final String? title; // his title of last week
  final VoidCallback onAlert;

  const _LeaderRow({required this.row, required this.place, required this.isMe, required this.title, required this.onAlert});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final remaining = (row['remaining'] as int?) ?? 0;
    final required = (row['required'] as int?) ?? 0;
    final completed = (row['completed'] as int?) ?? 0;
    final hasExcuse = row['hasExcuse'] == true;
    final canAlert = !isMe && remaining > 0 && !hasExcuse;
    final status = '${row['trackStatus']}';
    final name = '${row['name'] ?? ''}';

    final Widget trailing;
    if (hasExcuse) {
      trailing = Pill('عنده عذر', fg: c.info, bg: c.infoSoft);
    } else if (canAlert) {
      trailing = NudgeButton(onPressed: onAlert);
    } else if (remaining == 0) {
      trailing = Pill('كمّل', fg: c.success, bg: c.successSoft);
    } else {
      final (String label, Color fg, Color bg) = switch (status) {
        'MUST_TODAY' => ('لازم اليوم', c.urgentText, c.urgentSoft),
        'LOST_DAY' => ('ضاع يوم', c.danger, c.dangerSoft),
        'SETTLED' => ('خلص الأسبوع', c.info, c.infoSoft),
        _ => ('آمن', c.success, c.successSoft),
      };
      trailing = Pill(label, fg: fg, bg: bg);
    }

    // the one I can alert: his state in words instead of the pips
    final Widget progress;
    if (canAlert) {
      final (String state, Color color) = switch (status) {
        'LOST_DAY' => ('ضاع يوم · ', c.danger),
        'MUST_TODAY' => ('لازم اليوم · ', c.urgentText),
        _ => ('', c.inkSubtle),
      };
      progress = Text('$stateباقي ${arabicDigits(remaining)} من ${arabicDigits(required)}',
          style: text.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w600));
    } else {
      progress = Pips(done: completed, total: required);
    }

    return Semantics(
      label: '${isMe ? 'أنت' : name}، المركز $place، $completed من $required',
      child: RaisedCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        highlight: isMe ? c.primary : null,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(arabicDigits(place), style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            MemberAvatar(name, ring: title == null ? null : titleColor(title)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(isMe ? 'أنت' : name, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (title != null) ...[
                        const SizedBox(width: 6),
                        Pill(titlesAr[title] ?? title!, fg: title == 'TOP_DONOR' ? c.onGold : Colors.white, bg: titleColor(title)),
                      ],
                      if (((row['failureCount'] as int?) ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'ما كمّل أسبوعه مرة، المرة الثانية يطلع من المجموعة',
                          child: Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  progress,
                ],
              ),
            ),
            const SizedBox(width: Space.s2),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ---------- no goal: proposals and votes (design: GroupVote) ----------
class _ProposalsSection extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final bool isOwner;
  final int membersCount;
  final VoidCallback onInvite;
  final List<Map<String, dynamic>> proposals;
  final VoidCallback onChanged;
  final VoidCallback onGoalSet;

  const _ProposalsSection({
    required this.api,
    required this.groupId,
    required this.isOwner,
    required this.membersCount,
    required this.onInvite,
    required this.proposals,
    required this.onChanged,
    required this.onGoalSet,
  });

  @override
  State<_ProposalsSection> createState() => _ProposalsSectionState();
}

class _ProposalsSectionState extends State<_ProposalsSection> {
  bool _aiLoading = false;

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    try {
      await action();
      if (!mounted) return;
      if (done != null) showMessage(context, done);
      widget.onChanged();
    } catch (e) {
      if (mounted) showGroupError(context, e);
    }
  }

  Future<void> _ai() async {
    setState(() => _aiLoading = true);
    await _run(() => widget.api.aiProposals(widget.groupId), 'وصلت اقتراحات الذكاء');
    if (mounted) setState(() => _aiLoading = false);
  }

  Future<void> _propose() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ProposeSheet(api: widget.api, groupId: widget.groupId),
    );
    if (added == true) widget.onChanged();
  }

  Future<void> _setGoal(Map<String, dynamic>? proposal) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SetGoalSheet(api: widget.api, groupId: widget.groupId, proposal: proposal),
    );
    if (saved == true) widget.onGoalSet();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final team = teamColor(widget.groupId);
    final proposals = [...widget.proposals]..sort((a, b) => ((b['votes'] as int?) ?? 0).compareTo((a['votes'] as int?) ?? 0));
    final totalVotes = proposals.fold<int>(0, (sum, p) => sum + ((p['votes'] as int?) ?? 0));
    // a group goal needs 2 members at least (like a chat needs someone to talk to)
    final alone = widget.membersCount < 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (alone) ...[
          const SizedBox(height: Space.s3),
          RaisedCard(
            radius: Radii.card,
            color: c.primarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.group_add_rounded, color: c.primary, size: 32),
                const SizedBox(height: Space.s2),
                Text('أرسل رمز الدعوة لأصحابك', style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                Text('الهدف يبدأ لما يكون بالمجموعة شخصين على الأقل. شارك كود الدعوة أو الباركود.', style: text.bodySmall),
                const SizedBox(height: Space.s3),
                AtButton('أرسل رمز الدعوة', onPressed: widget.onInvite, icon: const Icon(Icons.qr_code_rounded, size: 18)),
              ],
            ),
          ),
        ],
        GroupSection(
          'التصويت على الهدف الجاي',
          note: proposals.isEmpty ? null : 'صوّت ${arabicDigits(totalVotes)} من ${arabicDigits(widget.membersCount)}',
        ),
        if (proposals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s4),
            child: Text('ما فيه اقتراحات للحين. اقترح هدف أو اسأل الذكاء.', style: text.bodySmall, textAlign: TextAlign.center),
          ),
        for (final (i, p) in proposals.indexed) ...[
          Appear(
            index: i,
            child: _ProposalCard(
            proposal: p,
            totalVotes: totalVotes,
            team: team,
            isOwner: widget.isOwner,
            canApprove: !alone,
            onVote: () => _run(() => widget.api.vote(p['id'] as int), 'انحسب صوتك'),
            onApprove: () => _setGoal(p),
            onReject: () => _run(() => widget.api.reject(p['id'] as int), 'انشال الاقتراح'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(child: DashedButton('+ اقترح هدف', onPressed: _propose)),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: c.pardonSoft,
                borderRadius: BorderRadius.circular(Radii.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  onTap: _aiLoading ? null : _ai,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 50),
                    alignment: Alignment.center,
                    child: _aiLoading
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.pardonText))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.auto_awesome_rounded, size: 18, color: c.pardonText),
                            const SizedBox(width: 6),
                            Text('اسأل الذكاء', style: text.labelLarge!.copyWith(color: c.pardonText, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.isOwner && proposals.isEmpty && !alone) ...[
          const SizedBox(height: Space.s2),
          AtButton('حط هدف بنفسك', onPressed: () => _setGoal(null), kind: AtButtonKind.text),
        ],
        const SizedBox(height: Space.s4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 14),
          decoration: BoxDecoration(color: c.deep, borderRadius: BorderRadius.circular(Radii.card)),
          child: Row(
            children: [
              const Icon(Icons.how_to_vote_rounded, color: Color(0xFF8FB4FF)),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Text(
                  widget.isOwner
                      ? 'صوّتوا على الاقتراحات، وأنت تعتمد الهدف والمبلغ والأسابيع.'
                      : 'صوّت أو اقترح هدف، ومنشئ المجموعة يعتمد الهدف والمبلغ والأسابيع.',
                  style: text.bodySmall!.copyWith(color: const Color(0xFFEDF1FA), height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// one proposal: tap the card to vote, the bar fills with the team color
class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final int totalVotes;
  final Color team;
  final bool isOwner;
  final bool canApprove;
  final VoidCallback onVote;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ProposalCard({
    required this.proposal,
    required this.totalVotes,
    required this.team,
    required this.isOwner,
    required this.canApprove,
    required this.onVote,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final p = proposal;
    final mine = p['myVote'] == true;
    final votes = (p['votes'] as int?) ?? 0;
    final share = totalVotes == 0 ? 0.0 : votes / totalVotes;
    final byAi = p['suggestedBy'] == 'AI';
    final fill = mine ? team : (c.isDark ? c.lineStrong : const Color(0xFFB7C5E8));
    final onFill = mine && share >= 0.3;
    return Semantics(
      button: !mine,
      label: mine ? 'صوتك على ${p['title']}' : 'صوّت على ${p['title']}',
      child: RaisedCard(
        radius: Radii.card,
        highlight: mine ? team : null,
        onTap: mine ? null : onVote,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('${p['title'] ?? ''}', style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700))),
                const SizedBox(width: Space.s2),
                if (mine)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduceMotion(context) ? 1 : 0.4, end: 1),
                    duration: Motion.reward,
                    curve: Motion.easePop,
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: Pill('صوتك', fg: Colors.white, bg: team),
                  )
                else if (byAi)
                  Pill('اقتراح الذكاء', fg: c.pardonText, bg: c.pardonSoft)
                else
                  Text('اقتراح ${p['suggestedBy'] ?? ''}', style: text.labelSmall),
              ],
            ),
            if ('${p['details'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('${p['details']}', style: text.bodySmall),
            ],
            const SizedBox(height: 10),
            // the live result
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                height: 34,
                color: mine ? c.pardonSoft : c.surfaceSunken,
                child: Stack(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: share),
                      duration: Motion.reward,
                      curve: Motion.easeOut,
                      builder: (context, value, _) => FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: value.clamp(0, 1).toDouble(),
                        child: Container(color: fill),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(votes == 0 ? 'ما فيه أصوات' : votesAr(votes),
                                style: text.labelMedium!.copyWith(color: onFill ? Colors.white : c.ink, fontWeight: FontWeight.w700)),
                          ),
                          Text('${arabicDigits((share * 100).round())}٪', style: text.labelMedium!.copyWith(color: mine ? c.pardonText : c.inkMuted, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!mine) ...[
              const SizedBox(height: 6),
              Text('اضغط على الاقتراح عشان تصوّت له', style: text.labelSmall),
            ],
            if (mine && !byAi) ...[
              const SizedBox(height: 6),
              Text('اقتراح ${p['suggestedBy'] ?? ''}', style: text.labelSmall),
            ],
            if (isOwner) ...[
              const SizedBox(height: Space.s2),
              Row(
                children: [
                  Expanded(child: AtButton('اعتمده', kind: AtButtonKind.outline, onPressed: canApprove ? onApprove : null)),
                  const SizedBox(width: Space.s2),
                  IconButton(
                    tooltip: 'شيل الاقتراح',
                    icon: Icon(Icons.close_rounded, color: c.danger),
                    onPressed: onReject,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposeSheet extends StatefulWidget {
  final GroupApi api;
  final int groupId;

  const _ProposeSheet({required this.api, required this.groupId});

  @override
  State<_ProposeSheet> createState() => _ProposeSheetState();
}


class _ProposeSheetState extends State<_ProposeSheet> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  int _timesPerWeek = 3;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.api.propose(widget.groupId, _title.text.trim(), _details.text.trim(), _timesPerWeek);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: 'اقترح هدف',
      error: _error,
      child: Column(
        children: [
          TextField(controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'الهدف', hintText: 'مثل: المشي ٣٠ دقيقة')),
          const SizedBox(height: Space.s2),
          TextField(controller: _details, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل (اختياري)')),
          const SizedBox(height: Space.s3),
          _Stepper(
            label: 'عدد المرات في الأسبوع',
            value: _timesPerWeek,
            min: 1,
            max: 7,
            onChanged: (value) => setState(() => _timesPerWeek = value),
          ),
          const SizedBox(height: Space.s4),
          AtButton('اقترح', onPressed: _submit, loading: _loading),
        ],
      ),
    );
  }
}


// ---------- the owner sets the goal (from a proposal or by himself) ----------
// the same times every week, or a plan of weeks from the AI (the same task and times for every member in a week)
class SetGoalSheet extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final Map<String, dynamic>? proposal;

  const SetGoalSheet({super.key, required this.api, required this.groupId, this.proposal});

  @override
  State<SetGoalSheet> createState() => _SetGoalSheetState();
}

class _PlanWeek {
  final TextEditingController title;
  int times;

  _PlanWeek(String text, this.times) : title = TextEditingController(text: text);
}

class _SetGoalSheetState extends State<SetGoalSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: '${widget.proposal?['title'] ?? ''}');
  final _amount = TextEditingController(text: '5');
  final _minutes = TextEditingController();
  String _method = 'PHOTO';
  String _difficulty = 'SOLO';
  int _times = 3;
  int _weeks = 4;
  bool _loading = false;
  String? _error;

  // the plan of the AI
  DateTime _endDate = DateTime.now().add(const Duration(days: 28));
  List<_PlanWeek>? _plan;
  String? _note;
  bool _suggesting = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _minutes.dispose();
    for (final w in _plan ?? <_PlanWeek>[]) {
      w.title.dispose();
    }
    super.dispose();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 364)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _suggest() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'اكتب الهدف أول، وبعدها نقترح عليك التقسيمة.');
      return;
    }
    setState(() {
      _suggesting = true;
      _error = null;
    });
    try {
      final plan = await widget.api.suggestPlan(widget.groupId, _title.text.trim(), _endDate);
      final weeks = (plan['weeks'] as List? ?? const [])
          .map((w) => _PlanWeek('${(w as Map)['title'] ?? ''}', (w['timesPerWeek'] as int?) ?? 1))
          .toList();
      if (!mounted) return;
      setState(() {
        _plan = weeks;
        _note = plan['note'] as String?;
        final method = plan['proofMethod'] as String?;
        if (method != null && proofMethodsAr.containsKey(method)) _method = method;
        _suggesting = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _suggesting = false;
        _error = errorText(e);
      });
    }
  }

  void _dropPlan() => setState(() {
        for (final w in _plan ?? <_PlanWeek>[]) {
          w.title.dispose();
        }
        _plan = null;
        _note = null;
      });

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final plan = _plan;
    try {
      await widget.api.setGoal(widget.groupId, {
        'title': _title.text.trim(),
        'proofMethod': _method,
        'amountPerTime': parseAmount(_amount.text)!,
        'proposalId': widget.proposal?['id'],
        'difficulty': _difficulty,
        'targetMinutes': _method == 'TIMER' ? int.parse(_minutes.text.trim()) : null,
        if (plan == null) 'timesPerWeek': _times,
        if (plan == null) 'totalWeeks': _weeks,
        if (plan != null) 'weeks': [for (final w in plan) {'title': w.title.text.trim(), 'timesPerWeek': w.times}],
      });
      if (mounted) {
        showMessage(context, 'بدأ هدف المجموعة، وصار عند كل عضو بتعهّداته');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final plan = _plan;
    return SheetBody(
      title: 'اعتمد هدف المجموعة',
      error: _error,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الكل ياخذ نفس الهدف بنفس عدد المرات والمبلغ.', style: text.bodySmall),
            const SizedBox(height: Space.s4),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'الهدف'),
              validator: (v) => (v == null || v.trim().isEmpty || v.length > 100) ? 'اكتب الهدف' : null,
            ),
            const SizedBox(height: Space.s4),

            // ---- the AI plan ----
            if (plan == null)
              Container(
                padding: const EdgeInsets.all(Space.s4),
                decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(Radii.lg)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: c.primary, size: 20),
                        const SizedBox(width: Space.s2),
                        Expanded(child: Text('تبغى نقترح عليك عدد مرات لكل أسبوع؟', style: text.titleMedium!.copyWith(color: c.primary))),
                      ],
                    ),
                    const SizedBox(height: Space.s1),
                    Text('اختر متى ينتهي الهدف، ونقسّمه على الأسابيع ونبدأ بالأسهل.', style: text.bodySmall),
                    const SizedBox(height: Space.s3),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickEndDate,
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text('ينتهي ${dayAr(_endDate.toIso8601String())}'),
                          ),
                        ),
                        const SizedBox(width: Space.s2),
                        Expanded(child: AtButton('اقترح', onPressed: _suggest, loading: _suggesting)),
                      ],
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(child: Text('التقسيمة (${arabicDigits(plan.length)} أسابيع)', style: text.titleMedium)),
                  TextButton(onPressed: _dropPlan, child: const Text('نفس العدد كل أسبوع')),
                ],
              ),
              if (_note != null && _note!.isNotEmpty) Text(_note!, style: text.bodySmall),
              const SizedBox(height: Space.s2),
              for (final (i, w) in plan.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s2),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('الأسبوع ${arabicDigits(i + 1)}', style: text.labelMedium!.copyWith(color: c.shadda)),
                        TextFormField(
                          controller: w.title,
                          decoration: const InputDecoration(isDense: true, hintText: 'وش المطلوب هالأسبوع'),
                          validator: (v) => (v == null || v.trim().isEmpty || v.length > 100) ? 'اكتب المطلوب' : null,
                        ),
                        _Stepper(label: 'مرات بالأسبوع', value: w.times, min: 1, max: 7, onChanged: (v) => setState(() => w.times = v)),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: Space.s4),

            Text('طريقة الإثبات', style: text.labelLarge),
            const SizedBox(height: Space.s2),
            Wrap(
              spacing: Space.s2,
              children: [
                for (final m in proofMethodsAr.entries)
                  ChoiceChip(label: Text(m.value), selected: _method == m.key, onSelected: (_) => setState(() => _method = m.key)),
              ],
            ),
            const SizedBox(height: Space.s4),
            if (plan == null) ...[
              _Stepper(label: 'كم مرة بالأسبوع', value: _times, min: 1, max: 7, onChanged: (v) => setState(() => _times = v)),
              _Stepper(label: 'كم أسبوع', value: _weeks, min: 1, max: 52, onChanged: (v) => setState(() => _weeks = v)),
              const SizedBox(height: Space.s2),
            ],
            Text('مستوى التحدي', style: text.labelLarge),
            const SizedBox(height: Space.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LevelCard(
                    selected: _difficulty == 'SOLO',
                    icon: Icons.person_rounded,
                    title: 'فردي',
                    body: 'اللي يسوّف هو بس اللي يتبرّع.',
                    color: c.primary,
                    onTap: () => setState(() => _difficulty = 'SOLO'),
                  ),
                ),
                const SizedBox(width: Space.s2),
                Expanded(
                  child: _LevelCard(
                    selected: _difficulty == 'HARD',
                    icon: Icons.local_fire_department_rounded,
                    title: 'صعب',
                    body: 'لو أحد سوّف الكل يتبرّع: هو بالمبلغ كامل، والباقين بنصه (٥ ريال أقل شي).',
                    color: c.urgent,
                    onTap: () => setState(() => _difficulty = 'HARD'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s4),
            AmountField(
              controller: _amount,
              label: 'مبلغ التبرّع لو ما تمت المهمة',
              hint: 'أقل مبلغ ٥ ريال',
              validator: (v) => (parseAmount(v ?? '') ?? 0) < 5 ? 'أقل مبلغ ٥ ريال' : null,
            ),
            if (_method == 'TIMER') ...[
              const SizedBox(height: Space.s4),
              TextFormField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'كم دقيقة'),
                validator: (v) {
                  final value = int.tryParse(v?.trim() ?? '');
                  if (value == null || value < 1 || value > 600) return 'من ١ إلى ٦٠٠ دقيقة';
                  return null;
                },
              ),
            ],
            if (_method == 'LOCATION')
              Padding(
                padding: const EdgeInsets.only(top: Space.s3),
                child: Text('كل عضو يحدد مكانه بنفسه من تعهّداته.', style: text.labelSmall),
              ),
            const SizedBox(height: Space.s6),
            AtButton('ابدأ الهدف', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}

// one level of the challenge in the goal sheet
class _LevelCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final VoidCallback onTap;

  const _LevelCard({required this.selected, required this.icon, required this.title, required this.body, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          padding: const EdgeInsets.all(Space.s3),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.10) : c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: selected ? color : c.line, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w800))),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: Motion.reward,
                  curve: Motion.easePop,
                  child: Icon(Icons.check_circle_rounded, color: color, size: 20),
                ),
              ]),
              const SizedBox(height: 4),
              Text(body, style: text.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.labelLarge)),
        IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
        SizedBox(width: 36, child: Text(arabicDigits(value), style: text.headlineSmall, textAlign: TextAlign.center)),
        IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }
}

// ---------- my place (LOCATION goal) ----------
// every member proves the goal in his own place (his gym, his mosque ...), he searches for it by name
class _MyPlaceCard extends StatefulWidget {
  final GroupApi api;
  final int groupId;

  const _MyPlaceCard({required this.api, required this.groupId});

  @override
  State<_MyPlaceCard> createState() => _MyPlaceCardState();
}

class _MyPlaceCardState extends State<_MyPlaceCard> {
  Map<String, dynamic>? _place;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final place = await widget.api.myPlace(widget.groupId);
      if (mounted) setState(() => _place = place);
    } catch (_) {
      // the card stays with "choose your place"
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _PlaceSearchSheet(api: widget.api, groupId: widget.groupId),
    );
    if (saved == true) {
      await _load();
      if (mounted) showMessage(context, 'حفظنا مكانك');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final name = '${_place?['name'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: Space.s3),
      child: AppCard(
        onTap: _choose,
        child: Row(
          children: [
            Icon(_place == null ? Icons.add_location_alt_outlined : Icons.location_on, color: c.primary),
            const SizedBox(width: Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_place == null ? 'اختر مكانك' : 'مكانك', style: text.labelSmall),
                  Text(_place == null ? 'الإثبات يكون بموقعك في المكان اللي تختاره' : (name.isEmpty ? 'مكان محفوظ' : name),
                      style: _place == null ? text.bodySmall : text.titleMedium),
                ],
              ),
            ),
            Text(_place == null ? 'اختيار' : 'تغيير', style: text.labelLarge!.copyWith(color: c.primary)),
          ],
        ),
      ),
    );
  }
}

class _PlaceSearchSheet extends StatefulWidget {
  final GroupApi api;
  final int groupId;

  const _PlaceSearchSheet({required this.api, required this.groupId});

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _query = TextEditingController();
  Timer? _wait;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _saving = false;
  String? _error;
  Position? _here; // to put the near places first (only when the location is already allowed)

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _here = await Geolocator.getLastKnownPosition();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _wait?.cancel();
    _query.dispose();
    super.dispose();
  }

  // searches after he stops typing
  void _onType(String value) {
    _wait?.cancel();
    _wait = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.api.searchPlaces(value.trim(), lat: _here?.latitude, lng: _here?.longitude);
      if (!mounted || _query.text != value) return;
      setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(Map<String, dynamic> place) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.setMyPlace(widget.groupId, place);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetBody(
      title: 'وين مكانك؟',
      error: _error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _onType,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'اكتب اسم المكان، مثل: نادي، مسجد، مكتبة',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
            ),
          ),
          const SizedBox(height: Space.s3),
          if (_saving) const LinearProgressIndicator(),
          if (!_searching && _results.isEmpty && _query.text.trim().length >= 2)
            Padding(
              padding: const EdgeInsets.all(Space.s4),
              child: Text('ما لقينا مكان بهالاسم، جرّب اسم ثاني', style: text.bodySmall, textAlign: TextAlign.center),
            ),
          for (final p in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text('${p['name'] ?? ''}'),
              subtitle: Text('${p['address'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: _saving ? null : () => _pick(p),
            ),
          const SizedBox(height: Space.s2),
          Text('تقدر تغيّر المكان لين أول إثبات مقبول', style: text.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
