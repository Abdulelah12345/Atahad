import 'package:flutter/material.dart';

// the logo (a picture, never written with a font)
// green on light backgrounds, white on dark ones (dark mode or the deep green)
//   AppLogo(width: 160)               the logo
//   AppLogo(width: 160, tagline: true) with "في الحالتين.. خير"
//   AppLogo(width: 160, white: true)  on a dark background
class AppLogo extends StatelessWidget {
  final double width;
  final bool tagline;
  final bool? white; // null = by the theme

  const AppLogo({super.key, this.width = 160, this.tagline = false, this.white});

  @override
  Widget build(BuildContext context) {
    final onDark = white ?? Theme.of(context).brightness == Brightness.dark;
    final file = onDark ? 'logo_white.png' : (tagline ? 'logo_tagline.png' : 'logo.png');
    return Image.asset('assets/images/$file', width: width, fit: BoxFit.contain, semanticLabel: 'أتعهّد');
  }
}
