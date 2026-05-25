import 'package:flutter/material.dart';

import 'package:mentor_minds/shared/widgets/badge_celebration_overlay.dart';
import 'package:mentor_minds/shared/widgets/email_verification_banner.dart';
import 'package:mentor_minds/shared/widgets/offline_banner.dart';

/// App-wide shell: offline banner + email verification + badge overlay.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return BadgeCelebrationHost(
      child: Column(
        children: [
          const OfflineBanner(),
          const EmailVerificationBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
