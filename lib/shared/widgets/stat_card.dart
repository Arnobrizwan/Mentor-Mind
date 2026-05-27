import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/theme/app_elevation.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';

// ---------------------------------------------------------------------------
// StatCard — the canonical "labeled number" tile used on Dashboard, Rewards,
// and Admin Analytics.
//
//   ┌────────────────────┐
//   │ 🔥                 │   ← optional leading icon (tinted circle)
//   │ 7-day streak       │   ← label, bodySmall + textMuted
//   │ 12 days            │   ← value, headingMedium + textDark
//   │ +3 this week       │   ← optional trend, labelSmall
//   └────────────────────┘
//
// Variants control accent tint (primary/accent/gold/error). Wrap in
// SkeletonGroup with placeholder StatCard.skeleton() while loading.
// ---------------------------------------------------------------------------

enum StatTint { primary, accent, gold, error }

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tint = StatTint.primary,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final StatTint tint;

  /// Optional caption underneath the value, e.g. "+3 this week".
  /// Color follows the tint so positive/negative momentum reads at a glance.
  final String? trend;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tintColor = switch (tint) {
      StatTint.primary => brand.primary,
      StatTint.accent => brand.accent,
      StatTint.gold => brand.gold,
      StatTint.error => brand.error,
    };

    final body = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: brand.border, width: 1),
        boxShadow: AppElevation.low,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tintColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.smBorder,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: tintColor, size: 20),
            ),
          if (icon != null) const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
          ),
          if (trend != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              trend!,
              style: AppTextStyles.labelSmall.copyWith(color: tintColor),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.lgBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgBorder,
        child: body,
      ),
    );
  }
}
