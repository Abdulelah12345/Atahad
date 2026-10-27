import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';
import '../utils/format.dart';
import 'at_button.dart';
import 'game.dart';
import 'riyal.dart';
import 'status_badge.dart';

// a task in «اليوم», its look changes with the state so the member knows what to do at a glance
//   urgent = «لازم اليوم»: a pulsing orange border and one primary button
//   missed = «ضاع يوم»: two buttons, a pardon card or an excuse (before any deduction)
//   safe   = «ماشية تمام»: a compact row with a «أجّل» link
enum QuestState { urgent, missed, safe }

QuestState questStateOf(String? trackStatus) => switch (trackStatus) {
      'MUST_TODAY' => QuestState.urgent,
      'LOST_DAY' => QuestState.missed,
      _ => QuestState.safe,
    };

// the icon of a proof method
IconData proofMethodIcon(String? method) => switch (method) {
      'PHOTO' => Icons.photo_camera_rounded,
      'LOCATION' => Icons.place_rounded,
      'TIMER' => Icons.timer_rounded,
      'QUIZ' => Icons.menu_book_rounded,
      'STEPS' => Icons.directions_walk_rounded,
      _ => Icons.flag_rounded,
    };

class QuestCard extends StatelessWidget {
  final QuestState state;
  final IconData icon;
  final Widget title;
  final String meta;
  final int done;
  final int total;
  final num? stake; // what goes to charity if a time is missed
  final VoidCallback? onTap;
  final String actionLabel; // urgent: the primary button
  final VoidCallback? onAction;
  final VoidCallback? onPardon; // missed
  final VoidCallback? onExcuse; // missed
  final VoidCallback? onPostpone; // safe
  final Widget? badge; // safe: the state (آمن، خلص الأسبوع)
  final int? pardons; // how many pardon cards the member has (shown on the pardon button)

