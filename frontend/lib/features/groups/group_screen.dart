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
import 'group_widgets.dart';
import 'moments_tab.dart';
import 'week_tab.dart';

// OWNER: Fai - one group: the board (goal, proposals, alerts), the chat, the moments, the week (settlement and titles)
class GroupScreen extends StatefulWidget {
  final int groupId;

  const GroupScreen({super.key, required this.groupId});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupData {
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> members;
  final bool isOwner;

  _GroupData(this.group, this.members, this.isOwner);
}

class _GroupScreenState extends State<GroupScreen> {
  late final GroupApi _api = GroupApi(context.read<ApiClient>());
  late final int? _me = context.read<AuthState>().userId;
  Key _key = UniqueKey();

  @override
  void initState() {
    super.initState();
    GroupActivity.instance.markSeen(widget.groupId); // the red dot goes away
  }

  @override
  void dispose() {
    GroupActivity.instance.markSeen(widget.groupId); // what I saw inside is not new
    super.dispose();
  }

  Future<_GroupData> _load() async {
    final results = await Future.wait([_api.group(widget.groupId), _api.members(widget.groupId)]);
    final group = results[0] as Map<String, dynamic>;
    final members = results[1] as List<Map<String, dynamic>>;
    final isOwner = members.any((m) => m['memberId'] == _me && m['role'] == 'OWNER');
    return _GroupData(group, members, isOwner);
  }

  void _refresh() => setState(() => _key = UniqueKey());

  Future<void> _onMenu(String action, _GroupData data) async {
    final id = widget.groupId;
    switch (action) {
      case 'invite':
        await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _InviteSheet(api: _api, groupId: id, isOwner: data.isOwner));
      case 'members':
        await showModalBottomSheet(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _MembersSheet(members: data.members, me: _me));
      case 'edit':
        final saved = await showModalBottomSheet<bool>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _EditSheet(api: _api, group: data.group));
        if (saved == true) _refresh();
      case 'add':
        final added = await showModalBottomSheet<bool>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => _AddMemberSheet(api: _api, groupId: id));
        if (added == true) _refresh();
      case 'leave':
        if (!await confirm(context, 'تطلع من المجموعة؟', 'المرات اللي باقية لك هالأسبوع في هدف المجموعة تنحسب عليك.', yes: 'اطلع')) return;
        await _run(() => _api.leave(id), done: 'طلعت من المجموعة', pop: true);
      case 'archive':
        if (data.group['activeGoalTitle'] != null) {
          showMessage(context, 'فيه هدف شغّال بالمجموعة، تقدر تحذفها بعد ما يخلص.');
          return;
        }
        if (!await confirm(context, 'تحذف المجموعة؟', 'المجموعة تتأرشف وسجلها يبقى.', yes: 'احذف')) return;
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
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_GroupData>(
      key: _key,
      load: _load,
      builder: (context, data, reload) {
        final name = '${data.group['name'] ?? ''}';
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(name),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (a) => _onMenu(a, data),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'invite', child: Text('كود الدعوة')),
                    const PopupMenuItem(value: 'members', child: Text('الأعضاء')),
                    if (data.isOwner) const PopupMenuItem(value: 'edit', child: Text('تعديل المجموعة')),
                    if (data.isOwner) const PopupMenuItem(value: 'add', child: Text('أضف عضو')),
                    if (!data.isOwner) const PopupMenuItem(value: 'leave', child: Text('اطلع من المجموعة')),
                    if (data.isOwner) const PopupMenuItem(value: 'archive', child: Text('احذف المجموعة')),
                  ],
                ),
              ],
              bottom: const TabBar(
                tabs: [Tab(text: 'اللوحة'), Tab(text: 'الشات'), Tab(text: 'اللحظات'), Tab(text: 'الأسبوع')],
              ),
            ),
            body: TabBarView(
              children: [
                BoardTab(api: _api, group: data.group, isOwner: data.isOwner, me: _me, onChanged: _refresh, onInvite: () => _onMenu('invite', data)),
                ChatTab(api: _api, groupId: widget.groupId, me: _me),
                MomentsTab(api: _api, groupId: widget.groupId, me: _me),
                WeekTab(api: _api, groupId: widget.groupId, groupName: name, members: data.members),
              ],
            ),
          ),
        );
      },
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
    setState(() => _invite = widget.api.resetInvite(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return SheetBody(
      title: 'ادعُ أصحابك',
      child: FutureBuilder<Map<String, dynamic>>(
        future: _invite,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 200, child: LoadingView());
          if (snap.hasError) return ErrorView(message: '${snap.error}');
          final code = '${snap.data!['inviteCode'] ?? ''}';
          final qr = '${snap.data!['qrContent'] ?? code}';
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(Space.s3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.lg)),
                child: QrImageView(data: qr, size: 180, eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.deep), dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: c.deep)),
              ),
              const SizedBox(height: Space.s4),
              Text('أو شارك الكود', style: text.bodySmall),
              const SizedBox(height: Space.s2),
              InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showMessage(context, 'تم نسخ الكود');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s5, vertical: Space.s3),
                  decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(code, style: text.headlineMedium!.copyWith(letterSpacing: 2), textDirection: TextDirection.ltr),
                      const SizedBox(width: Space.s3),
                      Icon(Icons.copy_rounded, size: 20, color: c.inkSubtle),
                    ],
                  ),
                ),
              ),
              if (widget.isOwner) ...[
                const SizedBox(height: Space.s4),
                AtButton('غيّر الكود', onPressed: _reset, kind: AtButtonKind.text),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------- members ----------
class _MembersSheet extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final int? me;

  const _MembersSheet({required this.members, required this.me});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetBody(
      title: 'الأعضاء (${arabicDigits(members.length)})',
      child: Column(
        children: [
          for (final m in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: NameAvatar('${m['name'] ?? ''}'),
              title: Text('${m['name'] ?? ''}${m['memberId'] == me ? ' (أنت)' : ''}', style: text.labelLarge),
              subtitle: Text('${arabicDigits(m['points'] ?? 0)} نقطة', style: text.labelSmall),
              trailing: m['role'] == 'OWNER' ? const StatusBadge('منشئ المجموعة', kind: BadgeKind.success) : null,
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

// ---------- add a friend by his phone number ----------
class _AddMemberSheet extends StatefulWidget {
  final GroupApi api;
  final int groupId;

  const _AddMemberSheet({required this.api, required this.groupId});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
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
    return SheetBody(
      title: 'أضف عضو',
      error: _error,
      child: Column(
        children: [
          TextField(
            controller: _phone,
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
          AtButton('أضف', onPressed: _add, loading: _loading),
        ],
      ),
    );
  }
}
