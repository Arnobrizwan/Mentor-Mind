import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';

// ---------------------------------------------------------------------------
// SkeletonBlock — atomic loading placeholder. Wrap any list/grid item with
// repeated SkeletonBlocks to produce a shimmer skeleton while data loads.
//
// Skeleton screens are now standard across screens for the redesign — they
// reduce perceived latency and avoid the "blank then pop" feel of spinners.
//
// Use via composition:
//   Column(children: [
//     SkeletonBlock(height: 14, width: 120),
//     SizedBox(height: 8),
//     SkeletonBlock(height: 14, width: double.infinity),
//   ])
//
// Or wrap a whole subtree in SkeletonGroup for one shimmer animation
// covering many blocks at once (cheaper + visually unified).
// ---------------------------------------------------------------------------

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = AppRadius.smRadius,
  });

  final double width;
  final double height;
  final Radius radius;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    // When inside a SkeletonGroup the parent Shimmer paints the gradient
    // and these blocks just provide the silhouette. Outside a group we
    // wrap in our own Shimmer for standalone use.
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: brand.border,
        borderRadius: BorderRadius.all(radius),
      ),
    );
    if (SkeletonGroup.of(context)) return block;
    return Shimmer.fromColors(
      baseColor: brand.border,
      highlightColor: brand.surfaceAlt,
      child: block,
    );
  }
}

/// Wrap a subtree to share a single shimmer animation across many
/// [SkeletonBlock]s. Cheaper to paint and visually unified.
class SkeletonGroup extends StatelessWidget {
  const SkeletonGroup({super.key, required this.child});

  final Widget child;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonScope>() != null;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Shimmer.fromColors(
      baseColor: brand.border,
      highlightColor: brand.surfaceAlt,
      child: _SkeletonScope(child: child),
    );
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required super.child});

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) => false;
}
