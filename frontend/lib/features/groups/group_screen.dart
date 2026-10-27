import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'board_tab.dart';
import 'chat_tab.dart';
import 'group_activity.dart';
import 'group_api.dart';
import 'group_labels.dart';
import 'group_ui.dart';
import 'group_widgets.dart';
import 'group_matching_screen.dart';
import 'match_tab.dart';
import 'moments_tab.dart';
import 'week_tab.dart';

// OWNER: Fai - one group (design: GroupBoard header): the board (goal, proposals, alerts), the chat, the moments, the week (settlement and titles)
class GroupScreen extends StatefulWidget {
  final int groupId;

  const GroupScreen({super.key, required this.groupId});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupData {
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? goal;
  final bool isOwner;

  _GroupData(this.group, this.members, this.goal, this.isOwner);
}

class _GroupScreenState extends State<GroupScreen> with SingleTickerProviderStateMixin {
  late final GroupApi _api = GroupApi(context.read<ApiClient>());
  int? _me;
  Key _key = UniqueKey();
  late final TabController _tabs = TabController(length: 5, vsync: this);

  static const _tabLabels = ['اللوحة', 'الشات', 'اللحظات', 'الأسبوع', 'المنافسة'];
  // the place of every tab where something can be new (the week and the competition have none)
  static const _tabKinds = [GroupActivity.alert, GroupActivity.chat, GroupActivity.moments, null, null];

  // the open tab is seen: its red dot goes away, also when something new comes while I am on it
  void _seeOpenTab() {
    final kind = _tabKinds[_tabs.index];
    if (kind != null) GroupActivity.instance.markSeen(widget.groupId, kind);
  }

  @override
  void initState() {
    super.initState();
    _me = context.read<AuthState>().userId;
    _tabs.addListener(_seeOpenTab);
    GroupActivity.instance.addListener(_seeOpenTab);
    _seeOpenTab();
  }

  @override
  void dispose() {
    GroupActivity.instance.removeListener(_seeOpenTab);
    _seeOpenTab();
    _tabs.dispose();
    super.dispose();
  }

  Future<_GroupData> _load() async {
    final results = await Future.wait<Object?>([_api.group(widget.groupId), _api.members(widget.groupId), _api.activeGoal(widget.groupId)]);
    final group = results[0] as Map<String, dynamic>;
    final members = results[1] as List<Map<String, dynamic>>;
    final isOwner = members.any((m) => m['memberId'] == _me && m['role'] == 'OWNER');
    return _GroupData(group, members, results[2] as Map<String, dynamic>?, isOwner);
  }

  void _refresh() => setState(() => _key = UniqueKey());

