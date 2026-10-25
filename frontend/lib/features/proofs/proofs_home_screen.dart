import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'proof_widgets.dart';
import 'proofs_api.dart';
import 'request_forms.dart';

class ProofsHomeScreen extends StatefulWidget {
  final int initialTab;
  final bool requestsOnly;
  const ProofsHomeScreen(
      {super.key, this.initialTab = 0, this.requestsOnly = false});
  @override
  State<ProofsHomeScreen> createState() => _ProofsHomeScreenState();
}

class _ProofsHomeScreenState extends State<ProofsHomeScreen> {
  late final ProofsApi _api = ProofsApi(context.read<ApiClient>());
  late Future<Json> _data = _load();
  late int _tab = widget.initialTab;
  String _filter = 'ALL';
  Future<Json> _load() async {
    final values =
        await Future.wait<dynamic>([_api.workspace(), _api.activities()]);
    return {...values[0] as Json, 'activities': values[1]};
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _openRecord(Json item, String kind) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            RecordDetails(item: item, kind: kind, onChanged: _reload));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return ProofPage(
        title: widget.requestsOnly ? 'طلباتي' : 'سجل الإثباتات',
        actions: [
          IconButton(
              tooltip: 'تحديث',
              onPressed: _reload,
              icon: const Icon(Icons.refresh)),
          IconButton(
              tooltip: 'الصفحة الرئيسية',
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined)),
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
              final data = snapshot.data!;
              final proofs = ProofsApi.maps(data['proofs']);
              final excuses = ProofsApi.maps(data['excuses']);
              final objections = ProofsApi.maps(data['objections']);
              final activities = ProofsApi.maps(data['activities']);
              final accepted =
                  proofs.where((p) => p['status'] == 'ACCEPTED').length;
              final waiting = [...proofs, ...excuses, ...objections]
                  .where((p) =>
                      p['status'] == 'PENDING' || p['status'] == 'ESCALATED')
                  .length;
              final records = switch (_tab) {
                1 => proofs,
                2 => excuses,
                3 => objections,
                _ => <Json>[]
              };
              final shown = records
                  .where((p) =>
                      _filter == 'ALL' ||
                      p['status'] == _filter ||
                      (_filter == 'PENDING' && p['status'] == 'ESCALATED'))
                  .toList();
              return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                      padding: const EdgeInsets.all(Space.s5),
                      children: [
                        AppCard(
                            color: colors.primarySoft,
                            padding: const EdgeInsets.all(24),
                            child: LayoutBuilder(
                                builder: (context, constraints) =>
                                    Row(children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(
                                                widget.requestsOnly
                                                    ? 'إرفاق الأعذار والاعتراضات'
                                                    : 'كل خطوة منك، لها أثر',
                                                style: text.headlineMedium),
                                            if (!widget.requestsOnly) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                  'وثّق إنجازك بالطريقة اللي تناسب نشاطك، وخذ الأمور خطوة خطوة.',
                                                  style: text.bodyMedium),
                                            ],
                                            const SizedBox(height: 16),
                                            Wrap(
                                                spacing: 14,
                                                runSpacing: 8,
                                                children: [
                                                  _metric(
                                                      'إنجاز موثّق',
                                                      accepted,
                                                      Icons.verified_outlined),
                                                  _metric('طلب ينتظر', waiting,
                                                      Icons.schedule),
                                                ]),
                                          ])),
                                      if (constraints.maxWidth > 600) ...[
                                        const SizedBox(width: 24),
                                        Icon(Icons.fact_check_outlined,
                                            size: 86, color: colors.primary)
                                      ],
                                    ]))),
                        const SizedBox(height: 22),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          AtButton('عرض التبرعات والمبالغ',
                              kind: AtButtonKind.gold,
                              expand: false,
                              icon:
                                  const Icon(Icons.volunteer_activism_outlined),
                              onPressed: () =>
                                  context.push('/proofs/donations')),
                          if (widget.requestsOnly)
                            AtButton('سجل إثباتاتي',
                                kind: AtButtonKind.outline,
                                expand: false,
                                onPressed: () => context.push('/proofs')),
                          AtButton('تقديم عذر',
                              kind: AtButtonKind.outline,
                              expand: false,
                              icon: const Icon(Icons.event_busy_outlined),
                              onPressed: activities.isEmpty
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ExcuseFormScreen(
                                                  activities: activities)));
                                      _reload();
                                    }),
                        ]),
                        const SizedBox(height: 24),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final (index, label) in [
                            'أنشطة اليوم',
                            'الإثباتات',
                            'الأعذار',
                            'الاعتراضات'
                          ].indexed.where(
                              (entry) => !widget.requestsOnly || entry.$1 >= 2))
                            ChoiceChip(
                                label: Text(label),
                                selected: _tab == index,
                                onSelected: (_) => setState(() {
                                      _tab = index;
                                      _filter = 'ALL';
                                    })),
                        ]),
                        const SizedBox(height: 20),
                        if (_tab == 0) ...[
                          Row(children: [
                            Expanded(
                                child: Text('وش أنجزت اليوم؟',
                                    style: text.headlineSmall)),
                            Text('${arabicDigits(activities.length)} نشاط',
                                style: text.bodySmall)
                          ]),
                          const SizedBox(height: 14),
                          if (activities.isEmpty)
                            const ProofEmpty(
                                title: 'مساحة لإنجازك القادم',
                                message:
                                    'ما عندك أنشطة حاليًا. بعد إضافة هدف أو عادة، تظهر مهامك هنا وتقدر توثّقها.'),
                          LayoutBuilder(builder: (context, constraints) {
                            final width = constraints.maxWidth > 700
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth;
                            return Wrap(spacing: 16, runSpacing: 16, children: [
                              for (final task in activities)
                                SizedBox(
                                    width: width,
                                    child: _activity(task, proofs))
                            ]);
                          }),
                        ] else ...[
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final choice in {
                              'ALL': 'الكل',
                              'PENDING': 'قيد الانتظار',
                              'ACCEPTED': 'مقبول',
                              'REJECTED': 'مرفوض'
                            }.entries)
                              FilterChip(
                                  label: Text(choice.value),
                                  selected: _filter == choice.key,
                                  onSelected: (_) =>
                                      setState(() => _filter = choice.key)),
                          ]),
                          const SizedBox(height: 16),
                          if (shown.isEmpty)
                            const ProofEmpty(
                                title: 'السجل هادئ للحين',
                                message:
                                    'طلباتك تظهر هنا بعد إرسالها، وتقدر تتابع حالتها من المكان نفسه.',
                                icon: Icons.history),
                          for (final item in shown)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                    onTap: () => _openRecord(
                                        item,
                                        [
                                          '',
                                          'PROOF',
                                          'EXCUSE',
                                          'OBJECTION'
                                        ][_tab]),
                                    child: Row(children: [
                                      Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                              color: colors.surfaceSunken,
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Icon(
                                              _tab == 1
                                                  ? methodIcon(
                                                      item['type'] as String?)
                                                  : _tab == 2
                                                      ? Icons
                                                          .event_busy_outlined
                                                      : Icons.forum_outlined,
                                              color: colors.primary)),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text('${item['title'] ?? 'طلبك'}',
                                                style: text.titleMedium),
                                            const SizedBox(height: 5),
                                            Text(
                                                displayDate(
                                                    item['activityTime'] ??
                                                        item['createdAt']),
                                                style: text.bodySmall?.copyWith(
                                                    color: colors.inkMuted)),
                                          ])),
                                      const SizedBox(width: 8),
                                      StatusBadge.review(
                                          item['status'] as String?),
                                    ]))),
                        ],
                        const SizedBox(height: 24),
                        const ProofNotice(
                            'لو احتجت تعترض على قرار مرفوض، تقدر خلال ٤٨ ساعة من صدور القرار. كل طلب يخص نشاطك أنت فقط.'),
                      ]));
            }));
  }

  Widget _metric(String label, int count, IconData icon) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 6),
        Text('${arabicDigits(count)} $label',
            style: Theme.of(context).textTheme.labelLarge),
      ]);
  Widget _activity(Json task, List<Json> proofs) {
    Json? active;
    final day = dateInput(riyadhNow());
    for (final proof in proofs) {
      if (proof['weekId'] == task['weekId'] &&
          proof['goalTaskId'] == task['goalTaskId'] &&
          '${proof['activityTime']}'.startsWith(day) &&
          proof['status'] != 'REJECTED') {
        active = proof;
        break;
      }
    }
    final existing = active;
    final done = existing?['status'] == 'ACCEPTED' ||
        (task['remaining'] as num? ?? 1) <= 0;
    return AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(methodIcon(task['proofMethod'] as String?),
                color: context.colors.primary),
            const Spacer(),
            StatusBadge.track(task['trackStatus'] as String?)
          ]),
          const SizedBox(height: 16),
          Text('${task['title']}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 7),
          Text(methodNames[task['proofMethod']] ?? 'إثبات نشاط',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          LinearProgressIndicator(
              value: ((task['completed'] as num? ?? 0) /
                      ((task['required'] as num? ?? 1).clamp(1, 999)))
                  .clamp(0, 1)
                  .toDouble(),
              borderRadius: BorderRadius.circular(8),
              minHeight: 6),
          const SizedBox(height: 8),
          Text(
              '${arabicDigits(task['completed'])} من ${arabicDigits(task['required'])} إنجازات هذا الأسبوع',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          AtButton(
              done
                  ? 'إنجازك موثّق'
                  : existing != null
                      ? 'تابع إثباتك'
                      : 'وثّق إنجازك',
              onPressed: done
                  ? null
                  : () async {
                      if (existing != null && existing['managed'] == true) {
                        await context.push(
                            '/proofs/session/${existing['id']}?title=${Uri.encodeComponent('${task['title']}')}');
                      } else if (existing != null) {
                        await _openRecord(existing, 'PROOF');
                      } else {
                        await context.push('/proofs/start', extra: task);
                      }
                      _reload();
                    },
              icon: Icon(done ? Icons.check : Icons.arrow_back)),
          const SizedBox(height: 6),
          AtButton('عندي عذر',
              kind: AtButtonKind.text,
              onPressed: done || existing != null
                  ? null
                  : () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ExcuseFormScreen(activities: [task])));
                      _reload();
                    }),
        ]));
  }
}

