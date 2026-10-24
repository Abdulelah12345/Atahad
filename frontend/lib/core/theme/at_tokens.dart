import 'package:flutter/animation.dart';

// 4px grid
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
  static const double sm = 8;
  static const double md = 12; // buttons and fields
  static const double lg = 16; // cards
  static const double xl = 24;
  static const double full = 999;
}

// calm and fast, only four special moments (check, riyal to the box, level up, rank change)
class Motion {
  static const fast = Duration(milliseconds: 120); // press and hover
  static const base = Duration(milliseconds: 220); // open and close
  static const sign = Duration(milliseconds: 900); // drawing the check mark
  static const easeOut = Cubic(0.2, 0.8, 0.2, 1); // default
  static const easePop = Cubic(0.34, 1.56, 0.64, 1); // achievements and badges
  static const easeSoft = Cubic(0.4, 0, 0.2, 1); // transitions
}