  Future<void> _onMenu(String action, _GroupData data) async {
    final id = widget.groupId;
    switch (action) {
      case 'invite':
        await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _InviteSheet(api: _api, groupId: id, isOwner: data.isOwner));
      case 'members':
        final changed = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _MembersSheet(api: _api, groupId: id, members: data.members, me: _me, isOwner: data.isOwner),
        );
        if (changed == true) _refresh();
      case 'matching': // AI Group Matching - Abdulelah
        final memberId = _me;
        if (memberId == null) {
          showMessage(context, 'سجّل الدخول أولاً');
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GroupMatchingScreen(groupId: id, memberId: memberId)),
        );
      case 'points':
        await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _PointsSheet(api: _api, group: data.group));
      case 'edit':
        final saved = await showModalBottomSheet<bool>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _EditSheet(api: _api, group: data.group));
        if (saved == true) _refresh();
      case 'add':
        await showModalBottomSheet<bool>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _AddMemberSheet(api: _api, groupId: id, members: data.members));
        _refresh(); // friends may be added from the list
      case 'leave':
        if (!await confirm(context, 'تطلع من المجموعة؟', 'المرات اللي باقية لك هالأسبوع في هدف المجموعة تنحسب عليك.', yes: 'اطلع')) return;
        await _run(() => _api.leave(id), done: 'طلعت من المجموعة', pop: true);
      case 'archive':
        if (data.group['activeGoalTitle'] != null) {
          showMessage(context, 'فيه هدف شغّال بالمجموعة، تقدر تحذفها بعد ما يخلص.');
          return;
        }
        if (!await confirm(context, 'تحذف المجموعة؟', '', yes: 'احذف')) return;
        await _run(() => _api.archive(id), done: 'انحذفت المجموعة', pop: true);
    }
  }

  Future<void> _run(Future<void> Function() action, {required String done, bool pop = false}) async {
    try {
      await action();
      if (!mounted) return;
      showMessage(context, done);
      if (pop) context.pop();
    } catch (e) {
      if (mounted) showGroupError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_GroupData>(
      key: _key,
      load: () => inArabic(_load()),
      builder: (context, data, reload) {
        final name = '${data.group['name'] ?? ''}';
        final c = context.colors;
        // the page color of every tab: the round corners of the header sit on it
        final pages = [c.bg, c.bg, paperColor(c), c.bg, const Color(0xFF0A1A3A)];
        return AnimatedBuilder(
          animation: _tabs.animation!,
          builder: (context, child) {
            final t = _tabs.animation!.value.clamp(0.0, pages.length - 1.0);
            final i = t.floor();
            final color = i >= pages.length - 1 ? pages.last : Color.lerp(pages[i], pages[i + 1], t - i)!;
            return Scaffold(backgroundColor: color, body: child);
          },
          child: Column(
            children: [
              _TeamHeader(
                data: data,
                groupId: widget.groupId,
                tabs: _tabs,
                labels: _tabLabels,
                kinds: _tabKinds,
                onPoints: () => _onMenu('points', data),
                menu: Semantics(
                  button: true,
                  label: 'خيارات المجموعة',
                  child: GestureDetector(
                  onTap: () async {
                    final action = await showAtSheet<String>(context, builder: (_) => _GroupMenuSheet(data: data, groupId: widget.groupId));
                    if (action != null && mounted) await _onMenu(action, data);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                  ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    BoardTab(api: _api, group: data.group, isOwner: data.isOwner, me: _me, onChanged: _refresh, onInvite: () => _onMenu('invite', data)),
                    ChatTab(api: _api, groupId: widget.groupId, me: _me),
                    MomentsTab(api: _api, groupId: widget.groupId, me: _me),
                    WeekTab(api: _api, groupId: widget.groupId, groupName: name, members: data.members, me: _me),
                    MatchTab(api: _api, groupId: widget.groupId, isOwner: data.isOwner, me: _me, onChanged: _refresh),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- the team colored header: back, name, the goal and the week, the points, and the pill tabs ----------
class _TeamHeader extends StatelessWidget {
  final _GroupData data;
  final int groupId;
  final TabController tabs;
  final List<String> labels;
  final List<String?> kinds;
  final Widget menu;
  final VoidCallback onPoints;

  const _TeamHeader({required this.data, required this.groupId, required this.tabs, required this.labels, required this.kinds, required this.menu, required this.onPoints});

  // "قراءة ٢٠ صفحة × ٤ · الأسبوع ٣ من ٤"
  String _subtitle() {
    final goal = data.goal;
    if (goal == null) {
      final description = '${data.group['description'] ?? ''}';
      return description.isNotEmpty ? description : 'ما فيه هدف شغّال، صوّتوا على الجاي';
    }
    final base = '${goal['title'] ?? ''} × ${arabicDigits(goal['timesPerWeek'] ?? '')}';
    final start = DateTime.tryParse('${goal['startDate']}');
    final total = goal['totalWeeks'] as int?;
    if (start == null) return base;
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day).difference(start).inDays;
    if (days < 0) return '$base · يبدأ ${dayAr(goal['startDate'])}';
    final week = days ~/ 7 + 1;
    return '$base · الأسبوع ${arabicDigits(week)}${total == null ? '' : ' من ${arabicDigits(total)}'}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final team = teamColor(groupId);
    const soft = Color(0xE6FFFFFF); // white text on the team colors (90%)
    final name = '${data.group['name'] ?? ''}';
    return Container(
      decoration: BoxDecoration(color: team, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26))),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  HeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onPressed: () => Navigator.maybePop(context)),
                  const SizedBox(width: Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: text.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_subtitle(), style: text.labelSmall!.copyWith(color: soft), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s2),
                  Semantics(
                    button: true,
                    label: 'نقاط المجموعة ${data.group['points'] ?? 0} من ${data.group['pointsForGraceDay'] ?? 300}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.md),
                      onTap: onPoints,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Column(
                          children: [
                            CountUp((data.group['points'] as int?) ?? 0, style: text.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                            Text('من ${arabicDigits(data.group['pointsForGraceDay'] ?? 300)}', style: text.labelSmall!.copyWith(color: soft, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s2),
                  menu,
                ],
              ),
              const SizedBox(height: 14),
              ListenableBuilder(
                listenable: Listenable.merge([tabs, GroupActivity.instance]),
                builder: (context, _) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < labels.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        PillTab(
                          label: labels[i],
                          team: team,
                          selected: tabs.index == i,
                          hasNew: kinds[i] != null && GroupActivity.instance.hasNewIn(groupId, kinds[i]!),
                          onTap: () => tabs.animateTo(i),
                        ),
                      ],
                    ],
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

// ---------- the group menu ----------
// the group's things as icon tiles (3 in a row), the way out at the bottom in red
class _GroupMenuSheet extends StatelessWidget {
  final _GroupData data;
  final int groupId;

  const _GroupMenuSheet({required this.data, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final team = teamColor(groupId);
    final items = <(String, IconData, String, Color)>[
      ('invite', Icons.qr_code_2_rounded, 'كود الدعوة', team),
      ('members', Icons.groups_rounded, 'الأعضاء', c.primary),
      ('points', Icons.stars_rounded, 'النقاط', c.pardon),
      ('matching', Icons.sports_kabaddi_rounded, 'التحديات', c.urgent),
      if (data.isOwner) ('add', Icons.person_add_alt_1_rounded, 'أضف عضو', c.success),
      if (data.isOwner) ('edit', Icons.edit_rounded, 'تعديل', c.info),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TeamAvatar(name: '${data.group['name'] ?? ''}', color: team, size: 44),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Text('${data.group['name'] ?? ''}', style: text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: Space.s4),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final (i, (action, icon, label, color)) in items.indexed)
                Appear(
                  index: i,
                  child: Material(
                    color: c.surfaceSunken,
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.card),
                      onTap: () => Navigator.pop(context, action),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconTile(icon, size: 46, fg: Colors.white, bg: color),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(label, style: text.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: c.ink)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.s3),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, data.isOwner ? 'archive' : 'leave'),
            style: TextButton.styleFrom(foregroundColor: c.danger, minimumSize: const Size.fromHeight(48)),
            icon: Icon(data.isOwner ? Icons.delete_outline_rounded : Icons.logout_rounded, size: 20),
            label: Text(data.isOwner ? 'احذف المجموعة' : 'اطلع من المجموعة'),
          ),
        ],
      ),
    );
  }
}

// ---------- invite ----------
class _InviteSheet extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final bool isOwner;

  const _InviteSheet({required this.api, required this.groupId, required this.isOwner});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late Future<Map<String, dynamic>> _invite = widget.api.invite(widget.groupId);

  Future<void> _reset() async {
    if (!await confirm(context, 'كود جديد؟', 'الكود القديم ما عاد يشتغل.', yes: 'غيّر الكود')) return;
    setState(() {
      _invite = widget.api.resetInvite(widget.groupId);
    });
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    showMessage(context, 'تم نسخ الكود');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final team = teamColor(widget.groupId);
    return SheetBody(
      title: 'ادعُ أصحابك',
      icon: Icons.qr_code_2_rounded,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _invite,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 260, child: LoadingView());
          if (snap.hasError) return ErrorView(message: errorText(snap.error!));
          final code = '${snap.data!['inviteCode'] ?? ''}';
          final qr = '${snap.data!['qrContent'] ?? code}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // a ticket in the team color: the QR on white, the code under it
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: team, borderRadius: BorderRadius.circular(24)),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: -30,
                      end: -30,
                      child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1))),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.s4, Space.s5, Space.s4, Space.s4),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: QrImageView(
                              data: qr,
                              size: 170,
                              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: c.deep),
                              dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: c.deep),
                            ),
                          ),
                          const SizedBox(height: Space.s4),
                          // every letter of the code in its own white box
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                for (final ch in code.characters)
                                  Container(
                                    width: 32,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                                    child: Text(ch, style: text.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.s4),
              AtButton('انسخ الكود', icon: const Icon(Icons.copy_rounded, size: 18), onPressed: () => _copy(code)),
              if (widget.isOwner) ...[
                const SizedBox(height: Space.s2),
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('كود جديد'),
                  style: TextButton.styleFrom(foregroundColor: c.inkMuted),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------- members ----------
// everyone with his points; tap a friend to see his groups and add him to a group you own
class _MembersSheet extends StatelessWidget {
  final GroupApi api;
  final int groupId;
  final List<Map<String, dynamic>> members;
  final int? me;
  final bool isOwner;

  const _MembersSheet({required this.api, required this.groupId, required this.members, required this.me, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final sorted = [...members]..sort((a, b) => ((b['points'] as int?) ?? 0).compareTo((a['points'] as int?) ?? 0));
    return SheetBody(
      title: 'الأعضاء',
      icon: Icons.groups_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${arabicDigits(members.length)} من ${arabicDigits(10)} أعضاء', style: text.labelSmall)),
              Text('مرتّبين بالنقاط', style: text.labelSmall),
            ],
          ),
          const SizedBox(height: Space.s2),
          for (final (i, m) in sorted.indexed) ...[
            Appear(
              index: i,
              child: RaisedCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                highlight: m['memberId'] == me ? c.primary : null,
                child: Row(
                  children: [
                    MemberAvatar('${m['name'] ?? ''}', size: 40),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['memberId'] == me ? 'أنت' : '${m['name'] ?? ''}', style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
                          Text('${arabicDigits(m['points'] ?? 0)} نقطة · انضم ${dayAr(m['joinedAt'])}', style: text.labelSmall),
                        ],
                      ),
                    ),
                    if (((m['failureCount'] as int?) ?? 0) > 0) ...[
                      Tooltip(
                        message: 'ما كمّل أسبوعه مرة، المرة الثانية يطلع من المجموعة',
                        child: Pill('إنذار', fg: c.warning, bg: c.warningSoft, dot: true),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (m['role'] == 'OWNER') Pill('المنشئ', fg: c.primary, bg: c.primarySoft),
                    if (m['memberId'] != me) Icon(Icons.chevron_left_rounded, color: c.inkSubtle),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s2),
          ],
        ],
      ),
    );
  }
}

// ---------- the group points: how they are collected and their log ----------
class _PointsSheet extends StatelessWidget {
  final GroupApi api;
  final Map<String, dynamic> group;

  const _PointsSheet({required this.api, required this.group});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final points = (group['points'] as int?) ?? 0;
    final target = (group['pointsForGraceDay'] as int?) ?? 300;
    Widget rule(String label, int value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: text.bodySmall)),
            Text('+${arabicDigits(value)}', style: text.labelLarge!.copyWith(color: c.accent, fontWeight: FontWeight.w800)),
          ]),
        );
    return SheetBody(
      title: 'نقاط المجموعة',
      icon: Icons.stars_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaisedCard(
            radius: Radii.card,
            color: c.pardonSoft,
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: target == 0 ? 0 : (points / target).clamp(0, 1).toDouble()),
                          duration: Motion.sign,
                          curve: Motion.easeOut,
                          builder: (context, v, _) => CircularProgressIndicator(value: v, strokeWidth: 7, strokeCap: StrokeCap.round, color: c.pardon, backgroundColor: c.surface),
                        ),
                      ),
                      CountUp(points, style: text.titleMedium!.copyWith(color: c.pardonText, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${arabicDigits(points)} من ${arabicDigits(target)}', style: text.titleMedium!.copyWith(color: c.pardonText, fontWeight: FontWeight.w800)),
                      Text('لما توصلون ${arabicDigits(target)} كل عضو ياخذ بطاقة عفو.', style: text.bodySmall!.copyWith(color: c.pardonText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const GroupSection('كيف تجمعونها'),
          rule('أسبوع ذهبي: كل الأعضاء كمّلوا الأسبوع', 50),
          rule('فوز بمنافسة ضد مجموعة ثانية', 100),
          rule('الأقل تسويف بالمنافسة', 50),
          rule('كل الأعضاء كمّلوا أسبوع المنافسة', 30),
          const GroupSection('السجل'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: api.groupPoints(group['id'] as int),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 120, child: LoadingView());
              if (snap.hasError) return ErrorView(message: errorText(snap.error!));
              final logs = snap.data!;
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s4),
                  child: Text('ما جمعتوا نقاط للحين. كمّلوا أسبوع كامل كلكم وتاخذون أول ٥٠.', style: text.bodySmall, textAlign: TextAlign.center),
                );
              }
              return Column(
                children: [
                  for (final (i, l) in logs.indexed)
                    Appear(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.s2),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: ((l['points'] as int?) ?? 0) < 0 ? c.pardonSoft : c.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                ((l['points'] as int?) ?? 0) < 0 ? Icons.style_rounded : Icons.bolt_rounded,
                                size: 18,
                                color: ((l['points'] as int?) ?? 0) < 0 ? c.pardon : c.primary,
                              ),
                            ),
                            const SizedBox(width: Space.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pointReasonsAr[l['reason']] ?? '${l['reason'] ?? ''}', style: text.labelLarge),
                                  Text(dayAr(l['createdAt']), style: text.labelSmall),
                                ],
                              ),
                            ),
                            Text(
                              '${((l['points'] as int?) ?? 0) > 0 ? '+' : ''}${arabicDigits(l['points'] ?? 0)}',
                              style: text.titleSmall!.copyWith(
                                color: ((l['points'] as int?) ?? 0) < 0 ? c.pardonText : c.accent,
                                fontWeight: FontWeight.w800,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------- edit ----------
class _EditSheet extends StatefulWidget {
  final GroupApi api;
  final Map<String, dynamic> group;

  const _EditSheet({required this.api, required this.group});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: '${widget.group['name'] ?? ''}');
  late final _description = TextEditingController(text: '${widget.group['description'] ?? ''}');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.api.update(widget.group['id'] as int, _name.text.trim(), _description.text.trim());
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
      title: 'تعديل المجموعة',
      icon: Icons.edit_rounded,
      error: _error,
      child: Column(
        children: [
          TextField(controller: _name, maxLength: 100, decoration: const InputDecoration(labelText: 'اسم المجموعة')),
          const SizedBox(height: Space.s2),
          TextField(controller: _description, maxLength: 255, maxLines: 2, decoration: const InputDecoration(labelText: 'الوصف')),
          const SizedBox(height: Space.s4),
          AtButton('احفظ', onPressed: _save, loading: _loading),
        ],
      ),
    );
  }
}

