import 'package:flutter/material.dart';

class Insets {
  Insets._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // Compatibility aliases for older screens.
  static const double xxl = lg;
  static const double xxxl = xl;

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
  static const double badgeRadius = 20;

  static const double buttonHeight = 52;
  static const double buttonHeightSm = 44;

  static const double minTouchTarget = 48;

  static const SizedBox gapXxs = SizedBox(height: xxs);
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = gapLg;

  static const SizedBox gapWXxs = SizedBox(width: xxs);
  static const SizedBox gapWXs = SizedBox(width: xs);
  static const SizedBox gapWSm = SizedBox(width: sm);
  static const SizedBox gapWMd = SizedBox(width: md);
  static const SizedBox gapWLg = SizedBox(width: lg);
  static const SizedBox gapWXl = SizedBox(width: xl);
}
