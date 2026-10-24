import 'package:flutter/material.dart';

// the colors of the design system (light and dark). In a widget: final c = context.colors;  c.primary
// the golden rule: gold is for money only. Points and done marks use shadda green.
@immutable
class AtColors extends ThemeExtension<AtColors> {
  // identity
  final Color primary; // ink green: the brand, the text and the main buttons
  final Color shadda; // done, checked, points
  final Color gold; // money only
  final Color goldLight;
  final Color goldDeep;
  final Color goldText; // gold text on a light background
  final Color onGold; // text on a gold button
  final Color deep; // the darkest green
  final Color primarySoft;
  final Color onPrimary;
  // neutral
  final Color bg;
  final Color surface;
  final Color surfaceSunken;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;
  // states
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  // streak
  final Color streak;
  final Color streakSoft;

  const AtColors({
    required this.primary,
    required this.shadda,
    required this.gold,
    required this.goldLight,
    required this.goldDeep,
    required this.goldText,
    required this.onGold,
    required this.deep,
    required this.primarySoft,
    required this.onPrimary,
    required this.bg,
    required this.surface,
    required this.surfaceSunken,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.streak,
    required this.streakSoft,
  });

  static const light = AtColors(
    primary: Color(0xFF0E4D45),
    shadda: Color(0xFF1F8A70),
    gold: Color(0xFFF2B33D),
    goldLight: Color(0xFFFFE29A),
    goldDeep: Color(0xFFC98A1E),
    goldText: Color(0xFF8A5A0B),
    onGold: Color(0xFF072A25),
    deep: Color(0xFF072A25),
    primarySoft: Color(0xFFDCEDE7),
    onPrimary: Color(0xFFFFFFFF),
    bg: Color(0xFFF5F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEF2F0),
    line: Color(0xFFDCE4E0),
    lineStrong: Color(0xFF748984),
    ink: Color(0xFF12302B),
    inkMuted: Color(0xFF3E524D),
    inkSubtle: Color(0xFF5A6B66),
    success: Color(0xFF1F8A70),
    successSoft: Color(0xFFDCEDE7),
    warning: Color(0xFF9A5B00),
    warningSoft: Color(0xFFFDF0D9),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBE4E2),
    info: Color(0xFF1A73B5),
    infoSoft: Color(0xFFE2EEF8),
    streak: Color(0xFFF57C1F),
    streakSoft: Color(0xFFFFEBDC),
  );

  static const dark = AtColors(
    primary: Color(0xFF5FC9A4),
    shadda: Color(0xFF3FAE8C),
    gold: Color(0xFFF2B33D),
    goldLight: Color(0xFFFFE29A),
    goldDeep: Color(0xFFC98A1E),
    goldText: Color(0xFFF2B33D),
    onGold: Color(0xFF072A25),
    deep: Color(0xFF072A25),
    primarySoft: Color(0xFF173F38),
    onPrimary: Color(0xFF072A25),
    bg: Color(0xFF0B1F1C),
    surface: Color(0xFF12302B),
    surfaceSunken: Color(0xFF081815),
    line: Color(0xFF24453F),
    lineStrong: Color(0xFF6E9189),
    ink: Color(0xFFEAF3EF),
    inkMuted: Color(0xFFB9D6CC),
    inkSubtle: Color(0xFF8FAAA2),
    success: Color(0xFF5FC9A4),
    successSoft: Color(0xFF173F38),
    warning: Color(0xFFF2B33D),
    warningSoft: Color(0xFF3A2E12),
    danger: Color(0xFFF2877E),
    dangerSoft: Color(0xFF3D1F1C),
    info: Color(0xFF7DB8E8),
    infoSoft: Color(0xFF15304A),
    streak: Color(0xFFF57C1F),
    streakSoft: Color(0xFF3D2412),
  );

  // group colors, by the order the group was created (the same in light and dark)
  static const teams = [
    Color(0xFF0B7D60), // emerald
    Color(0xFF1A73B5), // sky
    Color(0xFF6A4BE0), // violet
    Color(0xFFB8336F), // rose
  ];

  static Color team(int index) => teams[index % teams.length];

  @override
  AtColors copyWith() => this;

  @override
  AtColors lerp(covariant ThemeExtension<AtColors>? other, double t) {
    if (other is! AtColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AtColorsContext on BuildContext {
  AtColors get colors => Theme.of(this).extension<AtColors>()!;
}
