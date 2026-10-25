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
import 'group_widgets.dart';
import 'scan_screen.dart';

// OWNER: Fai - the "المجموعات" tab: my groups, create a group, join with a code
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupApi _api = GroupApi(context.read<ApiClient>());
  final _activity = GroupActivity.instance;
  Key _listKey = UniqueKey();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
    final groups = await _api.myGroups();
    if (mounted) _activity.check(_api, groups, context.read<AuthState>().userId);
    return groups;
  }

  void _refresh() => setState(() => _listKey = UniqueKey());

  Future<void> _open(int groupId) async {
    await context.push('/group/$groupId');
    _refresh(); // the group may be left or archived
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
      appBar: AppBar(title: const Text('المجموعات')),
      body: AsyncView<List<Map<String, dynamic>>>(
        key: _listKey,
        load: _loadGroups,
        builder: (context, groups, reload) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(Space.s4),
              children: [
                Row(
                  children: [
                    Expanded(child: AtButton('أنشئ مجموعة', onPressed: _create)),
                    const SizedBox(width: Space.s3),
                    Expanded(child: AtButton('انضم بالكود', onPressed: _join, kind: AtButtonKind.outline)),
                  ],
                ),
                const SizedBox(height: Space.s5),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.s10),
                    child: EmptyView(
                      message: 'ما انضميت لمجموعة للحين.\nسوّ مجموعة مع أصحابك، أو اطلب منهم كود الدعوة.',
                      icon: Icons.groups_outlined,
                    ),
                  ),
                for (final g in groups) ...[
                  _GroupTile(group: g, hasNew: _activity.hasNew(g['groupId'] as int), onTap: () => _open(g['groupId'] as int)),
                  const SizedBox(height: Space.s3),
                ],
                if (groups.isNotEmpty)
                  Text('اسحب لتحت عشان تحدّث', style: text.labelSmall, textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool hasNew; // something new in the group since I opened it
  final VoidCallback onTap;

  const _GroupTile({required this.group, required this.hasNew, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = '${group['groupName'] ?? ''}';
    final color = AtColors.team(((group['groupId'] as int?) ?? 1) - 1);
    final isOwner = group['role'] == 'OWNER';
    return AppCard(
      color: color,
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(name.isEmpty ? '' : name.characters.first, style: text.headlineSmall!.copyWith(color: Colors.white)),
              ),
              if (hasNew)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: const Color(0xFFE5484D), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.headlineSmall!.copyWith(color: Colors.white)),
                Text(hasNew ? 'فيه جديد' : (isOwner ? 'منشئ المجموعة' : 'عضو'),
                    style: text.labelSmall!.copyWith(color: Colors.white, fontWeight: hasNew ? FontWeight.w700 : null)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(arabicDigits(group['points'] ?? 0), style: text.headlineSmall!.copyWith(color: Colors.white)),
              Text('نقطة', style: text.labelSmall!.copyWith(color: Colors.white70)),
            ],
          ),
        ],
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
      final group = await widget.api.create(_name.text.trim(), _description.text.trim());
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
