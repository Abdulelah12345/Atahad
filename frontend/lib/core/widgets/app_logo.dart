import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/at_colors.dart';

// the approved logo «أزرق + لمعة الإنجاز» (a picture, never written with a font)
// blue ink on light backgrounds, the reverse (white ink) on dark ones (dark mode, deep or primary)
// the smallest full logo is 120 wide, under it use the app icon
//   AppLogo(width: 160)                the logo
//   AppLogo(width: 160, tagline: true) with "في الحالتين.. خير" under it
//   AppLogo(width: 160, white: true)   on a dark background
class AppLogo extends StatelessWidget {
  final double width;
  final bool tagline;
  final bool? white; // null = by the theme

  const AppLogo({super.key, this.width = 160, this.tagline = false, this.white});

  @override
  Widget build(BuildContext context) {
    final onDark = white ?? Theme.of(context).brightness == Brightness.dark;
    final logo = SvgPicture.asset(
      onDark ? 'assets/brand/logo_reverse.svg' : 'assets/brand/logo.svg',
      width: width,
      semanticsLabel: 'أتعهّد',
    );
    if (!tagline) return logo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        SizedBox(height: width * 0.06),
        Text(
          'في الحالتين.. خير',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: (width * 0.09).clamp(12, 20).toDouble(),
                fontWeight: FontWeight.w400,
                color: onDark ? const Color(0xFFB7C5E8) : context.colors.inkMuted,
              ),
        ),
      ],
    );
  }
}
