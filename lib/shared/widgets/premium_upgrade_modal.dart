import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/observability/analytics_service.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/application/viewmodels/profile/profile_viewmodel.dart';

/// SHRD-01 — shared premium upgrade bottom sheet.
class PremiumUpgradeModal extends ConsumerWidget {
  const PremiumUpgradeModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.brand.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const PremiumUpgradeModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // All copy + pricing comes from /config/subscription (Remote Config) so
    // the price shown here can never diverge from the profile upgrade card.
    final config = ref.watch(currentSubscriptionConfigProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.brand.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.kPrimary, Color(0xFF3E7D74)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.kGold, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    config.headline,
                    style: AppTextStyles.headingLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final feature in config.features) _feature(feature),
                  const SizedBox(height: 4),
                  Text(
                    '${config.currencySymbol}${config.monthlyPriceBdt} / month',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final router = GoRouter.of(context);
                await ref.read(analyticsServiceProvider).logUpgradeStarted();
                navigator.pop();
                router.goNamed(AppRoutes.profile);
                final err = await ref
                    .read(profileViewModelProvider.notifier)
                    .startPremiumCheckout();
                if (err == null) {
                  await ref
                      .read(profileViewModelProvider.notifier)
                      .refreshAuthToken();
                  await ref
                      .read(analyticsServiceProvider)
                      .logUpgradeCompleted();
                }
              },
              child: Text(config.ctaLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
