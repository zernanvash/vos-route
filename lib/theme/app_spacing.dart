import 'package:flutter/material.dart';

class Insets {
  Insets._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  static const EdgeInsets hSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets hMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets hLg = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets vSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets vMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets vLg = EdgeInsets.symmetric(vertical: lg);

  static const EdgeInsets rowSm = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );

  static const EdgeInsets cardLg = EdgeInsets.all(lg);
  static const EdgeInsets cardInner = EdgeInsets.all(md);

  static const EdgeInsets badgeSm = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xxs,
  );
  static const EdgeInsets badgeMd = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );

  static const double cardRadius = 12;
  static const double smallRadius = 8;
  static const double badgeRadius = 6;

  static const double buttonHeight = 52;
  static const double buttonHeightSm = 44;

  static const double minTouchTarget = 48;

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);
  static const SizedBox gapWSm = SizedBox(width: sm);
  static const SizedBox gapWMd = SizedBox(width: md);
  static const SizedBox gapWLg = SizedBox(width: lg);
}
