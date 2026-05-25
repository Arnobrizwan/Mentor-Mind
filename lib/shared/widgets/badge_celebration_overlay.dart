import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/rewards/gamification_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/observability/analytics_service.dart';
import 'package:mentor_minds/data/models/badge_info.dart';

/// SHRD-02 — global badge-earned overlay (mount in [AppShell]).
class BadgeCelebrationHost extends ConsumerStatefulWidget {
  const BadgeCelebrationHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BadgeCelebrationHost> createState() =>
      _BadgeCelebrationHostState();
}

class _BadgeCelebrationHostState extends ConsumerState<BadgeCelebrationHost> {
  BadgeInfo? _active;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _show(BadgeInfo badge) {
    _dismissTimer?.cancel();
    setState(() => _active = badge);
    unawaited(ref.read(analyticsServiceProvider).logEarnBadge(badge.id));
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _active = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<BadgeInfo>>(badgeEarnedEventProvider, (_, next) {
      final badge = next.valueOrNull;
      if (badge != null) _show(badge);
    });

    return Stack(
      children: [
        widget.child,
        if (_active != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _active = null),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: _BadgeCelebrationCard(badge: _active!)
                    .animate()
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 200.ms),
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeCelebrationCard extends StatelessWidget {
  const _BadgeCelebrationCard({required this.badge});

  final BadgeInfo badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.kSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.kGold.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Badge earned!', style: AppTextStyles.headingMedium),
            const SizedBox(height: 6),
            Text(
              badge.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.kTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.kGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '+30 pts',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.kGold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap anywhere to dismiss',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
