import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'group_activity.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_ui.dart';
import 'group_widgets.dart';
import 'moment_viewer.dart';
import 'scan_screen.dart';

// OWNER: Fai - the "المجموعات" tab (design: Groups): my groups as cards, create a group, join with a code or QR
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

// what a group card shows: the group, its goal, my week in it and its competition
class _CardInfo {
  final Map<String, dynamic> group;
  final Map<String, dynamic>? goal;
  final Map<String, dynamic>? myRow;
  final Map<String, dynamic>? match; // ACTIVE, or a PENDING challenge to us

  _CardInfo(this.group, this.goal, this.myRow, this.match);
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupApi _api = GroupApi(context.read<ApiClient>());
  final _activity = GroupActivity.instance;
  final Map<int, Future<_CardInfo>> _cards = {};
  Future<Map<String, dynamic>?> _friendMoment = Future.value(null);
  Key _listKey = UniqueKey();
  Timer? _timer;
  int? _me;

  @override
  void initState() {
    super.initState();
    _me = context.read<AuthState>().userId;
    _activity.addListener(_onActivity);
    // this tab stays alive under the bottom bar, so it checks the groups every 20 seconds while the app is open
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _checkActivity());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _activity.removeListener(_onActivity);
    super.dispose();
  }

  void _onActivity() {
    if (mounted) setState(() {});
  }

  Future<void> _checkActivity() async {
    try {
      final groups = await _api.myGroups();
      if (!mounted) return;
      await _activity.check(_api, groups, context.read<AuthState>().userId);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadGroups() async {
    _cards.clear();
    _friendMoment = _api.friendMoment().catchError((_) => null);
    final groups = await _api.myGroups();
    if (mounted) _activity.check(_api, groups, context.read<AuthState>().userId);
    return groups;
  }

  Future<_CardInfo> _loadCard(int groupId) async {
    final me = _me;
    final results = await Future.wait<Object?>([
      _api.group(groupId),
      _api.activeGoal(groupId),
      _api.matches(groupId).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    final group = results[0] as Map<String, dynamic>;
    final goal = results[1] as Map<String, dynamic>?;
    final matches = results[2] as List<Map<String, dynamic>>;
    Map<String, dynamic>? myRow;
    if (goal != null) {
      try {
        final board = await _api.board(groupId);
        myRow = board.where((r) => r['memberId'] == me).firstOrNull;
      } catch (_) {}
    }
    final match = matches.where((m) => m['status'] == 'ACTIVE').firstOrNull ??
        matches.where((m) => m['status'] == 'PENDING' && m['opponentId'] == groupId).firstOrNull;
    return _CardInfo(group, goal, myRow, match);
  }

  void _refresh() => setState(() => _listKey = UniqueKey());

  Future<void> _open(int groupId) async {
    await context.push('/group/$groupId');
    _refresh(); // the group may be left or archived
  }

  Future<void> _openMoment(Map<String, dynamic> moment) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => MomentViewer(api: _api, moments: [moment], start: 0, me: _me)),
    );
  }

  Future<void> _create() async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateGroupSheet(api: _api),
    );
    if (id != null) {
      _refresh();
      _open(id);
    }
  }

  Future<void> _join() async {
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _JoinSheet(api: _api),
    );
    if (joined == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Map<String, dynamic>>>(
          key: _listKey,
          load: () => inArabic(_loadGroups()),
          builder: (context, groups, reload) {
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s5, Space.s4, Space.s8),
                children: [
                  Text('مجموعاتي', style: text.headlineMedium!.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: Space.s6),
                      child: EmptyView(
                        message: 'ما انضميت لمجموعة للحين.\nسوّ مجموعة مع أصحابك، أو اطلب منهم كود الدعوة.',
                        icon: Icons.groups_outlined,
                      ),
                    ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _friendMoment,
                    builder: (context, snap) {
                      final m = snap.data;
                      if (m == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Space.s3),
                        child: Appear(index: 0, child: _FriendMoment(moment: m, onTap: () => _openMoment(m))),
                      );
                    },
                  ),
                  for (final (i, g) in groups.indexed) ...[
                    Appear(
                      index: i,
                      child: _GroupCard(
                      member: g,
                      info: _cards.putIfAbsent(g['groupId'] as int, () => _loadCard(g['groupId'] as int)),
                      hasAlert: _activity.hasNewIn(g['groupId'] as int, GroupActivity.alert),
                      whereNew: _activity.whereNew(g['groupId'] as int),
                      onTap: () => _open(g['groupId'] as int),
                      ),
                    ),
                    const SizedBox(height: Space.s3),
                  ],
                  const SizedBox(height: Space.s2),
                  Text('مجموعة جديدة', style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BigAction(
                          primary: true,
                          icon: Icons.group_add_rounded,
                          title: 'أنشئ مجموعة',
                          subtitle: 'وادعُ أصحابك',
                          onTap: _create,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BigAction(
                          primary: false,
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'انضم لمجموعة',
                          subtitle: 'بالكود أو بمسح QR',
                          onTap: _join,
                        ),
                      ),
                    ],
                  ),
                  if (groups.isNotEmpty) ...[
                    const SizedBox(height: Space.s5),
                    Text('اسحب لتحت عشان تحدّث', style: text.labelSmall, textAlign: TextAlign.center),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------- one group ----------
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> member; // from my groups: groupId, groupName, role, points
  final Future<_CardInfo> info;
  final bool hasAlert;
  final String? whereNew;
  final VoidCallback onTap;

  const _GroupCard({required this.member, required this.info, required this.hasAlert, required this.whereNew, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final groupId = member['groupId'] as int;
    final name = '${member['groupName'] ?? ''}';
    final team = teamColor(groupId);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FutureBuilder<_CardInfo>(
            future: info,
            builder: (context, snap) {
              final data = snap.data;
              final goal = data?.goal;
              final match = data?.match;
              final members = data?.group['membersCount'];
              final subtitle = [
                if (members != null) '${arabicDigits(members)}/${arabicDigits(10)} أعضاء',
                if (goal != null) '${goal['title'] ?? ''} × ${arabicDigits(goal['timesPerWeek'] ?? '')}',
                if (data != null && goal == null) 'بدون هدف شغّال',
                if (data == null) member['role'] == 'OWNER' ? 'منشئ المجموعة' : 'عضو',
              ].join(' · ');
              final Widget? badge = hasAlert
                  ? Pill('تنبيه', fg: c.danger, bg: c.dangerSoft, dot: true)
                  : whereNew != null
                      ? Pill('جديد', fg: c.primary, bg: c.primarySoft, dot: true)
                      : match?['status'] == 'ACTIVE'
                          ? Pill('في منافسة', fg: c.urgentText, bg: c.urgentSoft)
                          : match != null
                              ? Pill('تحدّي جديد', fg: c.urgentText, bg: c.urgentSoft, dot: true)
                              : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TeamAvatar(name: name, color: team),
                      const SizedBox(width: Space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(subtitle, style: text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (badge != null) ...[const SizedBox(width: Space.s2), badge],
                    ],
                  ),
                  if (whereNew != null) ...[
                    const SizedBox(height: Space.s2),
                    Text(whereNew!, style: text.labelSmall!.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
                  ],
                  if (data != null) ...[
                    const SizedBox(height: Space.s3),
                    if (match != null)
                      _MatchPanel(match: match, groupId: groupId)
                    else if (goal != null)
                      Row(
                        children: [
                          Expanded(child: _MyWeekPanel(row: data.myRow)),
                          const SizedBox(width: Space.s2),
                          Expanded(child: _PardonPanel(group: data.group)),
                        ],
                      )
                    else
                      _Panel(child: Text('صوّتوا على الهدف الجاي من لوحة المجموعة', style: text.labelSmall)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// the newest moment a friend shared (GET /moment/widget), like a photo on the fridge
class _FriendMoment extends StatelessWidget {
  final Map<String, dynamic> moment;
  final VoidCallback onTap;

  const _FriendMoment({required this.moment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final isVideo = moment['mediaType'] == 'VIDEO';
    return RaisedCard(
      radius: Radii.card,
      color: paperColor(c),
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Transform.rotate(
            angle: -0.05,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Color(0x2610245E), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: isVideo
                      ? Container(color: c.deep, child: const Icon(Icons.play_arrow_rounded, color: Colors.white))
                      : Image.network(
                          GroupApi.media(moment['mediaUrl']),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(color: c.surfaceSunken, child: Icon(Icons.image_outlined, color: c.inkSubtle)),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('آخر لحظة من أصحابك', style: text.labelSmall),
                Text('${moment['name'] ?? ''}', style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                Text('${moment['groupName'] ?? ''} · ${dayAr(moment['createdAt'])}', style: text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: c.inkSubtle),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: context.colors.bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: child,
    );
  }
}

// «أنت: باقي ٢ من ٤» and the pips
class _MyWeekPanel extends StatelessWidget {
  final Map<String, dynamic>? row;

  const _MyWeekPanel({required this.row});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = row;
    if (r == null) return _Panel(child: Text('مو داخل هدف هالأسبوع', style: text.labelSmall));
    final required = (r['required'] as int?) ?? 0;
    final completed = (r['completed'] as int?) ?? 0;
    final remaining = (r['remaining'] as int?) ?? 0;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(remaining == 0 ? 'أنت: كمّلت الأسبوع' : 'أنت: باقي ${arabicDigits(remaining)} من ${arabicDigits(required)}', style: text.labelSmall),
          const SizedBox(height: 6),
          Pips(done: completed, total: required, width: 0, empty: context.colors.line),
        ],
      ),
    );
  }
}

// «٢٤٠ / ٣٠٠ للعفو الجماعي»
class _PardonPanel extends StatelessWidget {
  final Map<String, dynamic> group;

  const _PardonPanel({required this.group});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final points = (group['points'] as int?) ?? 0;
    final target = (group['pointsForGraceDay'] as int?) ?? 300;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${arabicDigits(points)} / ${arabicDigits(target)} للعفو الجماعي', style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(value: target == 0 ? 0 : (points / target).clamp(0, 1).toDouble(), minHeight: 6, color: c.pardon, backgroundColor: c.line),
          ),
        ],
      ),
    );
  }
}

// «ضد «الصقور» · باقي ٣ أيام»   ٨٤٪ – ٧٩٪
class _MatchPanel extends StatelessWidget {
  final Map<String, dynamic> match;
  final int groupId;

  const _MatchPanel({required this.match, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final weChallenged = match['challengerId'] == groupId;
    final them = '${weChallenged ? match['opponentName'] : match['challengerName']}';
    final ours = weChallenged ? match['challengerScore'] : match['opponentScore'];
    final theirs = weChallenged ? match['opponentScore'] : match['challengerScore'];
    final pending = match['status'] == 'PENDING';
    final end = DateTime.tryParse('${match['endDate']}');
    final start = DateTime.tryParse('${match['startDate']}');
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final String when;
    if (pending) {
      when = 'يتحداكم، رد عليه من المنافسة';
    } else if (start != null && day.isBefore(start)) {
      when = 'تبدأ ${arabicDigits('${start.day}/${start.month}')}';
    } else if (end != null) {
      final left = end.difference(day).inDays + 1;
      when = left <= 1 ? 'آخر يوم' : 'باقي ${arabicDigits(left)} أيام';
    } else {
      when = '';
    }
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: Text('ضد «$them»${when.isEmpty ? '' : ' · $when'}', style: text.labelMedium!.copyWith(color: c.inkMuted, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (!pending && ours != null && theirs != null)
            Text('${arabicDigits(ours)}٪ – ${arabicDigits(theirs)}٪', style: text.titleSmall!.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// the two big buttons under the groups: create (raised primary) and join (white)
class _BigAction extends StatefulWidget {
  final bool primary;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigAction({required this.primary, required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  State<_BigAction> createState() => _BigActionState();
}

class _BigActionState extends State<_BigAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final primary = widget.primary;
    final fg = primary ? c.onPrimary : c.ink;
    return Semantics(
      button: true,
      label: '${widget.title}، ${widget.subtitle}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          margin: EdgeInsets.only(top: primary && _down ? 4 : 0, bottom: primary && !_down ? 4 : 0),
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primary ? c.primary : c.surface,
            borderRadius: BorderRadius.circular(18),
            border: primary ? null : Border.all(color: c.line),
            boxShadow: primary && !_down ? [BoxShadow(color: c.primaryEdge, offset: const Offset(0, 4))] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: primary ? fg : c.primary, size: 26),
              const SizedBox(height: Space.s4),
              Text(widget.title, style: text.labelLarge!.copyWith(color: fg, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(widget.subtitle, style: text.labelSmall!.copyWith(color: primary ? c.onPrimary.withValues(alpha: 0.8) : c.inkSubtle)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  final GroupApi api;

  const _CreateGroupSheet({required this.api});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _payMode = 'SOLO'; // who donates when someone misses, fixed after creating
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final group = await widget.api.create(_name.text.trim(), _description.text.trim(), _payMode);
      if (mounted) Navigator.pop(context, group['id'] as int?);
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
      title: 'مجموعة جديدة',
      icon: Icons.group_add_rounded,
      error: _error,
      child: Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم المجموعة'),
              validator: (v) => (v == null || v.trim().isEmpty || v.length > 100) ? 'اكتب اسم (١٠٠ حرف أقصى شي)' : null,
            ),
            const SizedBox(height: Space.s3),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'وش تبون تتحدون فيه؟ (اختياري)'),
              validator: (v) => (v != null && v.length > 255) ? '٢٥٥ حرف أقصى شي' : null,
            ),
            const SizedBox(height: Space.s4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('لو أحد سوّف، مين يتبرّع؟', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: Space.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OptionCard(
                    icon: Icons.person_rounded,
                    title: 'هو بس',
                    subtitle: 'كل واحد عن نفسه',
                    selected: _payMode == 'SOLO',
                    onTap: () => setState(() => _payMode = 'SOLO'),
                  ),
                ),
                const SizedBox(width: Space.s2),
                Expanded(
                  child: OptionCard(
                    icon: Icons.groups_rounded,
                    title: 'الكل',
                    subtitle: 'هو كامل، والباقين النص',
                    selected: _payMode == 'ALL',
                    color: context.colors.urgent,
                    onTap: () => setState(() => _payMode = 'ALL'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s2),
            Row(children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: context.colors.inkSubtle),
              const SizedBox(width: 4),
              Expanded(child: Text('ما يتغيّر بعد إنشاء المجموعة', style: Theme.of(context).textTheme.labelSmall)),
            ]),
            const SizedBox(height: Space.s5),
            AtButton('أنشئ', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  final GroupApi api;

  const _JoinSheet({required this.api});

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (code == null || !mounted) return;
    _code.text = code;
    _submit(); // join right away
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.api.join(code);
      if (mounted) {
        showMessage(context, 'انضميت للمجموعة');
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
    return SheetBody(
      title: 'انضم لمجموعة',
      icon: Icons.login_rounded,
      error: _error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AtButton(
            'امسح الباركود',
            kind: AtButtonKind.outline,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _scan,
          ),
          const SizedBox(height: Space.s4),
          Text('أو اكتب الكود', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: Space.s2),
          TextField(
            controller: _code,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'كود الدعوة'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.s5),
          AtButton('انضم', onPressed: _submit, loading: _loading),
        ],
      ),
    );
  }
}
