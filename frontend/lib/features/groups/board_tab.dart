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
import 'group_widgets.dart';

// the board: the group card, today's alerts, the active goal and every member's week (with the alert button)
// when there is no goal: the proposals, the votes, and the owner sets the next goal
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

  _BoardData(this.goal, this.board, this.proposals, this.alerts);
}

class _BoardTabState extends State<BoardTab> with AutomaticKeepAliveClientMixin {
  _BoardData? _data;
  String? _error;
  Timer? _timer;
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
    if (goal == null) return _BoardData(null, const [], await api.proposals(_groupId), alerts);
    return _BoardData(goal, await api.board(_groupId), const [], alerts);
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
      if (goalStarted) widget.onChanged(); // the group card (active goal) changes too
    } catch (e) {
      if (mounted && !silent) setState(() => _error = errorText(e));
    }
  }

  // I did my task: opens its proof (the same steps as the today page), then the board refreshes
  Widget _proveButton(_BoardData data) {
    final mine = data.board.where((r) => r['memberId'] == widget.me).toList();
    if (mine.isEmpty) return const SizedBox.shrink(); // not in this goal (joined after it ended, or kicked)
    final left = (mine.first['remaining'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s3),
      child: AtButton(
        left == 0 ? 'خلّصت مهام هالأسبوع' : 'سوّيت المهمة؟ وثّق إنجازك',
        icon: Icon(left == 0 ? Icons.check_circle : Icons.task_alt),
        onPressed: left == 0 || _proving ? null : _prove,
        loading: _proving,
      ),
    );
  }

  bool _proving = false;

  Future<void> _prove() async {
    setState(() => _proving = true);
    try {
      final task = await widget.api.myTask(_groupId);
      if (!mounted) return;
      await openActivityProof(context, task);
      await _refresh(silent: true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _proving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    if (data == null) return _error != null ? ErrorView(message: _error!, onRetry: _refresh) : const LoadingView();
    final members = (widget.group['membersCount'] as int?) ?? 0;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(Space.s4),
        children: [
          _GroupCard(group: widget.group, goal: data.goal),
          for (final a in data.alerts.where((a) => !GroupActivity.instance.dismissed.contains(a['id']))) ...[
            const SizedBox(height: Space.s3),
            _AlertBanner(
              alert: a,
              onDismiss: () async {
                await GroupActivity.instance.dismissAlert(a['id'] as int);
                if (mounted) setState(() {});
              },
            ),
          ],
          if (data.goal != null) ...[
            _GoalSection(goal: data.goal!, board: data.board),
            if (data.goal!['proofMethod'] == 'LOCATION') _MyPlaceCard(api: widget.api, groupId: _groupId),
            _proveButton(data),
            SectionTitle('هالأسبوع', trailing: TextButton(onPressed: () => _showHistory(context), child: const Text('الأهداف السابقة'))),
            for (final (i, row) in _ranked(data.board).indexed) ...[
              _BoardRow(row: row, place: i + 1, isMe: row['memberId'] == widget.me, onAlert: () => _alert(row)),
              const SizedBox(height: Space.s2),
            ],
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
      if (mounted) showError(context, e);
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
            if (snap.hasError) return ErrorView(message: '${snap.error}');
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

// ---------- the group card (team color) ----------
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final Map<String, dynamic>? goal;

  const _GroupCard({required this.group, required this.goal});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = '${group['name'] ?? ''}';
    final color = AtColors.team(((group['id'] as int?) ?? 1) - 1);
    final white70 = text.labelSmall!.copyWith(color: Colors.white70);
    return AppCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NameAvatar(name, radius: 22, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.headlineSmall!.copyWith(color: Colors.white)),
                    Text('${arabicDigits(group['membersCount'] ?? 0)} أعضاء', style: white70),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(arabicDigits(group['points'] ?? 0), style: text.headlineMedium!.copyWith(color: Colors.white)),
                  Text('نقطة', style: white70),
                ],
              ),
            ],
          ),
          if ('${group['description'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: Space.s3),
            Text('${group['description']}', style: text.bodySmall!.copyWith(color: Colors.white)),
          ],
          if (group['pointsForGraceDay'] != null) ...[
            const SizedBox(height: Space.s3),
            Text('${arabicDigits(group['pointsForGraceDay'])} نقطة وتكسب المجموعة يوم عفو', style: white70),
          ],
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onDismiss;

  const _AlertBanner({required this.alert, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: c.streakSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_rounded, color: c.streak),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['isCollective'] == true ? 'المجموعة تنبهك' : '${alert['senderName'] ?? ''} ينبهك', style: text.labelLarge),
                const SizedBox(height: Space.s1),
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

// ---------- the active goal ----------
class _GoalSection extends StatelessWidget {
  final Map<String, dynamic> goal;
  final List<Map<String, dynamic>> board;

  const _GoalSection({required this.goal, required this.board});

  // "بدأ الهدف ٢٤/١٠ · الأسبوع ١ من ٤"
  String _started() {
    final start = DateTime.tryParse('${goal['startDate']}');
    final total = goal['totalWeeks'] as int?;
    if (start == null) return 'بدأ الهدف';
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day).difference(start).inDays;
    if (days < 0) return 'يبدأ الهدف ${dayAr(goal['startDate'])}';
    final week = days ~/ 7 + 1;
    return 'بدأ الهدف ${dayAr(goal['startDate'])} · الأسبوع ${arabicDigits(week)}${total == null ? '' : ' من ${arabicDigits(total)}'}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final required = board.fold<int>(0, (sum, r) => sum + ((r['required'] as int?) ?? 0));
    final completed = board.fold<int>(0, (sum, r) => sum + ((r['completed'] as int?) ?? 0));
    final finished = board.where((r) => (r['remaining'] as int? ?? 1) == 0).length;
    final progress = required == 0 ? 0.0 : (completed / required).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('هدف المجموعة'),
        Container(
          padding: const EdgeInsets.all(Space.s5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.xl),
            gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [c.shadda, c.deep]),
            boxShadow: [BoxShadow(color: c.deep.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_started(), style: text.labelMedium!.copyWith(color: c.goldLight)),
                        const SizedBox(height: Space.s1),
                        Text('${goal['title'] ?? ''}', style: text.headlineMedium!.copyWith(color: Colors.white)),
                        if ('${goal['details'] ?? ''}'.isNotEmpty)
                          Text('${goal['details']}', style: text.bodySmall!.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  // the group together this week
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: progress),
                            duration: Motion.sign,
                            curve: Motion.easeOut,
                            builder: (context, value, _) => CircularProgressIndicator(
                              value: value,
                              strokeWidth: 7,
                              strokeCap: StrokeCap.round,
                              color: c.gold,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${arabicDigits((progress * 100).round())}٪', style: text.titleMedium!.copyWith(color: Colors.white)),
                            Text('المجموعة', style: text.labelSmall!.copyWith(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s4),
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [
                  _Chip(proofMethodsAr[goal['proofMethod']] ?? '${goal['proofMethod']}'),
                  _Chip('${arabicDigits(goal['timesPerWeek'])} مرات بالأسبوع'),
                  _Chip('${arabicDigits(goal['totalWeeks'])} أسابيع'),
                  if (goal['targetMinutes'] != null) _Chip('${arabicDigits(goal['targetMinutes'])} دقيقة'),
                  if (finished > 0) _Chip('${arabicDigits(finished)} كمّلوا الأسبوع'),
                ],
              ),
              const SizedBox(height: Space.s4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(
                  children: [
                    Expanded(child: Text('مبلغ التبرّع في حال ما تمت المهمة', style: text.bodySmall!.copyWith(color: Colors.white))),
                    RiyalAmount(goal['amountPerTime'] as num?, color: c.gold),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s1),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(Radii.full)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Colors.white)),
    );
  }
}

// ---------- one member in the board ----------
class _BoardRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final int place;
  final bool isMe;
  final VoidCallback onAlert;

  const _BoardRow({required this.row, required this.place, required this.isMe, required this.onAlert});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final remaining = (row['remaining'] as int?) ?? 0;
    final required = (row['required'] as int?) ?? 0;
    final completed = (row['completed'] as int?) ?? 0;
    final hasExcuse = row['hasExcuse'] == true;
    final canAlert = !isMe && remaining > 0 && !hasExcuse;
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: isMe ? c.primary : c.line, width: isMe ? 1.5 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(arabicDigits(place), style: text.titleMedium!.copyWith(color: place == 1 ? c.shadda : c.inkSubtle)),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              NameAvatar('${row['name'] ?? ''}'),
              if (remaining == 0)
                PositionedDirectional(
                  bottom: -2,
                  end: -2,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(color: c.shadda, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? 'أنت' : '${row['name'] ?? ''}', style: text.labelLarge),
                const SizedBox(height: Space.s1),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.full),
                  child: LinearProgressIndicator(
                    value: required == 0 ? 0 : completed / required,
                    minHeight: 6,
                    backgroundColor: c.surfaceSunken,
                    color: c.shadda,
                  ),
                ),
                const SizedBox(height: Space.s1),
                Text(
                  remaining == 0 ? 'كمّل الأسبوع، شجّعوه' : 'باقي ${arabicDigits(remaining)} من ${arabicDigits(required)} · ${arabicDigits(row['daysLeft'] ?? 0)} أيام',
                  style: text.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.s2),
          if (hasExcuse)
            const StatusBadge('عنده عذر', kind: BadgeKind.info)
          else if (canAlert)
            IconButton.filledTonal(
              tooltip: 'نبّهه',
              onPressed: onAlert,
              style: IconButton.styleFrom(backgroundColor: c.streakSoft, foregroundColor: c.streak),
              icon: const Icon(Icons.campaign_rounded),
            )
          else
            StatusBadge.track(row['trackStatus'] as String?),
        ],
      ),
    );
  }
}

