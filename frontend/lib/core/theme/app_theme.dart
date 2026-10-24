import 'package:flutter/material.dart';

import 'at_colors.dart';
import 'at_text.dart';
import 'at_tokens.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light, AtColors.light);

  static ThemeData dark() => _build(Brightness.dark, AtColors.dark);

  static ThemeData _build(Brightness brightness, AtColors c) {
    final text = AtText.theme(c.ink, c.inkMuted);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: c.line),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        secondary: c.gold,
        onSecondary: c.onGold,
        error: c.danger,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.ink,
      ),
      scaffoldBackgroundColor: c.bg,
      textTheme: text,
      extensions: [c],
      dividerColor: c.line,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.headlineSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3 + 2),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.primary, width: 1.5)),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 1.5)),
        labelStyle: text.labelLarge?.copyWith(color: c.inkMuted),
        hintStyle: text.bodyMedium?.copyWith(color: c.inkSubtle),
        errorStyle: text.labelSmall?.copyWith(color: c.danger),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(color: c.ink)),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.primary : c.inkSubtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.deep,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }
}
