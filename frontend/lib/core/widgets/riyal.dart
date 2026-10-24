import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/at_colors.dart';
import '../utils/format.dart';

// the official riyal symbol, never "ر.س" or "SAR" (assets/icons/riyal.svg)
class RiyalSymbol extends StatelessWidget {
  final double size;
  final Color? color;

  const RiyalSymbol({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/riyal.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? context.colors.goldText, BlendMode.srcIn),
    );
  }
}

// ٧٠٫٠٠ with the riyal symbol after it (RTL: the symbol is on the left of the number)
class RiyalAmount extends StatelessWidget {
  final num? amount;
  final TextStyle? style;
  final Color? color;

  const RiyalAmount(this.amount, {super.key, this.style, this.color});

  @override
  Widget build(BuildContext context) {
    final textStyle = (style ?? Theme.of(context).textTheme.titleMedium)!.copyWith(
      color: color ?? context.colors.goldText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final size = (textStyle.fontSize ?? 16) * 0.8;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(money(amount), style: textStyle),
        SizedBox(width: size * 0.25),
        RiyalSymbol(size: size, color: textStyle.color),
      ],
    );
  }
}
