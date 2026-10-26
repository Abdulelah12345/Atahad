import 'package:flutter/material.dart';
import '../../core/theme/at_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'proofs_api.dart';
import 'proof_widgets.dart';

/// Requests-only layout: creation first, categories second, then quiet status filters.
class RequestsInbox extends StatelessWidget {
  final List<Json> excuses;
  final List<Json> objections;
  final List<Json> shown;
  final int tab;
  final String filter;
  final ValueChanged<int> onTab;
  final ValueChanged<String> onFilter;
  final VoidCallback? onCreate;
  final Future<void> Function() onRefresh;
  final void Function(Json item, String kind) onOpen;
  final ValueChanged<Json> onObject;
  const RequestsInbox({
    super.key,
    required this.excuses,
    required this.objections,
    required this.shown,
    required this.tab,
    required this.filter,
    required this.onTab,
    required this.onFilter,
    required this.onCreate,
    required this.onRefresh,
    required this.onOpen,
    required this.onObject,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'إرفاق الأعذار والاعتراضات',
                style: text.headlineLarge?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'قدّم عذرك أو تابع طلباتك السابقة',
                style: text.bodySmall?.copyWith(color: c.inkSubtle),
              ),
              const SizedBox(height: 26),
              AtButton(
                'تقديم عذر',
                kind: AtButtonKind.gold,
                icon: const Icon(Icons.add_rounded),
                onPressed: onCreate,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.surfaceSunken,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final entry in [
                      (2, 'الأعذار', excuses.length),
                      (3, 'الاعتراضات', objections.length),
                    ])
                      Expanded(
                        child: Semantics(
                          selected: tab == entry.$1,
                          button: true,
                          child: Material(
                            color: tab == entry.$1
                                ? c.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => onTab(entry.$1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                child: Text(
                                  '${entry.$2} (${arabicDigits(entry.$3)})',
                                  textAlign: TextAlign.center,
                                  style: text.labelLarge?.copyWith(
                                    color: tab == entry.$1
                                        ? c.primary
                                        : c.inkMuted,
                                    fontWeight: tab == entry.$1
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final entry in {
                    'ALL': 'الكل',
                    'PENDING': 'قيد الانتظار',
                    'ACCEPTED': 'مقبول',
                    'REJECTED': 'مرفوض',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: filter == entry.key,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                      labelStyle: text.labelSmall?.copyWith(
                        color: filter == entry.key ? c.primary : c.inkMuted,
                      ),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onFilter(entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (shown.isEmpty)
                ProofEmpty(
                  title: 'السجل هادئ للحين',
                  message: filter == 'ALL'
                      ? 'طلباتك تظهر هنا بعد إرسالها، وتقدر تتابع حالتها من المكان نفسه.'
                      : 'ما فيه طلبات تطابق الحالة المختارة. جرّب «الكل» لعرض بقية طلباتك.',
                  icon: Icons.inbox_outlined,
                ),
              for (final item in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequestCard(
                    item: item,
                    kind: tab == 2 ? 'EXCUSE' : 'OBJECTION',
                    onOpen: () =>
                        onOpen(item, tab == 2 ? 'EXCUSE' : 'OBJECTION'),
                    onObject: () => onObject(item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Json item;
  final String kind;
  final VoidCallback onOpen;
  final VoidCallback onObject;
  const _RequestCard({
    required this.item,
    required this.kind,
    required this.onOpen,
    required this.onObject,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final rejected = item['status'] == 'REJECTED';
    // The backend owns the objection window and duplicate-request checks.
    final canObject = kind == 'EXCUSE' && rejected && item['canObject'] == true;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rejected ? c.danger.withValues(alpha: 0.35) : c.line,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackBadge =
                        constraints.maxWidth < 285 ||
                        MediaQuery.textScalerOf(context).scale(12) > 15;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: c.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                kind == 'EXCUSE'
                                    ? Icons.description_outlined
                                    : Icons.forum_outlined,
                                color: c.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['title'] ?? 'طلبك'}',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayDate(
                                      item['activityTime'] ?? item['createdAt'],
                                    ),
                                    style: text.labelSmall?.copyWith(
                                      color: c.inkSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!stackBadge) ...[
                              const SizedBox(width: 8),
                              StatusBadge.review(item['status'] as String?),
                            ],
                          ],
                        ),
                        if (stackBadge)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: StatusBadge.review(
                                item['status'] as String?,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (canObject) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: c.inkSubtle,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'تقدر تعترض خلال ٤٨ ساعة من صدور القرار.',
                          style: text.labelSmall?.copyWith(color: c.inkMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.danger,
                        side: BorderSide(
                          color: c.danger.withValues(alpha: 0.7),
                        ),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onObject,
                      child: const Text('اعترض على القرار'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
