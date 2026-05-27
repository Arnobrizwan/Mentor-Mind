import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';

// ---------------------------------------------------------------------------
// EmptyState — used wherever a list/grid has no items, or after a filter
// clears everything. Visual recipe: tinted circular badge + headline +
// supportive sentence + optional CTA button.
//
// Variants:
//   - default        — informational, accent tint
//   - search         — for "no results" with a magnifier feel
//   - error          — for retry-able failures, error tint
//
// Keeps Calm-Edu base (lots of whitespace, restrained), with Duolingo-Brave
// CTA highlighting via PillButton primary.
// ---------------------------------------------------------------------------

enum EmptyStateVariant { info, search, error }

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.variant = EmptyStateVariant.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final String title;
  final String message;
  final EmptyStateVariant variant;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tint = switch (variant) {
      EmptyStateVariant.info => brand.accent,
      EmptyStateVariant.search => brand.primary,
      EmptyStateVariant.error => brand.error,
    };
    final defaultIcon = switch (variant) {
      EmptyStateVariant.info => Icons.inbox_outlined,
      EmptyStateVariant.search => Icons.search_off_rounded,
      EmptyStateVariant.error => Icons.error_outline_rounded,
    };

    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: AppRadius.pillBorder,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon ?? defaultIcon,
              size: 32,
              color: tint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            PillButton(
              label: actionLabel!,
              onPressed: onAction,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}