// ---------- add a friend: from my other groups, or by his phone number ----------
class _AddMemberSheet extends StatefulWidget {
  final GroupApi api;
  final int groupId;
  final List<Map<String, dynamic>> members;

  const _AddMemberSheet({required this.api, required this.groupId, required this.members});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _phone = TextEditingController();
  late final Future<List<Map<String, dynamic>>> _friends = _loadFriends();
  final Set<int> _added = {};
  bool _loading = false;
  int? _adding;
  String? _error;

  bool get _full => widget.members.length + _added.length >= 10;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  // the members of my other groups who are not in this group
  Future<List<Map<String, dynamic>>> _loadFriends() async {
    final inGroup = widget.members.map((m) => m['memberId']).toSet();
    final groups = (await widget.api.myGroups()).where((g) => g['groupId'] != widget.groupId).toList();
    final lists = await Future.wait(groups.map((g) => widget.api.members(g['groupId'] as int).catchError((_) => <Map<String, dynamic>>[])));
    final friends = <int, Map<String, dynamic>>{};
    for (final (i, list) in lists.indexed) {
      for (final m in list) {
        final id = m['memberId'] as int?;
        if (id == null || inGroup.contains(id)) continue;
        friends.putIfAbsent(id, () => {...m, 'from': groups[i]['groupName']});
      }
    }
    return friends.values.toList();
  }

