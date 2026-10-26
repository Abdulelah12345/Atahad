import 'package:flutter/material.dart';

import '../../core/theme/at_colors.dart';
import '../../core/theme/at_tokens.dart';
import '../../core/utils/format.dart';

// OWNER: Fai - the shared pieces of the group pages (the design system screens: Groups, GroupBoard, GroupVote, GroupWeek, GroupVS, Moments)

// the color of a group, by the order it was created (white text on it)
Color teamColor(Object? groupId) => AtColors.team(((groupId as int?) ?? 1) - 1);

// a darker shade of a color, for the 3-4px edge under raised things
Color edgeOf(Color color) => Color.lerp(color, Colors.black, 0.28)!;

bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// the first letter of the group in a rounded square (team color)
class TeamAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  final bool onColor; // on a team colored background: a light square instead

  const TeamAvatar({super.key, required this.name, required this.color, this.size = 50, this.onColor = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onColor ? Colors.white.withValues(alpha: 0.2) : color,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        name.isEmpty ? '' : name.characters.first,
        style: text.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.44, height: 1.1),
      ),
    );
  }
}

// a member: the first letter in a circle, with a ring in the color of his title of the week
class MemberAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? ring;
  final Color? gap; // the color between the avatar and its ring (the page behind it)

  const MemberAvatar(this.name, {super.key, this.size = 42, this.ring, this.gap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        shape: BoxShape.circle,
        // later shadows paint over the earlier ones: the ring first, then the white gap on it
        boxShadow: ring == null ? null : [BoxShadow(color: ring!, spreadRadius: 4), BoxShadow(color: gap ?? c.surface, spreadRadius: 2)],
      ),
      child: Text(
        name.isEmpty ? '' : name.characters.first,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(color: c.primary, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );
  }
}

// a white card that stands on a 3px edge; highlighted = a primary ring (me, my vote)
class RaisedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? highlight;
  final VoidCallback? onTap;
  final Color? color;

  const RaisedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = Radii.lg,
    this.highlight,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final edge = highlight == null ? c.line : edgeOf(highlight!);
    final shape = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          if (highlight != null) BoxShadow(color: highlight!, spreadRadius: 2),
          BoxShadow(color: highlight == null ? edge : highlight!, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: color ?? c.surface,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

// small pill with text (no dot), like «صوتك» or a title of the week
class Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final bool dot;

  const Pill(this.label, {super.key, required this.fg, required this.bg, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}

// the times of the week as small bars: done = accent
class Pips extends StatelessWidget {
  final int done;
  final int total;
  final double width; // 0 = fill the row
  final Color? empty;

  const Pips({super.key, required this.done, required this.total, this.width = 18, this.empty});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (total <= 0) return const SizedBox(height: 6);
    // many times: one bar
    if (total > 10) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.full),
        child: LinearProgressIndicator(value: (done / total).clamp(0, 1).toDouble(), minHeight: 6, color: c.accent, backgroundColor: empty ?? c.surfaceSunken),
      );
    }
    Widget pip(int i) => Container(
          width: width == 0 ? null : width,
          height: 6,
          decoration: BoxDecoration(color: i < done ? c.accent : (empty ?? c.surfaceSunken), borderRadius: BorderRadius.circular(Radii.full)),
        );
    return Row(
      mainAxisSize: width == 0 ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          width == 0 ? Expanded(child: pip(i)) : pip(i),
        ],
      ],
    );
  }
}

// «باقي ٦٠ نقطة وكل واحد ياخذ يوم عفو»
class PardonBanner extends StatelessWidget {
  final int points;
  final int target;

  const PardonBanner({super.key, required this.points, required this.target});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final left = (target - points).clamp(0, target);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.pardonSoft, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        children: [
          Icon(Icons.style_rounded, size: 20, color: c.pardon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              left == 0 ? 'وصلتوا! كل واحد ياخذ يوم عفو' : 'باقي ${arabicDigits(left)} نقطة وكل واحد ياخذ يوم عفو',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: c.pardonText),
            ),
          ),
          Text('${arabicDigits(points)}/${arabicDigits(target)}', style: Theme.of(context).textTheme.labelSmall!.copyWith(color: c.pardonText)),
        ],
      ),
    );
  }
}

// a section title: Alexandria 16 with an optional note on the other side
class GroupSection extends StatelessWidget {
  final String title;
  final String? note;
  final Widget? trailing;

  const GroupSection(this.title, {super.key, this.note, this.trailing});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700))),
          if (note != null) Text(note!, style: text.labelSmall),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// «نبّه»: the orange raised button with a ringing bell
class NudgeButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const NudgeButton({super.key, required this.onPressed});

  @override
  State<NudgeButton> createState() => _NudgeButtonState();
}

