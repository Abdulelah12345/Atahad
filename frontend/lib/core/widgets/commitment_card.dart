import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';
import 'riyal.dart';
import 'week_tracker.dart';

// a commitment in «تعهّداتي», always in this order:
// the title, the details and the state · the week · the money line · one button as wide as the card
// (in «اليوم» use QuestCard)
class CommitmentCard extends StatelessWidget {
  final String title;
  final List<String> details;
  final Widget? badge;
  final Widget? menu;
  final List<DayState>? week;
  final String moneyLabel;
  final num? amount;
  final List<Widget> extra; // anything between the money line and the button
  final Widget? action;
  final VoidCallback? onTap;

  const CommitmentCard({
    super.key,
    required this.title,
    this.details = const [],
    this.badge,
    this.menu,
    this.week,
    this.moneyLabel = 'لكل مرة تفوتك',
    this.amount,
    this.extra = const [],
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(Radii.card);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: AtShadows.card(dark)),
      child: Material(
        color: c.surface,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.headlineSmall),
                          for (final d in details) Text(d, style: text.bodySmall),
                        ],
                      ),
                    ),
                    if (badge != null) Padding(padding: const EdgeInsets.only(top: Space.s1), child: badge!),
                    if (menu != null) menu!,
                  ],
                ),
                if (week != null) ...[const SizedBox(height: Space.s4), WeekTracker(days: week!)],
                if (amount != null) ...[
                  const SizedBox(height: Space.s4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
                    decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(
                      children: [
                        Expanded(child: Text(moneyLabel, style: text.bodySmall)),
                        RiyalAmount(amount, style: text.titleMedium!.copyWith(fontSize: 18)),
                      ],
                    ),
                  ),
                ],
                ...extra,
                if (action != null) ...[const SizedBox(height: Space.s4), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
