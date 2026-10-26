import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';

// a small pill with a dot: "آمن"، "لازم اليوم"، "ضاع يوم"، "قيد المراجعة"، "تبرّعنا عنك"، "بطاقة عفو"
// every state has a fixed color (streak = "must today", orange)
enum BadgeKind { success, warning, danger, info, streak, pardon, brand, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeKind kind;

  const StatusBadge(this.label, {super.key, this.kind = BadgeKind.neutral});

  // the week status from the backend (trackStatus) -> a badge
  factory StatusBadge.track(String? status, {Key? key}) => switch (status) {
        'SAFE' => StatusBadge('آمن', kind: BadgeKind.success, key: key),
        'MUST_TODAY' => StatusBadge('لازم اليوم', kind: BadgeKind.streak, key: key),
        'LOST_DAY' => StatusBadge('ضاع يوم', kind: BadgeKind.danger, key: key),
        'SETTLED' => StatusBadge('خلص الأسبوع', kind: BadgeKind.info, key: key),
        _ => StatusBadge(status ?? '-', key: key),
      };

  // a proof, excuse or donation status from the backend
  factory StatusBadge.review(String? status, {Key? key}) => switch (status) {
        'ACCEPTED' => StatusBadge('مقبول', kind: BadgeKind.success, key: key),
        'PENDING' || 'ESCALATED' => StatusBadge('قيد المراجعة', kind: BadgeKind.warning, key: key),
        'REJECTED' => StatusBadge('مرفوض', kind: BadgeKind.danger, key: key),
        _ => StatusBadge(status ?? '-', key: key),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fg, Color bg) = switch (kind) {
      BadgeKind.success => (c.success, c.successSoft),
      BadgeKind.warning => (c.warning, c.warningSoft),
      BadgeKind.danger => (c.danger, c.dangerSoft),
      BadgeKind.info => (c.info, c.infoSoft),
      BadgeKind.streak => (c.urgentText, c.urgentSoft),
      BadgeKind.pardon => (c.pardonText, c.pardonSoft),
      BadgeKind.brand => (c.primary, c.primarySoft),
      BadgeKind.neutral => (c.inkMuted, c.surfaceSunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: Space.s1 + 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
