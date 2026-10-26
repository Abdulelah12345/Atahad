import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';

// primary = the main action, raised on a 4px edge that presses down (ONE per screen)
// gold = there is money in it (donate) / outline = secondary / text = a quiet link
// labels are verbs: "ارفع الإثبات"، "نبّه"، "انضم للمجموعة"
enum AtButtonKind { gold, primary, outline, text }

class AtButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AtButtonKind kind;
  final bool loading;
  final bool expand;
  final Widget? icon;

  const AtButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = AtButtonKind.primary,
    this.loading = false,
    this.expand = true,
    this.icon,
  });

  @override
  State<AtButton> createState() => _AtButtonState();
}

class _AtButtonState extends State<AtButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _set(bool down) {
    if (_enabled && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final disabled = widget.onPressed == null && !widget.loading;
    final kind = widget.kind;

    final Color fg = disabled && kind != AtButtonKind.text
        ? c.inkSubtle
        : switch (kind) {
            AtButtonKind.gold => c.onGold,
            AtButtonKind.primary => c.onPrimary,
            _ => c.primary,
          };

    BoxDecoration decoration;
    double edge = 0; // the raised edge under the primary button
    if (disabled && kind != AtButtonKind.text) {
      decoration = BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md));
    } else {
      switch (kind) {
        case AtButtonKind.primary:
          edge = _down ? 1 : 4;
          decoration = BoxDecoration(
            color: _down ? c.primaryHover : c.primary,
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: [BoxShadow(color: c.primaryEdge, offset: Offset(0, edge))],
          );
        case AtButtonKind.gold:
          decoration = BoxDecoration(
            gradient: c.goldGradient,
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: AtShadows.gold(dark),
          );
        case AtButtonKind.outline:
          decoration = BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.lineStrong),
          );
        case AtButtonKind.text:
          decoration = BoxDecoration(borderRadius: BorderRadius.circular(Radii.md));
      }
    }

    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 16, color: fg);
    final child = widget.loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                IconTheme.merge(data: IconThemeData(color: fg, size: 20), child: widget.icon!),
                const SizedBox(width: Space.s2),
              ],
              Flexible(child: Text(widget.label, style: textStyle, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = Semantics(
      button: true,
      enabled: _enabled,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.easeOut,
          // the primary button goes down as its edge gets smaller
          margin: EdgeInsets.only(top: kind == AtButtonKind.primary && !disabled ? 4 - edge : 0, bottom: kind == AtButtonKind.primary && !disabled ? edge : 0),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: Space.s6),
          alignment: Alignment.center,
          decoration: decoration,
          child: AnimatedScale(scale: _down && kind != AtButtonKind.primary ? 0.98 : 1, duration: Motion.fast, child: child),
        ),
      ),
    );
    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
