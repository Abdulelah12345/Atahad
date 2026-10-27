import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';
import '../utils/format.dart';

// the seven days Sunday to Saturday: done / missed / excused / today / planned / empty
enum DayState { done, missed, excused, today, planned, empty }

class WeekTracker extends StatelessWidget {
  final List<DayState> days; // 7 items, Sunday first

  const WeekTracker({super.key, required this.days}) : assert(days.length == 7);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final state = days[i];
        final (Color bg, BoxBorder? border, Widget inner) = switch (state) {
          DayState.done => (c.accent, null, const Icon(Icons.check_rounded, size: 18, color: Colors.white)),
          DayState.missed => (c.dangerSoft, null, Icon(Icons.close_rounded, size: 18, color: c.danger)),
          DayState.excused => (c.infoSoft, null, Icon(Icons.remove_rounded, size: 18, color: c.info)),
          DayState.today => (c.surface, Border.all(color: c.primary, width: 2), _dayNumber(i, c.primary, text)),
          DayState.planned => (c.primarySoft, null, _dayNumber(i, c.primary, text)),
          DayState.empty => (c.surfaceSunken, null, _dayNumber(i, c.inkSubtle, text)),
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, border: border, borderRadius: BorderRadius.circular(Radii.sm)),
              child: inner,
            ),
            const SizedBox(height: Space.s1),
            Text(
              weekDaysAr[i],
              style: text.labelSmall!.copyWith(
                color: state == DayState.today ? c.primary : c.inkSubtle,
                fontWeight: state == DayState.today ? FontWeight.w700 : null,
              ),
            ),
          ],
        );
      }),
    );
  }

  static Widget _dayNumber(int index, Color color, TextTheme text) =>
      Text(arabicDigits(index + 1), style: text.labelLarge!.copyWith(color: color));
}
