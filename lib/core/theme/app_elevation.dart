import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppElevation — calibrated shadow tokens.
// Material 3 elevations feel too heavy for the Calm-Edu base; these are
// tuned for a softer paper-on-paper feel with restrained darkening.
//
// Usage:
//   BoxDecoration(
//     borderRadius: AppRadius.lgBorder,
//     color: Colors.white,
//     boxShadow: AppElevation.card,
//   )
// ---------------------------------------------------------------------------

abstract final class AppElevation {
  /// No shadow — for inline content / dark surfaces.
  static const List<BoxShadow> none = [];

  /// Subtle hairline lift — for inline cards, list items.
  static const List<BoxShadow> low = [
    BoxShadow(
      color: Color(0x0D1C1F2E), // 5% slate
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  /// Default card resting state — the workhorse.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x141C1F2E), // 8% slate
      blurRadius: 14,
      offset: Offset(0, 2),
    ),
  ];

  /// Raised CTA / floating action — lifts toward the user.
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1F1C1F2E), // 12% slate
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// Modal / sheet — biggest visible lift below an overlay.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x331C1F2E), // 20% slate
      blurRadius: 36,
      offset: Offset(0, 16),
    ),
  ];
}