class RecordDetails extends StatelessWidget {
  final Json item;
  final String kind;
  final Future<void> Function() onChanged;
  const RecordDetails(
      {super.key,
      required this.item,
      required this.kind,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(kindNames[kind] ?? 'تفاصيل الطلب',
                          style: text.labelLarge),
                      const SizedBox(height: 10),
                      Text('${item['title']}', style: text.headlineMedium),
                      const SizedBox(height: 16),
                      StatusBadge.review(item['status'] as String?),
                      const SizedBox(height: 16),
                      Text(
                          'التاريخ: ${displayDate(item['activityTime'] ?? item['createdAt'])}',
                          style: text.bodyMedium),
                      if (kind == 'EXCUSE' && item['evidenceUrl'] != null)
                        EvidenceImage('${item['evidenceUrl']}'),
                      if (item['reason'] != null &&
                          '${item['reason']}'.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        ProofNotice('${item['reason']}')
                      ],
                      if (kind == 'OBJECTION' && item['aiReason'] != null) ...[
                        const SizedBox(height: 12),
                        Text('سبب القرار السابق: ${item['aiReason']}',
                            style: text.bodySmall)
                      ],
                      const SizedBox(height: 24),
                      if (kind == 'PROOF' && item['managed'] == true)
                        AtButton('افتح تفاصيل الإثبات', onPressed: () {
                          Navigator.pop(context);
                          context.push(
                              '/proofs/session/${item['id']}?title=${Uri.encodeComponent('${item['title']}')}');
                        }),
                      if (item['canObject'] == true)
                        AtButton('قدّم اعتراض', kind: AtButtonKind.outline,
                            onPressed: () async {
                          final saved = await editObjection(context,
                              kind: kind, targetId: item['id'] as int);
                          if (saved) {
                            await onChanged();
                            if (context.mounted) Navigator.pop(context);
                          }
                        }),
                      if (item['canEdit'] == true)
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: AtButton('عدّل الطلب',
                                kind: AtButtonKind.outline,
                                onPressed: () async {
                              if (kind == 'OBJECTION') {
                                final saved = await editObjection(context,
                                    kind: kind,
                                    targetId: item['id'] as int,
                                    existing: item);
                                if (saved) {
                                  await onChanged();
                                  if (context.mounted) Navigator.pop(context);
                                }
                              } else if (kind == 'EXCUSE') {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ExcuseFormScreen(
                                            activities: [item],
                                            existing: item)));
                                await onChanged();
                                if (context.mounted) Navigator.pop(context);
                              } else {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => LegacyProofEditScreen(
                                            proof: item)));
                                await onChanged();
                                if (context.mounted) Navigator.pop(context);
                              }
                            })),
                      if (item['canDelete'] == true)
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: AtButton('احذف الطلب',
                                kind: AtButtonKind.text, onPressed: () async {
                              if (!await confirmDelete(context,
                                  'نحذف هذا الطلب فقط. إعادة التقديم تخضع للمهلة والشروط الأصلية.')) {
                                return;
                              }
                              if (!context.mounted) return;
                              final api = context.read<ApiClient>();
                              final path = kind == 'OBJECTION'
                                  ? '/api/v1/objection/delete/${item['id']}'
                                  : kind == 'EXCUSE'
                                      ? '/api/v1/excuse/delete/goal-task/${item['id']}'
                                      : '/api/v1/proof/delete/goal-task/${item['id']}';
                              try {
                                await api.delete(path);
                                await onChanged();
                                if (context.mounted) Navigator.pop(context);
                              } catch (error) {
                                if (context.mounted) proofError(context, error);
                              }
                            })),
                      if (kind == 'OBJECTION' &&
                          item['reviewStartedAt'] != null)
                        const ProofNotice(
                            'بدأ الأدمن مراجعة اعتراضك؛ لا يمكن تعديله أو حذفه الآن.'),
                    ]))));
  }
}
