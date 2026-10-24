import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';

// gold = there is money in it / primary = the main action (one per screen) / outline / text
// labels are verbs: "ارفع الإثبات"، "التزم"، "انضم للمجموعة"
enum AtButtonKind { gold, primary, outline, text }

class AtButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.colors;
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 15);
    final (Color bg, Color fg, BorderSide side) = switch (kind) {
      AtButtonKind.gold => (c.gold, c.onGold, BorderSide.none),
      AtButtonKind.primary => (c.primary, c.onPrimary, BorderSide.none),
      AtButtonKind.outline => (Colors.transparent, c.primary, BorderSide(color: c.primary)),
      AtButtonKind.text => (Colors.transparent, c.primary, BorderSide.none),
    };
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: Space.s2)],
              Flexible(child: Text(label, style: textStyle.copyWith(color: fg), overflow: TextOverflow.ellipsis)),
            ],
          );
    final button = TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: onPressed == null && kind != AtButtonKind.text && kind != AtButtonKind.outline
            ? bg.withValues(alpha: 0.45)
            : bg,
        foregroundColor: fg,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.s5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: side),
        elevation: kind == AtButtonKind.gold ? 2 : 0,
        shadowColor: c.goldDeep.withValues(alpha: 0.4),
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
