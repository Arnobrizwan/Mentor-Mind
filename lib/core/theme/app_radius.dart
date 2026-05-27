import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppRadius — corner radius tokens.
//   xs   → 4   (text fields, tiny chips)
//   sm   → 8   (badges, dense list rows)
//   md   → 12  (default buttons, default inputs)
//   lg   → 16  (default cards)
//   xl   → 20  (hero cards, sheets)
//   xxl  → 28  (logo badge, modal sheets)
//   pill → 999 (pill buttons, fully rounded chips)
//
// Each token also exposes a `*Radius` and `*Border` helper to cut down
// repetition at call sites.
// ---------------------------------------------------------------------------

abstract final class AppRadius {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 28;
  static const double pill = 999;

  static const Radius xsRadius   = Radius.circular(xs);
  static const Radius smRadius   = Radius.circular(sm);
  static const Radius mdRadius   = Radius.circular(md);
  static const Radius lgRadius   = Radius.circular(lg);
  static const Radius xlRadius   = Radius.circular(xl);
  static const Radius xxlRadius  = Radius.circular(xxl);
  static const Radius pillRadius = Radius.circular(pill);

  static const BorderRadius xsBorder   = BorderRadius.all(xsRadius);
  static const BorderRadius smBorder   = BorderRadius.all(smRadius);
  static const BorderRadius mdBorder   = BorderRadius.all(mdRadius);
  static const BorderRadius lgBorder   = BorderRadius.all(lgRadius);
  static const BorderRadius xlBorder   = BorderRadius.all(xlRadius);
  static const BorderRadius xxlBorder  = BorderRadius.all(xxlRadius);
  static const BorderRadius pillBorder = BorderRadius.all(pillRadius);
}
