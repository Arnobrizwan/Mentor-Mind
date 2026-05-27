import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/theme/app_motion.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';

// ---------------------------------------------------------------------------
// SubjectChip — selectable pill used in onboarding (subject grid), materials
// (filter row), and profile (edit subjects sheet).
//
// Selected state uses an indigo fill (Duolingo-Brave moment); unselected
// uses a hairline border on the surface (Calm-Edu base). Switches with a
// 120ms ease — the canonical micro feedback duration.
//
// Optional [emoji] renders before the label for the onboarding grid where
// subjects feel friendlier with an icon.
// ---------------------------------------------------------------------------

class SubjectChip extends StatelessWidget {
  const SubjectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final bg = selected ? brand.primary : Colors.transparent;
    final fg = selected ? Colors.white : brand.textDark;
    final borderColor = selected ? brand.primary : brand.border;

    final padding = dense
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs)
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm);

    return AnimatedContainer(
      duration: AppMotion.micro,
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.pillBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) ...[
                  Text(emoji!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: fg,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