// ---------- no goal: proposals and votes ----------
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
      if (mounted) showError(context, e);
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
    final proposals = [...widget.proposals]..sort((a, b) => ((b['votes'] as int?) ?? 0).compareTo((a['votes'] as int?) ?? 0));
    final totalVotes = proposals.fold<int>(0, (sum, p) => sum + ((p['votes'] as int?) ?? 0));
    final leader = proposals.isNotEmpty && ((proposals.first['votes'] as int?) ?? 0) > 0 ? proposals.first : null;
    // a group goal needs 2 members at least (like a chat needs someone to talk to)
    final alone = widget.membersCount < 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (alone) ...[
          const SizedBox(height: Space.s4),
          AppCard(
            color: c.primarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.group_add_rounded, color: c.primary, size: 32),
                const SizedBox(height: Space.s2),
                Text('أرسل رمز الدعوة لأصحابك', style: text.headlineSmall),
                Text('الهدف يبدأ لما يكون بالمجموعة شخصين على الأقل. شارك كود الدعوة أو الباركود.', style: text.bodySmall),
                const SizedBox(height: Space.s3),
                AtButton('أرسل رمز الدعوة', onPressed: widget.onInvite, icon: const Icon(Icons.qr_code_rounded, size: 18)),
              ],
            ),
          ),
        ],
        const SectionTitle('وش هدفنا الجاي؟'),
        Text(
          widget.isOwner
              ? 'صوّت على اقتراح الأعضاء، وأنت تعتمد الهدف اللي تختارونه.'
              : 'صوّت على اقتراح الأعضاء أو اقترح هدف، ومنشئ المجموعة يعتمد الهدف.',
          style: text.bodySmall,
        ),
        const SizedBox(height: Space.s4),
        Row(
          children: [
            Expanded(child: AtButton('اقترح هدف', onPressed: _propose, kind: AtButtonKind.outline)),
            const SizedBox(width: Space.s3),
            Expanded(child: AtButton('اقتراحات الذكاء', onPressed: _ai, loading: _aiLoading, kind: AtButtonKind.outline)),
          ],
        ),
        const SizedBox(height: Space.s4),
        if (proposals.isEmpty) const EmptyView(message: 'ما فيه اقتراحات للحين.', icon: Icons.lightbulb_outline),
        if (proposals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: Text(
              'صوّت ${arabicDigits(totalVotes)} من ${arabicDigits(widget.membersCount)} · النتيجة تتحدّث لحالها',
              style: text.labelSmall,
            ),
          ),
        for (final p in proposals) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${p['title'] ?? ''}', style: text.headlineSmall)),
                    if (leader != null && identical(p, leader)) const StatusBadge('الأكثر', kind: BadgeKind.success),
                  ],
                ),
                const SizedBox(height: Space.s2),
                // the live result
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.full),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: widget.membersCount == 0 ? 0 : ((p['votes'] as int?) ?? 0) / widget.membersCount),
                          duration: Motion.base,
                          curve: Motion.easeOut,
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value.clamp(0, 1).toDouble(),
                            minHeight: 8,
                            backgroundColor: c.surfaceSunken,
                            color: p['myVote'] == true ? c.shadda : c.primary.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.s3),
                    Text('${arabicDigits(p['votes'] ?? 0)} صوت', style: text.labelLarge),
                  ],
                ),
                if ('${p['details'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: Space.s1),
                  Text('${p['details']}', style: text.bodySmall),
                ],
                const SizedBox(height: Space.s1),
                Text('اقترحه: ${p['suggestedBy'] ?? ''}', style: text.labelSmall),
                const SizedBox(height: Space.s3),
                Row(
                  children: [
                    Expanded(
                      child: AtButton(
                        p['myVote'] == true ? 'صوتك هنا' : 'صوّت',
                        kind: p['myVote'] == true ? AtButtonKind.outline : AtButtonKind.primary,
                        onPressed: p['myVote'] == true ? null : () => _run(() => widget.api.vote(p['id'] as int), 'انحسب صوتك'),
                      ),
                    ),
                    if (widget.isOwner) ...[
                      const SizedBox(width: Space.s2),
                      Expanded(child: AtButton('اعتمده', kind: AtButtonKind.outline, onPressed: alone ? null : () => _setGoal(p))),
                      IconButton(
                        tooltip: 'شيله',
                        icon: Icon(Icons.close_rounded, color: c.danger),
                        onPressed: () => _run(() => widget.api.reject(p['id'] as int), 'انشال الاقتراح'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s3),
        ],
        if (widget.isOwner && proposals.isEmpty && !alone)
          AtButton('حط هدف بنفسك', onPressed: () => _setGoal(null), kind: AtButtonKind.text),
      ],
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
      await widget.api.propose(widget.groupId, _title.text.trim(), _details.text.trim());
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
        'amountPerTime': num.parse(_amount.text.trim()),
        'proposalId': widget.proposal?['id'],
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
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'مبلغ التبرّع في حال ما تمت المهمة', suffixIcon: Padding(padding: EdgeInsets.all(14), child: RiyalSymbol())),
              validator: (v) => (num.tryParse(v?.trim() ?? '') ?? 0) < 5 ? '٥ أقل شي' : null,
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