  Future<void> _addFriend(Map<String, dynamic> friend) async {
    final id = friend['memberId'] as int;
    setState(() {
      _adding = id;
      _error = null;
    });
    try {
      await widget.api.addMember(widget.groupId, id);
      if (mounted) setState(() => _added.add(id));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _adding = null);
    }
  }

  Future<void> _add() async {
    final phone = _phone.text.trim();
    if (phone.length < 9) {
      setState(() => _error = 'اكتب رقم الجوال كامل، مثل 0501234567');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.addMemberByPhone(widget.groupId, phone);
      if (mounted) {
        showMessage(context, 'انضاف للمجموعة');
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
    return SheetBody(
        title: 'أضف عضو',
      icon: Icons.person_add_alt_1_rounded,
        error: _error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${arabicDigits(widget.members.length + _added.length)} من ${arabicDigits(10)} أعضاء', style: text.labelSmall),
            if (_full)
              Padding(
                padding: const EdgeInsets.only(top: Space.s2),
                child: Pill('المجموعة مليانة', fg: c.warning, bg: c.warningSoft, dot: true),
              ),
            const GroupSection('من أصحابك بمجموعاتك الثانية'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _friends,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 80, child: LoadingView());
                final friends = snap.data ?? const [];
                if (friends.isEmpty) return Text('ما فيه أحد من مجموعاتك الثانية برا هالمجموعة.', style: text.bodySmall);
                return Column(
                  children: [
                    for (final f in friends) ...[
                      Row(
                        children: [
                          MemberAvatar('${f['name'] ?? ''}', size: 36),
                          const SizedBox(width: Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${f['name'] ?? ''}', style: text.labelLarge),
                                Text('من ${f['from'] ?? ''}', style: text.labelSmall),
                              ],
                            ),
                          ),
                          if (_added.contains(f['memberId']))
                            Pill('انضاف', fg: c.success, bg: c.successSoft, dot: true)
                          else
                            AtButton('أضف', expand: false, kind: AtButtonKind.outline, loading: _adding == f['memberId'],
                                onPressed: _adding != null || _full ? null : () => _addFriend(f)),
                        ],
                      ),
                      const SizedBox(height: Space.s2),
                    ],
                  ],
                );
              },
            ),
            const GroupSection('أو برقم جواله'),
            TextField(
              controller: _phone,
              enabled: !_full,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم جواله',
                hintText: '05XXXXXXXX',
                helperText: 'لازم يكون مسجّل في أتعهّد بنفس الرقم',
              ),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: Space.s4),
            AtButton('أضف بالرقم', onPressed: _full ? null : _add, loading: _loading),
          ],
        ),
    );
  }
}
