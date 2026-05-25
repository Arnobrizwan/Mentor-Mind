import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:mentor_minds/application/viewmodels/auth/auth_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/data/repositories/auth_repository.dart';

/// AUTH-03 — reminder banner until email is verified.
class EmailVerificationBanner extends ConsumerWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateUserProvider).valueOrNull;
    if (user == null || user.emailVerified) return const SizedBox.shrink();
    if (!_usesEmailPassword(user)) return const SizedBox.shrink();

    return Material(
      color: AppColors.kGold.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Verify your email to use MentorBot and save sessions.',
                style: AppTextStyles.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(authViewModelProvider.notifier)
                    .resendEmailVerification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification email sent')),
                  );
                }
              },
              child: const Text('Resend'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _usesEmailPassword(User user) {
  return user.providerData.any((p) => p.providerId == 'password');
}

final authStateUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
