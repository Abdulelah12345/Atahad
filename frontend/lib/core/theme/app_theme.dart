import 'package:flutter/material.dart';

import 'at_colors.dart';
import 'at_text.dart';
import 'at_tokens.dart';

class AppTheme {
  static ThemeData light() => _build(Brightness.light, AtColors.light);

  static ThemeData dark() => _build(Brightness.dark, AtColors.dark);

  static ThemeData _build(Brightness brightness, AtColors c) {
    final text = AtText.theme(c.ink, c.inkMuted);
    // the fields: sunken, a 3:1 border, the primary border when focused
    final dark = brightness == Brightness.dark;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: dark ? c.line : c.lineStrong.withValues(alpha: 0.55)),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primarySoft,
        onPrimaryContainer: c.primary,
        secondary: c.accent,
        onSecondary: c.onPrimary,
        tertiary: c.gold,
        onTertiary: c.onGold,
        error: c.danger,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.ink,
        onSurfaceVariant: c.inkMuted,
        outline: c.lineStrong,
        outlineVariant: c.line,
        surfaceContainerHighest: c.surfaceSunken,
      ),
      scaffoldBackgroundColor: c.bg,
      textTheme: text,
      extensions: [c],
      dividerColor: c.line,
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: c.line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // light: white fields on the grey page (the design), dark: a step below the cards
        fillColor: dark ? c.surfaceSunken : c.surface,
        prefixIconColor: c.inkSubtle,
        suffixIconColor: c.inkSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3 + 2),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.primary, width: 2)),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 2)),
        labelStyle: text.labelLarge?.copyWith(color: c.inkMuted),
        hintStyle: text.bodyMedium?.copyWith(color: c.inkSubtle),
        errorStyle: text.labelSmall?.copyWith(color: c.danger),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        height: 68,
        indicatorColor: c.primarySoft,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? c.primary : c.inkSubtle,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.primary : c.inkSubtle),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.inkSubtle,
        indicatorColor: c.primary,
        dividerColor: c.line,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary, textStyle: text.labelLarge, minimumSize: const Size(44, 44)),
      ),
      // the plain Material buttons look like AtButton (48px, radius md, a verb in labelLarge 16)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.inkSubtle,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.s6),
          textStyle: text.labelLarge!.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.inkSubtle,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.s6),
          textStyle: text.labelLarge!.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.primary,
          side: BorderSide(color: c.lineStrong),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.s6),
          textStyle: text.labelLarge!.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primarySoft,
        side: BorderSide(color: c.line),
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.full)),
      ),
      // the menus: rounded, a line instead of a shadow tint
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x3310245E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: c.line)),
        textStyle: text.labelLarge,
        labelTextStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.primary,
        titleTextStyle: text.labelLarge!.copyWith(fontSize: 15),
        subtitleTextStyle: text.labelSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        minVerticalPadding: 10,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: c.primary,
        collapsedIconColor: c.inkSubtle,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.lineStrong.withValues(alpha: 0.4),
        dragHandleSize: const Size(40, 5),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.deep,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.surfaceSunken),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.lineStrong),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceSunken),
      ),
    );
  }
}