class _NudgeButtonState extends State<NudgeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _ring.stop();
    } else if (!_ring.isAnimating) {
      _ring.repeat();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  // 0%,60%,100% = 0 · 10% 16° · 20% -14° · 30% 10° · 40% -6°
  double _angle(double t) {
    const keys = [0.0, 0.1, 0.2, 0.3, 0.4, 0.6];
    const values = [0.0, 16.0, -14.0, 10.0, -6.0, 0.0];
    if (t >= 0.6) return 0;
    for (var i = 0; i < keys.length - 1; i++) {
      if (t <= keys[i + 1]) {
        final f = (t - keys[i]) / (keys[i + 1] - keys[i]);
        return (values[i] + (values[i + 1] - values[i]) * Curves.easeInOut.transform(f)) * 3.1416 / 180;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const edge = Color(0xFFB9560C);
    return Semantics(
      button: true,
      label: 'نبّه',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: Motion.fast,
          constraints: const BoxConstraints(minHeight: 36),
          margin: EdgeInsets.only(top: _down ? 3 : 0, bottom: _down ? 0 : 3),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.urgent,
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: _down ? null : const [BoxShadow(color: edge, offset: Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _ring,
                builder: (context, child) => Transform.rotate(angle: _angle(_ring.value), alignment: const Alignment(0, -0.8), child: child),
                child: Icon(Icons.notifications_active_rounded, size: 17, color: c.onUrgent),
              ),
              const SizedBox(width: 6),
              Text('نبّه', style: Theme.of(context).textTheme.labelMedium!.copyWith(color: c.onUrgent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// a pill tab on the team header: white when it is open, a red dot when something is new in it
class PillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hasNew;
  final Color team;
  final VoidCallback onTap;

  const PillTab({super.key, required this.label, required this.selected, required this.team, required this.onTap, this.hasNew = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: text.labelMedium!.copyWith(color: selected ? team : Colors.white, fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
              if (hasNew) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: const Color(0xFFE5484D), shape: BoxShape.circle, border: Border.all(color: selected ? Colors.white : team, width: 1)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// the square back / menu button on a colored header
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color background;
  final Color color;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background = const Color(0x2EFFFFFF),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: color, size: 22)),
        ),
      ),
    );
  }
}

// the icon of every title of the week, in its color tile
const titleIcons = {
  'IRON': Icons.fitness_center_rounded,
  'ROCKET': Icons.rocket_launch_rounded,
  'OWL': Icons.nightlight_round,
  'ALARMIST': Icons.notifications_active_rounded,
  'COMEBACK': Icons.replay_rounded,
  'EXCUSE_KING': Icons.receipt_long_rounded,
  'TOP_DONOR': Icons.volunteer_activism_rounded,
};

Color titleColor(String? code) => AtColors.titles[code] ?? const Color(0xFF7A869C);

class TitleTile extends StatelessWidget {
  final String code;
  final double size;

  const TitleTile(this.code, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final Gradient? gradient = switch (code) {
      'IRON' => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB7C3CD), Color(0xFF5B6B79)]),
      'TOP_DONOR' => const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFE29A), Color(0xFFF2B33D), Color(0xFFC98A1E)], stops: [0, 0.55, 1]),
      _ => null,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradient == null ? titleColor(code) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(titleIcons[code] ?? Icons.workspace_premium_rounded, color: code == 'TOP_DONOR' ? const Color(0xFF0A1A3A) : Colors.white, size: size * 0.5),
    );
  }
}

// «+ اقترح هدف»: a button with a dashed border
class DashedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const DashedButton(this.label, {super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onPressed,
        child: CustomPaint(
          painter: _DashedPainter(color: c.lineStrong, radius: Radii.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Space.s3),
            child: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: c.primary, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(1));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

// ١ صوت · صوتين · ٣ أصوات
String votesAr(int n) => n == 1 ? 'صوت' : n == 2 ? 'صوتين' : n >= 3 && n <= 10 ? '${arabicDigits(n)} أصوات' : '${arabicDigits(n)} صوت';


// the paper of the moments (the dark theme keeps its own background)
Color paperColor(AtColors c) => c.isDark ? c.bg : const Color(0xFFF2EDE4);

// a game feel: things come in one after another (fade + slide up), once
class Appear extends StatelessWidget {
  final int index;
  final Widget child;
  final double offset;

  const Appear({super.key, required this.index, required this.child, this.offset = 18});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final delay = (index * 70).clamp(0, 560);
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Motion.easeOut),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child),
      ),
      child: child,
    );
  }
}

// a number that counts up to its value (points, percentages)
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;

  const CountUp(this.value, {super.key, this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text('${arabicDigits(value)}$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Motion.easeOut,
      builder: (context, v, _) => Text('${arabicDigits(v.round())}$suffix', style: style),
    );
  }
}

// a soft heartbeat (the «ضد» circle, the camera ring)
class Pulse extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration period;

  const Pulse({super.key, required this.child, this.scale = 1.08, this.period = const Duration(milliseconds: 1400)});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(scale: 1 + (widget.scale - 1) * Curves.easeInOut.transform(_c.value), child: child),
      child: widget.child,
    );
  }
}

// a sheet title with an icon tile (the sheets of the group pages)
class SheetHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;

  const SheetHeading({super.key, required this.icon, required this.title, this.subtitle, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final tint = color ?? c.primary;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: tint),
        ),
        const SizedBox(width: Space.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle!, style: text.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}
