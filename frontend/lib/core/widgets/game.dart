import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';
import '../utils/format.dart';
import 'riyal.dart';

// the game pieces of the design system: Pips, ResourceChip, RewardProgress, LevelBadge, TitleBadge
// gold is for money only: points are blue, pardon cards are purple

bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// the times of the week as small bars: done = accent
class Pips extends StatelessWidget {
  final int done;
  final int total;
  final double width; // 0 = fill the row
  final double height;
  final Color? empty;

  const Pips({super.key, required this.done, required this.total, this.width = 18, this.height = 6, this.empty});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (total <= 0) return SizedBox(height: height);
    // many times: one bar
    if (total > 10) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.full),
        child: LinearProgressIndicator(value: (done / total).clamp(0, 1).toDouble(), minHeight: height, color: c.accent, backgroundColor: empty ?? c.surfaceSunken),
      );
    }
    Widget pip(int i) => Container(
          width: width == 0 ? null : width,
          height: height,
          decoration: BoxDecoration(color: i < done ? c.accent : (empty ?? c.surfaceSunken), borderRadius: BorderRadius.circular(Radii.full)),
        );
    return Row(
      mainAxisSize: width == 0 ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(width: width == 0 ? 5 : 3),
          width == 0 ? Expanded(child: pip(i)) : pip(i),
        ],
      ],
    );
  }
}

// the counters at the top of «اليوم»: points, pardon cards, donations (a tap opens «مستواي»)
enum ResourceKind { points, pardon, donated }

class ResourceChip extends StatelessWidget {
  final ResourceKind kind;
  final num value;
  final VoidCallback? onTap;

  const ResourceChip(this.kind, this.value, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = Theme.of(context).textTheme.titleSmall!.copyWith(
          fontWeight: FontWeight.w800,
          color: kind == ResourceKind.donated ? c.goldText : c.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final (String label, Widget icon) = switch (kind) {
      ResourceKind.points => (
          'نقطة',
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 13, color: c.onPrimary),
          ),
        ),
      ResourceKind.pardon => ('بطاقة عفو', Icon(Icons.confirmation_number_rounded, size: 18, color: c.pardon)),
      ResourceKind.donated => ('تبرّعت', RiyalSymbol(size: 13, color: c.goldText)),
    };
    final number = kind == ResourceKind.donated ? arabicDigits(value.round()) : arabicDigits(value);
    return Semantics(
      label: '$number $label',
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: StadiumBorder(side: BorderSide(color: c.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              // the riyal goes after the number, the other icons before it
              children: kind == ResourceKind.donated
                  ? [Text(number, style: style), const SizedBox(width: 4), icon]
                  : [icon, const SizedBox(width: 6), Text(number, style: style)],
            ),
          ),
        ),
      ),
    );
  }
}

// how far the next reward is: «بطاقة العفو الجاية ٣٠ / ١٥٠ نقطة» (the number left, not a percentage)
class RewardProgress extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final bool pardon; // a pardon card (purple), else a level (accent)
  final VoidCallback? onTap;

  const RewardProgress({super.key, required this.label, required this.current, required this.target, this.pardon = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final value = target <= 0 ? 0.0 : (current / target).clamp(0, 1).toDouble();
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: c.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: text.labelMedium!.copyWith(fontWeight: FontWeight.w700))),
                  Text('${arabicDigits(current)} / ${arabicDigits(target)} نقطة', style: text.labelSmall),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.full),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduceMotion(context) ? value : 0, end: value),
                  duration: Motion.reward,
                  curve: Motion.easeOut,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    backgroundColor: c.surfaceSunken,
                    color: pardon ? c.pardon : c.accent,
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

// the four levels: مبتدئ ← ملتزم ← مثابر ← حديدي (darker every level, iron is metal)
const levelOrder = ['BEGINNER', 'COMMITTED', 'PERSEVERING', 'IRON'];

class LevelBadge extends StatelessWidget {
  final String? level;
  final double size;
  final bool showName;
  final bool dimmed; // a level not reached yet (on the ladder)

