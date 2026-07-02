import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'app_radius.dart';
import 'brand_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        brand: BrandColors.light,
        statusBarIconBrightness: Brightness.dark,
        seed: AppColors.kPrimary,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        brand: BrandColors.dark,
        statusBarIconBrightness: Brightness.light,
        seed: AppColors.kDarkPrimary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required BrandColors brand,
    required Brightness statusBarIconBrightness,
    required Color seed,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: brand.primary,
      secondary: brand.accent,
      error: brand.error,
      surface: brand.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      // Branded type ramp with brightness-correct colors — AppTextStyles bakes
      // light-mode colors, so every slot is re-colored from BrandColors here.
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: brand.textDark),
        displayMedium:
            AppTextStyles.displayMedium.copyWith(color: brand.textDark),
        headlineLarge: AppTextStyles.headingLarge.copyWith(color: brand.textDark),
        headlineMedium:
            AppTextStyles.headingMedium.copyWith(color: brand.textDark),
        headlineSmall:
            AppTextStyles.headingSmall.copyWith(color: brand.textDark),
        titleLarge: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
        titleMedium: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
        titleSmall: AppTextStyles.labelMedium.copyWith(color: brand.textDark),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: brand.textDark),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: brand.textDark),
        labelMedium: AppTextStyles.labelMedium.copyWith(color: brand.textDark),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: brand.textMuted),
      ),
      colorScheme: scheme,
      scaffoldBackgroundColor: brand.background,
      extensions: <ThemeExtension<dynamic>>[brand],
      appBarTheme: AppBarTheme(
        backgroundColor: brand.surface,
        foregroundColor: brand.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarIconBrightness,
          statusBarBrightness: brightness == Brightness.light
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: brand.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: brand.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: brand.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: brand.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: brand.error),
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: brand.textMuted,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: brand.border,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
