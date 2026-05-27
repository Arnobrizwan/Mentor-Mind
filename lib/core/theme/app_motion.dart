import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppMotion — duration + curve tokens for consistent animation across the app.
// The redesign mixes Calm-Edu (subtle, short) base motion with Duolingo-Brave
// "moments" (celebratory, snappy) for streaks, badges, and CTAs.
//
// Rules of thumb:
//   - 120ms: micro-feedback (chip toggle, ripple complete)
//   - 200ms: standard transitions (page slide, toast in/out)
//   - 350ms: hero entrances (splash logo, login lockup)
//   - 600ms: celebratory moments (badge earned, streak fire)
// ---------------------------------------------------------------------------

abstract final class AppMotion {
  // -------- Durations --------
  static const Duration micro    = Duration(milliseconds: 120);
  static const Duration short    = Duration(milliseconds: 200);
  static const Duration medium   = Duration(milliseconds: 350);
  static const Duration long     = Duration(milliseconds: 600);
  static const Duration luxurious = Duration(milliseconds: 900);

  // -------- Curves --------

  /// Default — smooth, no overshoot. Use for nav, toasts, fades.
  static const Curve standard = Curves.easeOutCubic;

  /// Settling — slight ease in. Use for content arrivals (skeleton → real).
  static const Curve settle = Curves.easeInOut;

  /// Celebratory — slight overshoot, bouncy. Use for badge earned + streak.
  static const Curve celebrate = Curves.easeOutBack;

  /// Decisive — sharp entry. Use for primary CTA press feedback.
  static const Curve decisive = Curves.easeOutQuart;
}