  const LevelBadge(this.level, {super.key, this.size = 52, this.showName = true, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final index = levelOrder.indexOf(level ?? '');
    final number = index < 0 ? 1 : index + 1;
    final color = dimmed ? c.surfaceSunken : c.level(level);
    final iron = level == 'IRON' && !dimmed;
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iron ? null : color,
        gradient: iron ? AtColors.ironGradient : null,
        // a surface gap, then a ring in the level color
        boxShadow: [BoxShadow(color: dimmed ? c.line : color, spreadRadius: 5), BoxShadow(color: c.surface, spreadRadius: 3)],
      ),
      child: Text(
        arabicDigits(number),
        style: text.headlineSmall!.copyWith(
          color: dimmed ? c.inkSubtle : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
          height: 1.2,
        ),
      ),
    );
    if (!showName) return circle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.all(5), child: circle),
        const SizedBox(height: 6),
        Text(levelsAr[level] ?? '-', style: text.labelMedium!.copyWith(color: dimmed ? c.inkSubtle : c.ink, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// the whole ladder in «مستواي», the current level is highlighted
class LevelLadder extends StatelessWidget {
  final String? current;

  const LevelLadder({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final reached = levelOrder.indexOf(current ?? '');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (i, level) in levelOrder.indexed)
          Flexible(
            child: AnimatedScale(
              scale: i == reached ? 1 : 0.82,
              duration: Motion.base,
              child: LevelBadge(level, size: 44, dimmed: i > reached),
            ),
          ),
      ],
    );
  }
}

// the seven titles of the week (the color and icon of each, only the donor is gold)
const titleIcons = {
  'IRON': Icons.fitness_center_rounded,
  'ROCKET': Icons.rocket_launch_rounded,
  'OWL': Icons.nightlight_round,
  'ALARMIST': Icons.notifications_active_rounded,
  'COMEBACK': Icons.replay_rounded,
  'EXCUSE_KING': Icons.receipt_long_rounded,
  'TOP_DONOR': Icons.volunteer_activism_rounded,
};

Color titleColor(String? code) => AtColors.titles[code] ?? AtColors.light.lineStrong;

// the colored tile of a title
class TitleTile extends StatelessWidget {
  final String code;
  final double size;
  final bool locked; // not won: gray

  const TitleTile(this.code, {super.key, this.size = 48, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Gradient? gradient = locked
        ? null
        : switch (code) {
            'IRON' => AtColors.ironGradient,
            'TOP_DONOR' => RadialGradient(center: const Alignment(-0.3, -0.4), colors: [c.goldLight, c.gold, c.goldDeep], stops: const [0, 0.55, 1]),
            _ => null,
          };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: locked ? c.surfaceSunken : (gradient == null ? titleColor(code) : null),
        gradient: gradient,
        border: locked ? Border.all(color: c.line, width: 2) : null,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(
        titleIcons[code] ?? Icons.workspace_premium_rounded,
        color: locked ? c.lineStrong : (code == 'TOP_DONOR' ? c.onGold : Colors.white),
        size: size * 0.5,
      ),
    );
  }
}

// a title with its name under it, «٢×» on top when it was won more than once
class TitleBadge extends StatelessWidget {
  final String code;
  final String name;
  final int count;
  final bool locked;
  final double size;

  const TitleBadge(this.code, this.name, {super.key, this.count = 1, this.locked = false, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            TitleTile(code, size: size, locked: locked),
            if (count > 1 && !locked)
              PositionedDirectional(
                top: -6,
                end: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(Radii.full), border: Border.all(color: c.surface, width: 2)),
                  child: Text('${arabicDigits(count)}×', style: text.labelSmall!.copyWith(color: c.surface, fontWeight: FontWeight.w700, height: 1.3)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: text.labelSmall!.copyWith(color: locked ? c.inkSubtle : c.ink, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// a reward that appears with a pop, once (the + points, a new pardon card, a title)
class PopIn extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final total = Motion.reward + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: Motion.easePop),
      builder: (context, t, child) => Transform.scale(scale: 0.5 + 0.5 * t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
      child: child,
    );
  }
}

// an accepted proof: the check is drawn like a pen stroke, then +١٠ pops (animate = it was just accepted)
class AcceptedMoment extends StatelessWidget {
  final bool animate;
  final int points;

  const AcceptedMoment({super.key, this.animate = true, this.points = 10});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final still = !animate || reduceMotion(context);
    final check = TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: Motion.sign,
      curve: Motion.easeOut,
      builder: (context, t, _) => CustomPaint(size: const Size.square(64), painter: _CheckPainter(t, c.accent, c.successSoft)),
    );
    final reward = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(Radii.full)),
      child: Text('+${arabicDigits(points)} نقطة', style: text.titleSmall!.copyWith(color: c.primary, fontWeight: FontWeight.w800)),
    );
    return Semantics(
      label: 'انقبل إثباتك، +$points نقطة',
      child: Column(
        children: [
          check,
          const SizedBox(height: Space.s2),
          Text('انقبل إثباتك', style: text.headlineSmall),
          const SizedBox(height: Space.s2),
          still ? reward : PopIn(delay: Motion.sign, child: reward),
        ],
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  final Color color;
  final Color circle;

  _CheckPainter(this.t, this.color, this.circle);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, Paint()..color = circle);
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.36);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}
