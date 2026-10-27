import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/at_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'admin_tools_screen.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late final ApiClient _api = context.read<ApiClient>();
  late Future<Json> _data = _load();
  String _filter = 'ALL';
  bool _penalties = false;
  int get _adminId => context.read<AuthState>().userId!;
  Future<Json> _load() async {
    final values = await Future.wait([
      _api.get('/api/v1/admin-review/queue/$_adminId'),
      _api.get('/api/v1/admin-review/penalties/$_adminId')
    ]);
    return {'queue': values[0], 'penalties': values[1]};
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _review(Json item) async {
    try {
      if (item['kind'] == 'OBJECTION') {
        await _api.post('/api/v1/admin-review/start/$_adminId/${item['id']}');
      }
      if (!mounted) return;
      final decided = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => AdminReviewSheet(item: item, adminId: _adminId));
      if (decided == true) _reload();
    } catch (error) {
      if (mounted) proofError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ProofPage(
      title: 'مركز المراجعة',
      actions: [
        // the admin tools: member accounts and the proof methods
        IconButton(
            tooltip: 'الأعضاء',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMembersScreen())),
            icon: const Icon(Icons.manage_accounts_rounded)),
        IconButton(
            tooltip: 'طرق الإثبات',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProofMethodsScreen())),
            icon: const Icon(Icons.fact_check_rounded)),
        IconButton(
            tooltip: 'تحديث',
            onPressed: _reload,
            icon: const Icon(Icons.refresh)),
        IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<AuthState>().logout(),
            icon: const Icon(Icons.logout)),
      ],
      child: FutureBuilder<Json>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(
                  message: friendlyError(snapshot.error!), onRetry: _reload);
            }
            final queue = ProofsApi.maps(snapshot.data!['queue']);
            final penalties = ProofsApi.maps(snapshot.data!['penalties']);
            final shown = queue
                .where((q) => _filter == 'ALL' || q['kind'] == _filter)
                .toList();
            return ListView(padding: const EdgeInsets.all(24), children: [
              AppCard(
                  color: context.colors.primarySoft,
                  padding: const EdgeInsets.all(24),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('قرار واضح، ومراجعة عادلة',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 10),
                          Text(
                              '${arabicDigits(queue.length)} طلب ينتظر مراجعتك، مرتبة من الأقدم للأحدث.'),
                        ])),
                    Icon(Icons.policy_outlined,
                        color: context.colors.primary, size: 48),
                  ])),
              const SizedBox(height: 24),
              Wrap(spacing: 10, runSpacing: 10, children: [
                ChoiceChip(
                    label: const Text('طلبات المراجعة'),
                    selected: !_penalties,
                    onSelected: (_) => setState(() => _penalties = false)),
                ChoiceChip(
                    label: const Text('المبالغ'),
                    selected: _penalties,
                    onSelected: (_) => setState(() => _penalties = true))
              ]),
              const SizedBox(height: 20),
              if (!_penalties) ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final filter in {'ALL': 'الكل', ...kindNames}.entries)
                    FilterChip(
                        label: Text(filter.value),
                        selected: _filter == filter.key,
                        onSelected: (_) => setState(() => _filter = filter.key))
                ]),
                const SizedBox(height: 18),
                if (shown.isEmpty)
                  const ProofEmpty(
                      title: 'كل شيء تمت مراجعته',
                      message: 'ما فيه طلبات تنتظر في هذا القسم.',
                      icon: Icons.task_alt),
                for (final item in shown)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                          onTap: () => _review(item),
                          child: Row(children: [
                            Icon(
                                item['kind'] == 'DONATION'
                                    ? Icons.volunteer_activism_outlined
                                    : Icons.fact_check_outlined,
                                color: context.colors.primary),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${item['about']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 6),
                                  Text(
                                      '${item['memberName']} • ${kindNames[item['kind']] ?? ''}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 5),
                                  Text(displayDate(item['createdAt']),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ])),
                            const Icon(Icons.chevron_left),
                          ]))),
              ] else ...[
                if (penalties.isEmpty)
                  const ProofEmpty(
                      title: 'لا توجد مبالغ',
                      message: 'سجل مبالغ الأعضاء يظهر هنا.'),
                for (final penalty in penalties)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text('${penalty['memberName']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                              RiyalAmount(penalty['amount'] as num?)
                            ]),
                            const SizedBox(height: 8),
                            Text('${penalty['title']}'),
                            const SizedBox(height: 6),
                            Text(
                                '${displayDate(penalty['createdAt'])} • ${penalty['status'] == 'PENDING' ? 'بانتظار التبرع' : penalty['status'] == 'PAID' ? 'تم التبرع' : 'ملغي'}'),
                            if (penalty['status'] == 'PENDING')
                              AtButton('إلغاء المبلغ', kind: AtButtonKind.text,
                                  onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                            title: const Text('إلغاء المبلغ؟'),
                                            content: const Text(
                                                'يلغى هذا المبلغ عن العضو. تأكد من صحة القرار قبل المتابعة.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('تراجع')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text(
                                                      'إلغاء المبلغ'))
                                            ]));
                                if (confirmed != true) return;
                                try {
                                  await _api.put(
                                      '/api/v1/penalty/cancel/$_adminId/${penalty['id']}');
                                  await _reload();
                                } catch (error) {
                                  if (context.mounted) {
                                    proofError(context, error);
                                  }
                                }
                              }),
                          ]))),
              ],
            ]);
          }));
}

