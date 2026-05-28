// Golden test baselines for PillButton — 3 variants × 2 themes.
//
// Why this exists: PillButton is the canonical CTA across the redesign,
// so visual regressions on its 3 variants (primary / secondary / ghost) ripple
// through every screen. The 6-cell grid (variants × light/dark) catches:
//   - color drift in BrandColors
//   - border / radius / padding changes
//   - typography changes in AppTextStyles.labelLarge
//
// Note: brand fonts (Poppins/Inter) are referenced by name in styles but the
// .ttf files are not bundled, so button labels render as flat fallback bars in
// the baseline. Geometry is still deterministic, so visual regressions are
// caught — just don't expect the label text to be legible in the PNG.
//
// Run / regenerate baselines:
//   flutter test --update-goldens test/presentation/widgets/pill_button_golden_test.dart
// Verify:
//   flutter test test/presentation/widgets/pill_button_golden_test.dart

import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:mentor_minds/core/theme/app_theme.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';

void main() {
  testGoldens('PillButton — 3 variants × 2 themes', (tester) async {
    final builder = GoldenBuilder.grid(columns: 2, widthToHeightRatio: 2.4)
      ..addScenario('Primary · light', _cell(PillVariant.primary, light: true))
      ..addScenario('Primary · dark',  _cell(PillVariant.primary, light: false))
      ..addScenario('Secondary · light', _cell(PillVariant.secondary, light: true))
      ..addScenario('Secondary · dark',  _cell(PillVariant.secondary, light: false))
      ..addScenario('Ghost · light', _cell(PillVariant.ghost, light: true))
      ..addScenario('Ghost · dark',  _cell(PillVariant.ghost, light: false));

    await tester.pumpWidgetBuilder(
      builder.build(),
      surfaceSize: const Size(720, 640),
    );
    await screenMatchesGolden(tester, 'pill_button_variants_themes');
  });
}

/// One scenario cell. We deliberately do NOT use MaterialApp here — GoldenBuilder
/// scenarios are laid out inside a constrained grid cell, and MaterialApp tries
/// to claim a full ambient surface, which triggers layout exceptions.
Widget _cell(PillVariant variant, {required bool light}) {
  final theme = light ? AppTheme.light : AppTheme.dark;
  return Theme(
    data: theme,
    child: Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: PillButton(
        label: _labelFor(variant),
        variant: variant,
        onPressed: () {},
      ),
    ),
  );
}

String _labelFor(PillVariant v) => switch (v) {
      PillVariant.primary => 'Ask MentorBot',
      PillVariant.secondary => 'Maybe later',
      PillVariant.ghost => 'Cancel',
    };