  const QuestCard({
    super.key,
    required this.state,
    required this.icon,
    required this.title,
    required this.meta,
    required this.done,
    required this.total,
    this.stake,
    this.onTap,
    this.actionLabel = 'ارفع الإثبات',
    this.onAction,
    this.onPardon,
    this.onExcuse,
    this.onPostpone,
    this.badge,
    this.pardons,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final (Color iconBg, Color iconFg) = switch (state) {
      QuestState.urgent => (c.urgentSoft, c.urgentText),
      QuestState.missed => (c.dangerSoft, c.danger),
      QuestState.safe => (c.successSoft, c.success),
    };
    final compact = state == QuestState.safe;
    final pardonLabel = pardons == null ? 'بطاقة عفو' : 'بطاقة عفو (${arabicDigits(pardons)})';
    final iconBox = Container(
      width: compact ? 36 : 44,
      height: compact ? 36 : 44,
      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(compact ? 12 : 14)),
      child: Icon(icon, color: iconFg, size: compact ? 20 : 22),
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: (compact ? text.labelLarge : text.titleMedium)!.copyWith(fontWeight: FontWeight.w700),
          child: title,
        ),
        Text(meta, style: text.labelSmall!.copyWith(color: c.inkSubtle)),
      ],
    );

    final Widget body;
    if (compact) {
      body = Row(
        children: [
          iconBox,
          const SizedBox(width: 10),
          Expanded(child: heading),
          if (badge != null) badge!,
          if (onPostpone != null)
            TextButton(
              onPressed: onPostpone,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: Space.s2)),
              child: const Text('أجّل'),
            ),
          // the other ways out of a time, in a small menu
          if (onPardon != null || onExcuse != null)
            PopupMenuButton<String>(
              tooltip: 'خيارات',
              icon: Icon(Icons.more_vert_rounded, color: c.inkSubtle),
              onSelected: (v) => v == 'pardon' ? onPardon?.call() : onExcuse?.call(),
              itemBuilder: (context) => [
                if (onPardon != null)
                  PopupMenuItem(
                    value: 'pardon',
                    child: Row(children: [
                      Icon(Icons.confirmation_number_rounded, size: 20, color: c.pardon),
                      const SizedBox(width: Space.s3),
                      Text('استخدم $pardonLabel'),
                    ]),
                  ),
                if (onExcuse != null)
                  PopupMenuItem(
                    value: 'excuse',
                    child: Row(children: [
                      Icon(Icons.description_outlined, size: 20, color: c.inkMuted),
                      const SizedBox(width: Space.s3),
                      const Text('عندي عذر'),
                    ]),
                  ),
              ],
            ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              iconBox,
              const SizedBox(width: 10),
              Expanded(child: heading),
              if (state == QuestState.urgent) const StatusBadge('لازم اليوم', kind: BadgeKind.streak),
            ],
          ),
          const SizedBox(height: 12),
          Pips(done: done, total: total, width: 0, height: 8),
          const SizedBox(height: 12),
          if (state == QuestState.urgent)
            ...[
              Row(
                children: [
                  Expanded(child: _Stake(stake)),
                  const SizedBox(width: 10),
                  AtButton(actionLabel, expand: false, onPressed: onAction),
                ],
              ),
              // can't make it today: the two other ways, smaller than the proof
              if (onPardon != null || onExcuse != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onPardon != null)
                      Expanded(child: _SoftButton(pardonLabel, icon: Icons.confirmation_number_rounded, fg: c.pardonText, bg: c.pardonSoft, onPressed: onPardon)),
                    if (onPardon != null && onExcuse != null) const SizedBox(width: Space.s2),
                    if (onExcuse != null)
                      Expanded(child: _SoftButton('عندي عذر', icon: Icons.description_outlined, fg: c.ink, bg: c.surfaceSunken, onPressed: onExcuse)),
                  ],
                ),
              ],
            ]
          else ...[
            if (stake != null) ...[_Stake(stake), const SizedBox(height: Space.s2)],
            Row(
              children: [
                Expanded(child: _SoftButton(pardonLabel, icon: Icons.confirmation_number_rounded, fg: c.pardonText, bg: c.pardonSoft, onPressed: onPardon)),
                const SizedBox(width: Space.s2),
                Expanded(child: _SoftButton('عندي عذر', icon: Icons.description_outlined, fg: c.ink, bg: c.surfaceSunken, onPressed: onExcuse)),
              ],
            ),
          ],
        ],
      );
    }

    final shape = BorderRadius.circular(Radii.card);
    final card = Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: switch (state) {
          QuestState.urgent => BorderSide(color: c.urgent, width: 2),
          QuestState.missed => BorderSide(color: c.dangerSoft),
          QuestState.safe => BorderSide(color: c.line),
        },
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: compact ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10) : const EdgeInsets.all(14), child: body),
      ),
    );
    return state == QuestState.urgent ? _UrgentPulse(radius: Radii.card, child: card) : card;
  }
}

// «لو فاتتك: ١٠ ⃁ صدقة»
class _Stake extends StatelessWidget {
  final num? amount;

  const _Stake(this.amount);

  @override
  Widget build(BuildContext context) {
    if (amount == null) return const SizedBox.shrink();
    final c = context.colors;
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(color: c.goldText);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text('لو فاتتك:', style: style),
        RiyalAmount(amount, style: style.copyWith(fontWeight: FontWeight.w700)),
        Text('صدقة', style: style),
      ],
    );
  }
}

class _SoftButton extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _SoftButton(this.label, {required this.fg, required this.bg, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? context.colors.surfaceSunken : bg,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Space.s2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: onPressed == null ? context.colors.inkSubtle : fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(color: onPressed == null ? context.colors.inkSubtle : fg, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// «لازم اليوم»: the border breathes softly (the only thing that repeats forever), stops with reduced motion
class _UrgentPulse extends StatefulWidget {
  final double radius;
  final Widget child;

  const _UrgentPulse({required this.radius, required this.child});

  @override
  State<_UrgentPulse> createState() => _UrgentPulseState();
}

class _UrgentPulseState extends State<_UrgentPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgent = context.colors.urgent;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // 0% → 70%: a ring grows to 9px and fades out
        final t = (_c.value / 0.7).clamp(0.0, 1.0);
        final curved = Motion.easeOut.transform(t);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [BoxShadow(color: urgent.withValues(alpha: 0.5 * (1 - curved)), spreadRadius: 9 * curved)],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
