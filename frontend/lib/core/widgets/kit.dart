import 'package:flutter/material.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';

// small pieces the screens share: icon tiles, sheets, option cards, setting rows, pills

// a rounded square with an icon
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? fg;
  final Color? bg;
  final double size;

  const IconTile(this.icon, {super.key, this.fg, this.bg, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? c.primarySoft, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(icon, size: size * 0.5, color: fg ?? c.primary),
    );
  }
}

// a bottom sheet with a handle, it moves up with the keyboard
Future<T?> showAtSheet<T>(BuildContext context, {required WidgetBuilder builder}) => showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: builder,
    );

// the top of a sheet: an icon tile, a title and one short line
class SheetHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Color? fg;
  final Color? bg;

  const SheetHeader({super.key, this.icon, required this.title, this.subtitle, this.fg, this.bg});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s4),
      child: Row(
        children: [
          if (icon != null) ...[IconTile(icon!, fg: fg, bg: bg), const SizedBox(width: Space.s3)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.headlineSmall),
                if (subtitle != null) Text(subtitle!, style: text.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// a big choice card, filled when selected
class OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;

  const OptionCard({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.selected = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final tone = color ?? c.primary;
    final fg = selected ? Colors.white : c.ink;
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.easeOut,
      decoration: BoxDecoration(
        color: selected ? tone : c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: selected ? tone : c.line, width: 2),
        boxShadow: selected ? [BoxShadow(color: c.primaryEdge, offset: const Offset(0, 4))] : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 26, color: selected ? Colors.white.withValues(alpha: 0.85) : tone),
                const SizedBox(height: 6),
                Text(title, style: text.titleMedium!.copyWith(color: fg, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!, style: text.labelSmall!.copyWith(color: selected ? Colors.white.withValues(alpha: 0.75) : c.inkSubtle)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// rows in one card, split by thin lines
class RowGroup extends StatelessWidget {
  final List<Widget> children;

  const RowGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 56 + Space.s4, color: c.line),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

// icon, title, an optional line, and a chevron
class ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final Color? tone;

  const ActionRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.danger = false, this.tone});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final fg = danger ? c.danger : (tone ?? c.primary);
    final bg = danger ? c.dangerSoft : (tone?.withValues(alpha: 0.12) ?? c.primarySoft);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 10),
          child: Row(
            children: [
              IconTile(icon, fg: fg, bg: bg, size: 40),
              const SizedBox(width: Space.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: text.labelLarge!.copyWith(fontSize: 15, color: danger ? c.danger : c.ink)),
                    if (subtitle != null) Text(subtitle!, style: text.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: Space.s2),
              trailing ?? (onTap == null ? const SizedBox.shrink() : Icon(Icons.chevron_left_rounded, color: c.inkSubtle)),
            ],
          ),
        ),
      ),
    );
  }
}

// a small rounded label: «مربوط», «جديد»
class TagPill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;

  const TagPill(this.label, {super.key, required this.fg, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// one of a few choices side by side (فاتح / داكن / حسب الجهاز)
class SegmentedPills<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  const SegmentedPills({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.easeOut,
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: v == value ? const [BoxShadow(color: Color(0x1F10245E), blurRadius: 4, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(label,
                      style: text.labelMedium!.copyWith(color: v == value ? c.primary : c.inkSubtle, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// a number and its name, on a colored hero card
class StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final Widget? valueWidget;

  const StatCell({super.key, required this.value, required this.label, this.valueColor, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        children: [
          valueWidget ??
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: text.titleMedium!.copyWith(color: valueColor ?? Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: text.labelSmall!.copyWith(color: const Color(0xFFB7C5E8), fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// a colored card that opens a page (مهمة عشوائية، رحلة التعلّم)
class FeatureBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  final Widget? badge;

  const FeatureBanner({super.key, required this.icon, required this.title, required this.subtitle, required this.colors, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: colors),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // a soft circle in the corner
              PositionedDirectional(
                end: -30,
                top: -30,
                child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          Text(subtitle, style: text.labelSmall!.copyWith(color: Colors.white.withValues(alpha: 0.8)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: Space.s2), badge!],
                    const SizedBox(width: Space.s2),
                    const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// a section heading with an optional action on the end («لازم اليوم ··· + تعهّد جديد»)
class SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  final Widget? action;
  final IconData? icon;
  final Color? color;

  const SectionHeader(this.title, {super.key, this.count, this.action, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s5, bottom: Space.s2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color ?? context.colors.primary),
            const SizedBox(width: 6),
          ],
          Text(title, style: text.titleMedium!.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: context.colors.surfaceSunken, borderRadius: BorderRadius.circular(Radii.full)),
              child: Text(count!, style: text.labelSmall!.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// a menu line with its icon («عدّل»، «انسحب»، «احذف» in red)
PopupMenuItem<T> menuItem<T>(BuildContext context, T value, IconData icon, String label, {bool danger = false}) {
  final c = context.colors;
  final color = danger ? c.danger : c.ink;
  return PopupMenuItem<T>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: danger ? c.danger : c.inkMuted),
        const SizedBox(width: Space.s3),
        Flexible(child: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color))),
      ],
    ),
  );
}
