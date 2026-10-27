import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';

// the white card: a thin line instead of a heavy shadow (radius lg, or Radii.card for task and group cards)
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.s4),
    this.onTap,
    this.color,
    this.radius = Radii.lg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: color == null ? Border.all(color: c.line) : null,
        boxShadow: color == null ? null : AtShadows.card(dark),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