class AdminReviewSheet extends StatefulWidget {
  final Json item;
  final int adminId;
  const AdminReviewSheet(
      {super.key, required this.item, required this.adminId});
  @override
  State<AdminReviewSheet> createState() => _AdminReviewSheetState();
}

class _AdminReviewSheetState extends State<AdminReviewSheet> {
  final _note = TextEditingController();
  bool _busy = false;
  bool _accepting = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(bool accept) async {
    if (!accept &&
        widget.item['kind'] != 'OBJECTION' &&
        _note.text.trim().isEmpty) {
      showMessage(context, 'اكتب سببًا واضحًا يساعد العضو يفهم قرار الرفض.');
      return;
    }
    setState(() {
      _busy = true;
      _accepting = accept;
    });
    try {
      await context.read<ApiClient>().put(
          '/api/v1/admin-review/decide/${widget.adminId}/${widget.item['kind']}/${widget.item['id']}/$accept',
          query: {'note': _note.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) proofError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kindNames[widget.item['kind']] ?? 'مراجعة طلب',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 10),
                        Text('${widget.item['about']}',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(
                            '${widget.item['memberName']} • ${displayDate(widget.item['createdAt'])}'),
                        const SizedBox(height: 20),
                        ProofNotice('${widget.item['details'] ?? ''}'),
                        if (widget.item['aiNote'] != null) ...[
                          const SizedBox(height: 18),
                          Text('سبب القرار الآلي',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('${widget.item['aiNote']}')
                        ],
                        for (final image
                            in widget.item['evidence'] as List? ?? [])
                          Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: EvidenceImage('$image')),
                        const SizedBox(height: 24),
                        if (widget.item['kind'] != 'OBJECTION')
                          TextField(
                              controller: _note,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 1000,
                              decoration: const InputDecoration(
                                  labelText: 'ملاحظة المراجعة',
                                  hintText:
                                      'وضح سبب القرار للعضو، خصوصًا عند الرفض.')),
                        const SizedBox(height: 20),
                        AtButton('قبول الطلب',
                            loading: _busy && _accepting,
                            onPressed: _busy ? null : () => _decide(true)),
                        const SizedBox(height: 10),
                        AtButton('رفض الطلب',
                            kind: AtButtonKind.outline,
                            loading: _busy && !_accepting,
                            onPressed: _busy ? null : () => _decide(false)),
                      ])))));
}
