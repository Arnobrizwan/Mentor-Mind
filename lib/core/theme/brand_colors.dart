import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';

// ---------------------------------------------------------------------------
// BrandColors — ThemeExtension exposing the MentorMinds palette through
// Theme.of(context). The values flip automatically between light and dark
// because we register a different instance for each ThemeData in AppTheme.
//
// Why an extension (not direct AppColors references)?
//   - 400+ existing call sites use AppColors.kXxx (the light constants).
//     We keep that working for the migration period.
//   - New code in the redesign reads from BrandColors via:
//       final brand = Theme.of(context).extension<BrandColors>()!;
//       Container(color: brand.surface, ...)
//     and gets dark-mode swapping for free.
// ---------------------------------------------------------------------------

@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.primary,
    required this.accent,
    required this.gold,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textDark,
    required this.textMuted,
    required this.error,
  });

  final Color primary;
  final Color accent;
  final Color gold;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textDark;
  final Color textMuted;
  final Color error;

  static const BrandColors light = BrandColors(
    primary: AppColors.kPrimary,
    accent: AppColors.kAccent,
    gold: AppColors.kGold,
    background: AppColors.kBackground,
    surface: AppColors.kSurface,
    surfaceAlt: AppColors.kSurfaceAlt,
    border: AppColors.kBorder,
    textDark: AppColors.kTextDark,
    textMuted: AppColors.kTextMuted,
    error: AppColors.kError,
  );

  static const BrandColors dark = BrandColors(
    primary: AppColors.kDarkPrimary,
    accent: AppColors.kDarkAccent,
    gold: AppColors.kDarkGold,
    background: AppColors.kDarkBackground,
    surface: AppColors.kDarkSurface,
    surfaceAlt: AppColors.kDarkSurfaceAlt,
    border: AppColors.kDarkBorder,
    textDark: AppColors.kDarkTextDark,
    textMuted: AppColors.kDarkTextMuted,
    error: AppColors.kDarkError,
  );

  @override
  BrandColors copyWith({
    Color? primary,
    Color? accent,
    Color? gold,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textDark,
    Color? textMuted,
    Color? error,
  }) =>
      BrandColors(
        primary: primary ?? this.primary,
        accent: accent ?? this.accent,
        gold: gold ?? this.gold,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        border: border ?? this.border,
        textDark: textDark ?? this.textDark,
        textMuted: textMuted ?? this.textMuted,
        error: error ?? this.error,
      );

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textDark: Color.lerp(textDark, other.textDark, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

/// Convenience reader: `context.brand.primary` instead of the long form.
extension BrandColorsX on BuildContext {
  BrandColors get brand =>
      Theme.of(this).extension<BrandColors>() ?? BrandColors.light;
}
