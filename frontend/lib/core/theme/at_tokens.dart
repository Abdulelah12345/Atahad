import 'package:flutter/material.dart';

// 4px grid, the side margin of a screen is s4
class Space {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

class Radii {
  static const double sm = 8; // small badges, the days of the week
  static const double md = 12; // buttons and fields
  static const double lg = 16; // cards
  static const double card = 20; // task and group cards (softer)
  static const double xl = 24; // bottom sheets and banners
  static const double full = 999; // pills and circles
}

// calm, the special moments only: an accepted proof, "must today", the alert, unlocking, the rank, the splash
// one celebration per screen; respect MediaQuery.disableAnimations
class Motion {
  static const fast = Duration(milliseconds: 120); // press and hover
  static const base = Duration(milliseconds: 220); // open and close, rows sliding
  static const reward = Duration(milliseconds: 500); // +10 and badges with a pop
  static const sign = Duration(milliseconds: 900); // drawing the check mark
  static const easeOut = Cubic(0.2, 0.8, 0.2, 1); // default
  static const easePop = Cubic(0.34, 1.56, 0.64, 1); // rewards and badges
  static const easeSoft = Cubic(0.4, 0, 0.2, 1); // transitions between screens
}

// the shadows (light / dark)
class AtShadows {
  static List<BoxShadow> card(bool dark) => dark
      ? const [
          BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 4)),
        ]
      : const [
          BoxShadow(color: Color(0x0F10245E), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x1410245E), blurRadius: 16, offset: Offset(0, 4)),
        ];

  static List<BoxShadow> raised(bool dark) =>
      [BoxShadow(color: dark ? const Color(0x80000000) : const Color(0x2910245E), blurRadius: 32, offset: const Offset(0, 12))];

  // the gold (donate) button only
  static List<BoxShadow> gold(bool dark) =>
      [BoxShadow(color: dark ? const Color(0x33DDAE52) : const Color(0x4DB4873A), blurRadius: 20, offset: const Offset(0, 6))];
}
