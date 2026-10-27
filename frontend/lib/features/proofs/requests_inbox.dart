import 'package:flutter/material.dart';
import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import 'proofs_api.dart';
import 'proof_widgets.dart';

/// «طلباتي» (design: Requests): what is owed on top, the two kinds side by side, then one card per request.
class RequestsInbox extends StatelessWidget {
  final List<Json> excuses;
  final List<Json> objections;
  final List<Json> shown;
  final int tab;
  final String filter;
  final num owed;
  final ValueChanged<int> onTab;
  final ValueChanged<String> onFilter;
  final VoidCallback? onCreate;
  final VoidCallback onDonate;
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
    this.owed = 0,
    required this.onDonate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final kind = tab == 2 ? 'EXCUSE' : 'OBJECTION';
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s8),
            children: [
              if (owed > 0) ...[
                _OwedCard(amount: owed, onTap: onDonate),
                const SizedBox(height: Space.s4),
              ],
              SegmentedPills<int>(
                options: [
                  (2, 'الأعذار (${arabicDigits(excuses.length)})'),
                  (3, 'الاعتراضات (${arabicDigits(objections.length)})'),
                ],
                value: tab,
                onChanged: onTab,
              ),
              const SizedBox(height: Space.s3),
              // the status filters, one quiet row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (key, label, icon) in const [
                      ('ALL', 'الكل', Icons.all_inclusive_rounded),
                      ('PENDING', 'بالمراجعة', Icons.schedule_rounded),
                      ('ACCEPTED', 'مقبول', Icons.check_rounded),
                      ('REJECTED', 'مرفوض', Icons.close_rounded),
                    ]) ...[
                      ChoiceChip(
                        avatar: Icon(icon, size: 16, color: filter == key ? c.primary : c.inkSubtle),
                        label: Text(label),
                        selected: filter == key,
                        showCheckmark: false,
                        labelStyle: text.labelMedium?.copyWith(
                          color: filter == key ? c.primary : c.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => onFilter(key),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.s3),
              if (tab == 2 && onCreate != null) ...[
                DashedAction(icon: Icons.add_rounded, label: 'عذر جديد', onTap: onCreate!),
                const SizedBox(height: Space.s3),
              ],
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.s6),
                  child: Column(
                    children: [
                      IconTile(Icons.inbox_rounded, size: 64, fg: c.inkSubtle, bg: c.surfaceSunken),
                      const SizedBox(height: Space.s3),
                      Text(filter == 'ALL' ? 'ما فيه طلبات' : 'ما فيه طلبات بهالحالة', style: text.titleMedium),
                      if (filter != 'ALL')
                        TextButton(onPressed: () => onFilter('ALL'), child: const Text('اعرض الكل')),
                    ],
                  ),
                ),
              for (final (i, item) in shown.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Enter(
                    index: i,
                    child: _RequestCard(
                      item: item,
                      kind: kind,
                      onOpen: () => onOpen(item, kind),
                      onObject: () => onObject(item),
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

// a dashed «add» row, quieter than a big button
class DashedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DashedAction({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.primarySoft.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: c.primary.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: c.primary, size: 20),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// the navy card: what is owed, and a tap to the donation (design: Requests)
class _OwedCard extends StatelessWidget {
  final num amount;
  final VoidCallback onTap;

  const _OwedCard({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Material(
      color: c.deep,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0xFF050D22), offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [c.goldLight, c.gold, c.goldDeep], stops: const [0, 0.55, 1]),
                ),
                child: RiyalSymbol(size: 20, color: c.deep),
              ),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('عليك ', style: text.titleMedium!.copyWith(color: c.goldLight, fontWeight: FontWeight.w800)),
                        RiyalAmount(amount, color: c.goldLight, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
                        Text(' للخير', style: text.titleMedium!.copyWith(color: c.goldLight, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Text('تبرّع لإحسان وثبّت', style: text.labelSmall!.copyWith(color: const Color(0xFFB7C5E8))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// each card slides up a little, one after another
class _Enter extends StatelessWidget {
  final int index;
  final Widget child;

  const _Enter({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = (index * 60).clamp(0, 480);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Interval(delay / (320 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
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
    final status = item['status'] as String?;
    final rejected = status == 'REJECTED';
    // The backend owns the objection window and duplicate-request checks.
    final canObject = kind == 'EXCUSE' && rejected && item['canObject'] == true;
    // one color and icon per state (design: Requests)
    final (IconData icon, Color fg, Color bg, String label) = switch (status) {
      'ACCEPTED' => (Icons.verified_rounded, c.success, c.successSoft, 'مقبول'),
      'REJECTED' => (Icons.close_rounded, c.danger, c.dangerSoft, 'مرفوض'),
      'ESCALATED' => (Icons.gavel_rounded, c.pardonText, c.pardonSoft, 'عند المشرف'),
      _ => (Icons.schedule_rounded, c.warning, c.warningSoft, 'بالمراجعة'),
    };
    final type = kind == 'EXCUSE' ? excuseNames[item['type']] : kindNames[item['kind']];
    final heading = [if (type != null) type, '${item['title'] ?? 'طلبك'}'].join(' · ');
    final note = '${item['reason'] ?? ''}'.trim();
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rejected ? c.danger.withValues(alpha: 0.3) : c.line),
        boxShadow: [BoxShadow(color: c.line, offset: const Offset(0, 3))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon, size: 42, fg: fg, bg: bg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(heading, style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          const SizedBox(width: 8),
                          TagPill(label, fg: fg, bg: bg),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.isEmpty || note == 'null' ? displayDate(item['activityTime'] ?? item['createdAt']) : note,
                        style: text.labelSmall!.copyWith(color: c.inkSubtle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (canObject)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: onObject,
                            style: TextButton.styleFrom(
                              foregroundColor: c.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.balance_rounded, size: 16),
                            label: const Text('اعترض · خلال ٤٨ ساعة'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
