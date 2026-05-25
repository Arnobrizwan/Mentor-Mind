import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';

/// SHRD-03 — connectivity-driven banner at top of app shell.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityOnlineProvider).valueOrNull ?? true;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: online ? const Offset(0, -1) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        opacity: online ? 0 : 1,
        child: online
            ? const SizedBox.shrink()
            : Material(
                color: AppColors.kError,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "You're offline — some features may not work",
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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

final connectivityOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield _isOnline(initial);
  await for (final result in connectivity.onConnectivityChanged) {
    yield _isOnline(result);
  }
});

bool _isOnline(dynamic result) {
  if (result is List<ConnectivityResult>) {
    return result.any((r) => r != ConnectivityResult.none);
  }
  if (result is ConnectivityResult) {
    return result != ConnectivityResult.none;
  }
  return true;
}
