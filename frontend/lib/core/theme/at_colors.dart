import 'package:flutter/material.dart';

// the colors of the design system «أتعهّد» (the blue identity), light and dark
// In a widget: final c = context.colors;  c.primary
// the golden rule: gold is for money only. Progress, done marks and points are blue (accent).
@immutable
class AtColors extends ThemeExtension<AtColors> {
  // identity
  final Color primary; // royal blue: the main button, links, the active tab
  final Color primaryHover;
  final Color primaryEdge; // the 4px edge under the raised main button
  final Color onPrimary;
  final Color primarySoft; // selected things, the active tab background
  final Color accent; // progress: bars, done times, focus ring (drawing, not small text)
  final Color shadda; // the old name of accent (done, checked, points), kept for the old screens
  final Color deep; // navy: focus screens (timer, lock, competition), the same in light and dark
  final Color deepRaised; // cards on deep
  final Color gold; // money only
  final Color goldLight;
  final Color goldDeep;
  final Color goldText; // amounts as text
  final Color onGold; // text on a gold button
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
  // game
  final Color urgent; // "must today": the pulsing card border, the time badge, the alert button
  final Color onUrgent;
  final Color urgentSoft;
  final Color urgentText;
  final Color pardon; // the pardon card (grace day)
  final Color pardonSoft;
  final Color pardonText;
  final Color streak; // the old name of urgent, kept for the old screens
  final Color streakSoft;

  const AtColors({
    required this.primary,
    required this.primaryHover,
    required this.primaryEdge,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.shadda,
    required this.deep,
    required this.deepRaised,
    required this.gold,
    required this.goldLight,
    required this.goldDeep,
    required this.goldText,
    required this.onGold,
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
    required this.urgent,
    required this.onUrgent,
    required this.urgentSoft,
    required this.urgentText,
    required this.pardon,
    required this.pardonSoft,
    required this.pardonText,
    required this.streak,
    required this.streakSoft,
  });

  static const light = AtColors(
    primary: Color(0xFF1C46C9),
    primaryHover: Color(0xFF12308F),
    primaryEdge: Color(0xFF12308F),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE3EAFB),
    accent: Color(0xFF2F6BF2),
    shadda: Color(0xFF2F6BF2),
    deep: Color(0xFF0A1A3A),
    deepRaised: Color(0xFF13285A),
    gold: Color(0xFFF2B33D),
    goldLight: Color(0xFFFFE29A),
    goldDeep: Color(0xFFC98A1E),
    goldText: Color(0xFF8A5A0B),
    onGold: Color(0xFF0A1A3A),
    bg: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEF1F7),
    line: Color(0xFFDDE3EE),
    lineStrong: Color(0xFF7A869C),
    ink: Color(0xFF121A2E),
    inkMuted: Color(0xFF3E4A61),
    inkSubtle: Color(0xFF5B667C),
    success: Color(0xFF18785F),
    successSoft: Color(0xFFE3F3EC),
    warning: Color(0xFF9A4A00),
    warningSoft: Color(0xFFFDF0DF),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBE9E7),
    info: Color(0xFF0E7490),
    infoSoft: Color(0xFFE0F2F5),
    urgent: Color(0xFFF57C1F),
    onUrgent: Color(0xFF0A1A3A),
    urgentSoft: Color(0xFFFFEBD9),
    urgentText: Color(0xFF8F3D00),
    pardon: Color(0xFF6A4BE0),
    pardonSoft: Color(0xFFEEE9FD),
    pardonText: Color(0xFF4B32B8),
    streak: Color(0xFFF57C1F),
    streakSoft: Color(0xFFFFEBD9),
  );

  static const dark = AtColors(
    primary: Color(0xFF7DA6FF),
    primaryHover: Color(0xFFA3C0FF),
    primaryEdge: Color(0xFF0A1A3A),
    onPrimary: Color(0xFF0D1630),
    primarySoft: Color(0xFF1B2C5C),
    accent: Color(0xFF5E8BFF),
    shadda: Color(0xFF5E8BFF),
    deep: Color(0xFF0A1A3A),
    deepRaised: Color(0xFF13285A),
    gold: Color(0xFFF2B33D),
    goldLight: Color(0xFFFFE29A),
    goldDeep: Color(0xFFC98A1E),
    goldText: Color(0xFFF2B33D),
    onGold: Color(0xFF0A1A3A),
    bg: Color(0xFF0D1630),
    surface: Color(0xFF152246),
    surfaceSunken: Color(0xFF0A1226),
    line: Color(0xFF22386B),
    lineStrong: Color(0xFF5F7AB8),
    ink: Color(0xFFEDF1FA),
    inkMuted: Color(0xFFB7C5E8),
    inkSubtle: Color(0xFF8E9FC9),
    success: Color(0xFF5FC9A4),
    successSoft: Color(0xFF143A30),
    warning: Color(0xFFF5A55A),
    warningSoft: Color(0xFF3A2A16),
    danger: Color(0xFFF2857A),
    dangerSoft: Color(0xFF3A1D1B),
    info: Color(0xFF67C6D9),
    infoSoft: Color(0xFF10313A),
    urgent: Color(0xFFF57C1F),
    onUrgent: Color(0xFF0A1A3A),
    urgentSoft: Color(0xFF3A2A16),
    urgentText: Color(0xFFF5A55A),
    pardon: Color(0xFFB9A8F5),
    pardonSoft: Color(0xFF2A2160),
    pardonText: Color(0xFFCFC3FA),
    streak: Color(0xFFF57C1F),
    streakSoft: Color(0xFF3A2A16),
  );

  // group colors, by the order the group was created (the same in light and dark, white text on them)
  static const teams = [
    Color(0xFF0E7490), // teal
    Color(0xFF0B7D60), // emerald
    Color(0xFFB8336F), // rose
    Color(0xFF475569), // slate
  ];

  static Color team(int index) => teams[index % teams.length];

  // the four levels: BEGINNER, COMMITTED, PERSEVERING, IRON (iron is drawn with a metal gradient)
  static const levelsLight = {
    'BEGINNER': Color(0xFFA9B8DA),
    'COMMITTED': Color(0xFF2F6BF2),
    'PERSEVERING': Color(0xFF1C46C9),
    'IRON': Color(0xFF5B6B79),
  };
  static const levelsDark = {
    'BEGINNER': Color(0xFFA9B8DA),
    'COMMITTED': Color(0xFF5E8BFF),
    'PERSEVERING': Color(0xFF7DA6FF),
    'IRON': Color(0xFF8C9BA8),
  };
  static const ironGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB7C3CD), Color(0xFF5B6B79), Color(0xFF3B4853)],
    stops: [0, 0.55, 1],
  );

  // the seven weekly titles (GroupTitleService), only the donor one is gold (it is about money)
  static const titles = {
    'IRON': Color(0xFF5B6B79),
    'ROCKET': Color(0xFFF57C1F),
    'OWL': Color(0xFF3B3F8F),
    'ALARMIST': Color(0xFF0E7490),
    'COMEBACK': Color(0xFF18785F),
    'EXCUSE_KING': Color(0xFF7A869C),
    'TOP_DONOR': Color(0xFFF2B33D),
  };

  // the gold button: linear-gradient(180deg, gold-light, gold 55%, gold-deep)
  LinearGradient get goldGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [goldLight, gold, goldDeep],
        stops: const [0, 0.55, 1],
      );

  bool get isDark => bg.computeLuminance() < 0.2;

  Color level(String? name) => (isDark ? levelsDark : levelsLight)[name] ?? levelsLight['BEGINNER']!;

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
