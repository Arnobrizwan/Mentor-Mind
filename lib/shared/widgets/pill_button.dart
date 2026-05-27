import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/theme/app_motion.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';

// ---------------------------------------------------------------------------
// PillButton — the canonical CTA component across the redesign.
//
// Three variants:
//   primary   — filled indigo, white text. The single most prominent CTA per
//               screen (e.g. "Ask MentorBot", "Sign in", "Continue").
//   secondary — outline + indigo text. For non-destructive lesser actions.
//   ghost     — no background, indigo text. For inline links / "Cancel".
//
// Sizing follows an 8pt rhythm: minHeight=52 (matches existing theme button
// height), horizontal padding=24, optional leading icon with 8px gap.
// ---------------------------------------------------------------------------

enum PillVariant { primary, secondary, ghost }

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillVariant.primary,
    this.icon,
    this.fullWidth = true,
    this.dense = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final IconData? icon;
  final bool fullWidth;
  final bool dense;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final enabled = onPressed != null && !loading;

    Color bg, fg;
    Border? border;
    switch (variant) {
      case PillVariant.primary:
        bg = enabled ? brand.primary : brand.primary.withValues(alpha: 0.4);
        fg = Colors.white;
        border = null;
      case PillVariant.secondary:
        bg = Colors.transparent;
        fg = enabled ? brand.primary : brand.primary.withValues(alpha: 0.4);
        border = Border.all(color: brand.border, width: 1.5);
      case PillVariant.ghost:
        bg = Colors.transparent;
        fg = enabled ? brand.primary : brand.primary.withValues(alpha: 0.4);
        border = null;
    }

    final height = dense ? 40.0 : 52.0;
    final padding = dense
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.lg)
        : const EdgeInsets.symmetric(horizontal: AppSpacing.xl);

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: AnimatedContainer(
        duration: AppMotion.micro,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: AppRadius.pillBorder,
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize:
                    fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  else if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (!loading)
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
