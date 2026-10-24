import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Alexandria for titles and numbers, IBM Plex Sans Arabic for the text. No letter spacing on Arabic.
// In a widget: Text('...', style: Theme.of(context).textTheme.headlineMedium)
//   displayLarge = display / headlineLarge = h1 / headlineMedium = h2 / headlineSmall = h3
//   titleLarge = amount / bodyLarge = body-lg / bodyMedium = body / bodySmall = body-sm
//   labelLarge = label / labelSmall = caption
class AtText {
  static TextStyle _title(double size, double line, FontWeight weight, Color color) =>
      GoogleFonts.alexandria(fontSize: size, height: line / size, fontWeight: weight, color: color);

  static TextStyle _body(double size, double line, FontWeight weight, Color color) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: size, height: line / size, fontWeight: weight, color: color);

  static TextTheme theme(Color ink, Color muted) => TextTheme(
        displayLarge: _title(40, 52, FontWeight.w800, ink),
        headlineLarge: _title(32, 44, FontWeight.w700, ink),
        headlineMedium: _title(24, 34, FontWeight.w700, ink),
        headlineSmall: _title(20, 30, FontWeight.w600, ink),
        titleLarge: _title(32, 40, FontWeight.w700, ink).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        titleMedium: _title(16, 24, FontWeight.w600, ink),
        titleSmall: _title(14, 20, FontWeight.w600, ink),
        bodyLarge: _body(18, 30, FontWeight.w400, ink),
        bodyMedium: _body(16, 26, FontWeight.w400, ink),
        bodySmall: _body(14, 22, FontWeight.w400, muted),
        labelLarge: _body(14, 20, FontWeight.w600, ink),
        labelMedium: _body(13, 18, FontWeight.w600, ink),
        labelSmall: _body(12, 18, FontWeight.w500, muted),
      );
}
