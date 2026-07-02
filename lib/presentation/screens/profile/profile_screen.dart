import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mentor_minds/data/models/support_config.dart';
import 'package:mentor_minds/application/viewmodels/profile/profile_viewmodel.dart';
import 'package:mentor_minds/application/viewmodels/settings/theme_mode_provider.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/core/theme/app_radius.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';
import 'package:mentor_minds/data/models/profile_stats.dart';
import 'package:mentor_minds/data/models/profile_user.dart';
import 'package:mentor_minds/shared/widgets/empty_state.dart';
import 'package:mentor_minds/shared/widgets/pill_button.dart';
import 'package:mentor_minds/shared/widgets/skeleton_block.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final state = ref.watch(profileViewModelProvider);

    ref.listen<ProfileState>(profileViewModelProvider, (prev, next) {
      final err = next.error;
      // With no profile loaded the inline error view owns the error (a
      // snackbar+clear here would flip the screen back to the shimmer).
      if (err != null && err != prev?.error && next.user != null) {
        _showSnack(context, err, isError: true);
        ref.read(profileViewModelProvider.notifier).clearError();
      }
    });

    final allSubjects = ref.watch(currentCurriculumConfigProvider).subjects;

    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        // A stream error before the first user emission would otherwise leave
        // the shimmer up forever — surface it with a retry instead.
        child: state.user == null && !state.isLoading && state.error != null
            ? Center(
                child: EmptyState(
                  variant: EmptyStateVariant.error,
                  title: "Couldn't load your profile",
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.read(profileViewModelProvider.notifier).retryLoad(),
                ),
              )
            : state.isLoading || state.user == null
                ? const _ProfileShimmer()
                : _ProfileBody(state: state, allSubjects: allSubjects),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ProfileBody extends ConsumerWidget {
  final ProfileState state;
  final List<String> allSubjects;
  const _ProfileBody({required this.state, required this.allSubjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final user = state.user!;
    return RefreshIndicator(
      color: brand.accent,
      onRefresh: () =>
          ref.read(profileViewModelProvider.notifier).fetchStats(user.uid),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(user: user)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
              ),
              child: _StatsRow(stats: state.stats),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm,
              ),
              child:
                  user.isPremium ? const _PremiumCard() : const _UpgradeCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: _SettingsList(user: user, allSubjects: allSubjects),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xxl,
              ),
              child: Center(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    final info = snap.data;
                    final label = info == null
                        ? 'MentorMinds'
                        : 'MentorMinds · v${info.version} (${info.buildNumber})';
                    return Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: brand.textMuted,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — always-indigo brand hero (both themes).
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  final ProfileUser user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploading = ref.watch(
      profileViewModelProvider.select((s) => s.uploadingAvatar),
    );

    // Header sizes to its content rather than locking to a fixed pixel height.
    // Three layers: gradient → background illustration (low opacity, decorative)
    // → SafeArea-wrapped content. SafeArea pushes content below the system
    // status bar; the Stack hosts the absolutely-positioned back/edit buttons
    // and sizes to the inner Column.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kPrimary, AppColors.kSplashBottom],
        ),
      ),
      child: Stack(
        children: [
          // Decorative background illustration — low-opacity hero image
          // bleeds in from the right behind the content. Purely aesthetic;
          // semantic content is unchanged.
          //
          // Opacity is intentionally low (0.10) and the multiply blend tints
          // the image with the indigo primary so the PNG's off-white
          // background doesn't wash out the dark header.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 0.10,
                child: Image.asset(
                  'assets/images/illustrations/onboarding_hero.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                  color: AppColors.kPrimary,
                  colorBlendMode: BlendMode.multiply,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.xs,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    tooltip: 'Back',
                    onPressed: () async {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      final route = await resolveHomeRouteName(ref);
                      if (context.mounted) context.goNamed(route);
                    },
                  ),
                ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.xs,
              child: IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                tooltip: 'Edit profile',
                onPressed: () => _openEditSheet(context, user),
              ),
            ),
            // SizedBox.expand makes the Padding+Column fill the Stack's width
            // (Stack would otherwise give it loose constraints and the Column
            // would shrink to intrinsic width + left-align). Now the Column's
            // crossAxisAlignment defaults to center and the avatar/name/email
            // sit in the middle of the header.
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(user: user, uploading: uploading),
                    const SizedBox(height: AppSpacing.sm + 2),
                    Text(
                      user.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    _RoleChip(user: user),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final ProfileUser user;
  final bool uploading;
  const _Avatar({required this.user, required this.uploading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.kAccent,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7), width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
              image: user.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(user.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: user.avatarUrl == null
                ? Text(
                    user.initials,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: uploading ? null : () => _openEditSheet(context, user),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.kGold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: uploading
                    ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final ProfileUser user;
  const _RoleChip({required this.user});

  @override
  Widget build(BuildContext context) {
    final (label, decoration, textColor, icon) = _chipVariant(user);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2,
      ),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: textColor, fontSize: 12, fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (String, BoxDecoration, Color, IconData?) _chipVariant(ProfileUser u) {
    if (u.isPremium) {
      return (
        'Premium',
        BoxDecoration(
          borderRadius: AppRadius.pillBorder,
          gradient: const LinearGradient(
            colors: [AppColors.kGold, Color(0xFFE08D0B)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.kGold.withValues(alpha: 0.45),
              blurRadius: 10,
            ),
          ],
        ),
        Colors.white,
        Icons.star_rounded,
      );
    }
    switch (u.role) {
      case 'teacher':
        return (
          'Teacher',
          BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          Colors.white,
          Icons.school_rounded,
        );
      case 'admin':
        return (
          'Admin',
          BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          Colors.white,
          Icons.shield_rounded,
        );
      default:
        return (
          'Student',
          BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          Colors.white,
          null,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Stats — 3 numeric tiles
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final ProfileStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: '📚',
            value: stats.sessionCount.toString(),
            label: 'Sessions',
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: _StatTile(
            icon: '⭐',
            value: stats.points.toString(),
            label: 'Points',
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: _StatTile(
            icon: '🔥',
            value: '${stats.streakDays}d',
            label: 'Streak',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md + 2, horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: brand.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subscription cards — teal upgrade + gold premium (brand identity moments).
// ---------------------------------------------------------------------------

class _UpgradeCard extends ConsumerWidget {
  const _UpgradeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(currentSubscriptionConfigProvider);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlBorder,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kAccent, Color(0xFF007A64)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.kAccent.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub.headline,
            style: AppTextStyles.headingMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final f in sub.features) ...[
            Row(
              children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    f,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          const SizedBox(height: AppSpacing.sm + 2),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ref
                    .read(profileViewModelProvider.notifier)
                    .startPremiumCheckout();
                await ref
                    .read(profileViewModelProvider.notifier)
                    .refreshAuthToken();
              },
              icon: const Icon(Icons.bolt_rounded, color: AppColors.kGold),
              label: Text(sub.ctaLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.kPrimary,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdBorder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends ConsumerWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlBorder,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kGold, Color(0xFFE08D0B)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.kGold.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 22),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                'Premium Member',
                style: AppTextStyles.headingMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'All features unlocked. Thanks for supporting MentorMinds.',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await ref
                    .read(profileViewModelProvider.notifier)
                    .openSubscriptionPortal();
                await ref
                    .read(profileViewModelProvider.notifier)
                    .refreshAuthToken();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.4),
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdBorder,
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              child: const Text('Manage Subscription'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings list
// ---------------------------------------------------------------------------

class _SettingsList extends ConsumerWidget {
  final ProfileUser user;
  final List<String> allSubjects;
  const _SettingsList({required this.user, required this.allSubjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md + 2, AppSpacing.lg, 0,
      ),
      child: Column(
        children: [
          _Group(
            title: 'Account',
            children: [
              _Tile(
                icon: Icons.person_rounded,
                title: 'Edit Profile',
                subtitle: 'Name, avatar',
                onTap: () => _openEditSheet(context, user),
              ),
              _Tile(
                icon: Icons.lock_rounded,
                title: 'Change Password',
                onTap: () => _openChangePasswordDialog(context, ref),
              ),
              _Tile(
                icon: Icons.menu_book_rounded,
                title: 'My Subjects',
                subtitle: user.subjects.isEmpty
                    ? 'None selected'
                    : user.subjects.join(' · '),
                onTap: () =>
                    _openSubjectsSheet(context, user, allSubjects),
              ),
              _Tile(
                icon: Icons.school_rounded,
                title: 'My Level',
                subtitle: user.level.isEmpty ? 'Not set' : user.level,
                onTap: () => _openLevelSheet(context, user),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          _Group(
            title: 'Preferences',
            children: [
              _SwitchTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                value: user.notificationsEnabled,
                onChanged: (v) => ref
                    .read(profileViewModelProvider.notifier)
                    .toggleNotifications(v),
              ),
              _ThemeModeTile(),
              _Tile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: _deviceLocaleLabel(context),
                onTap: () =>
                    _showSnack(context, 'More languages coming soon.'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Consumer(builder: (context, ref, _) {
            final support = ref.watch(currentSupportConfigProvider);
            return _Group(
              title: 'Support',
              children: [
                _Tile(
                  icon: Icons.help_rounded,
                  title: 'Help & FAQ',
                  onTap: () => context.goNamed(AppRoutes.helpFaq),
                ),
                _Tile(
                  icon: Icons.policy_rounded,
                  title: 'Privacy Policy',
                  onTap: () => context.goNamed(AppRoutes.privacy),
                ),
                _Tile(
                  icon: Icons.description_rounded,
                  title: 'Terms of Service',
                  onTap: () => context.goNamed(AppRoutes.terms),
                ),
                _Tile(
                  icon: Icons.star_rate_rounded,
                  title: 'Rate the App',
                  onTap: () => _launchStoreRating(context, support),
                ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.md + 2),
          _Group(
            title: 'Danger Zone',
            children: [
              _Tile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                titleColor: brand.error,
                iconColor: brand.error,
                onTap: () => _logOut(context, ref),
              ),
              _Tile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Account',
                titleColor: brand.error,
                iconColor: brand.error,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, 0, 0, AppSpacing.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: brand.textMuted, letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: brand.surface,
            borderRadius: AppRadius.lgBorder,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1, thickness: 1, indent: 56, color: brand.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? brand.primary),
      title: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: titleColor ?? brand.textDark, fontSize: 15,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Icon(Icons.chevron_right_rounded, color: brand.textMuted),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SwitchListTile.adaptive(
      secondary: Icon(icon, color: brand.primary),
      title: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: brand.textDark, fontSize: 15,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: brand.accent,
    );
  }
}

// ---------------------------------------------------------------------------
// Edit-profile bottom sheet
// ---------------------------------------------------------------------------

void _openEditSheet(BuildContext context, ProfileUser user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.brand.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.xxlRadius),
    ),
    builder: (_) => _EditProfileSheet(user: user),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final ProfileUser user;
  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  XFile? _pickedAvatar;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _pickedAvatar = file);
    } catch (e) {
      if (mounted) _showSnack(context, 'Could not pick image: $e', isError: true);
    }
  }

  Future<void> _save() async {
    final ok = await ref.read(profileViewModelProvider.notifier).updateProfile(
          name: _nameCtrl.text,
          avatarFile: _pickedAvatar,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      _showSnack(context, 'Profile updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final state = ref.watch(profileViewModelProvider);
    final busy = state.isBusy;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final currentAvatarUrl = widget.user.avatarUrl;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + inset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: brand.textMuted.withValues(alpha: 0.3),
                borderRadius: AppRadius.xsBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          Text(
            'Edit Profile',
            style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.lg + 2),

          // Avatar preview
          Center(
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brand.accent,
                    image: _pickedAvatar != null
                        ? DecorationImage(
                            image: FileImage(File(_pickedAvatar!.path)),
                            fit: BoxFit.cover,
                          )
                        : (currentAvatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(currentAvatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null),
                  ),
                  alignment: Alignment.center,
                  child: (_pickedAvatar == null && currentAvatarUrl == null)
                      ? Text(
                          widget.user.initials,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 30,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (_pickedAvatar != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: GestureDetector(
                      onTap: busy
                          ? null
                          : () => setState(() => _pickedAvatar = null),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: brand.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Gallery',
                  icon: Icons.photo_library_rounded,
                  variant: PillVariant.secondary,
                  dense: true,
                  onPressed:
                      busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: PillButton(
                  label: 'Camera',
                  icon: Icons.camera_alt_rounded,
                  variant: PillVariant.secondary,
                  dense: true,
                  onPressed:
                      busy ? null : () => _pick(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          TextField(
            controller: _nameCtrl,
            enabled: !busy,
            textCapitalization: TextCapitalization.words,
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: AppRadius.mdBorder),
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          PillButton(
            label: 'Save Changes',
            onPressed: busy ? null : _save,
            loading: busy,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subjects sheet
// ---------------------------------------------------------------------------

void _openSubjectsSheet(
  BuildContext context,
  ProfileUser user,
  List<String> allSubjects,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.brand.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.xxlRadius),
    ),
    builder: (_) =>
        _SubjectsSheet(initial: user.subjects, allSubjects: allSubjects),
  );
}

class _SubjectsSheet extends ConsumerStatefulWidget {
  final List<String> initial;
  final List<String> allSubjects;
  const _SubjectsSheet({required this.initial, required this.allSubjects});

  @override
  ConsumerState<_SubjectsSheet> createState() => _SubjectsSheetState();
}

class _SubjectsSheetState extends ConsumerState<_SubjectsSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final busy =
        ref.watch(profileViewModelProvider.select((s) => s.isEditing));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl - 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: brand.textMuted.withValues(alpha: 0.3),
                borderRadius: AppRadius.xsBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'My Subjects',
            style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pick what you study. We tailor materials and tutor answers to this.',
            style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in widget.allSubjects)
                FilterChip(
                  label: Text(s),
                  selected: _selected.contains(s),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selected.add(s);
                    } else {
                      _selected.remove(s);
                    }
                  }),
                  selectedColor: brand.accent.withValues(alpha: 0.18),
                  checkmarkColor: brand.accent,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          PillButton(
            label: 'Save',
            onPressed: busy
                ? null
                : () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref
                        .read(profileViewModelProvider.notifier)
                        .updateSubjects(_selected.toList()..sort());
                    if (!mounted) return;
                    if (ok) {
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Subjects updated')),
                      );
                    }
                  },
            loading: busy,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level sheet
// ---------------------------------------------------------------------------

void _openLevelSheet(BuildContext context, ProfileUser user) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.brand.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.xxlRadius),
    ),
    builder: (_) => _LevelSheet(initial: user.level),
  );
}

class _LevelSheet extends ConsumerWidget {
  final String initial;
  const _LevelSheet({required this.initial});

  Future<void> _pick(BuildContext context, WidgetRef ref, String value) async {
    final ok =
        await ref.read(profileViewModelProvider.notifier).updateLevel(value);
    if (context.mounted && ok) {
      Navigator.of(context).pop();
      _showSnack(context, 'Level updated to $value');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl - 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: brand.textMuted.withValues(alpha: 0.3),
                borderRadius: AppRadius.xsBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'My Level',
            style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final l in ref.watch(currentCurriculumConfigProvider).levels)
            ListTile(
              onTap: () => _pick(context, ref, l),
              leading: Icon(
                initial == l
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: initial == l ? brand.accent : brand.textMuted,
              ),
              title: Text(
                l,
                style: AppTextStyles.labelLarge.copyWith(color: brand.textDark),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change-password dialog
// ---------------------------------------------------------------------------

Future<void> _openChangePasswordDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState
    extends ConsumerState<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final err = await ref
        .read(profileViewModelProvider.notifier)
        .changePassword(
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
        );
    if (!mounted) return;
    if (err != null) {
      _showSnack(context, err, isError: true);
    } else {
      Navigator.of(context).pop();
      _showSnack(context, 'Password updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final busy =
        ref.watch(profileViewModelProvider.select((s) => s.isEditing));
    return AlertDialog(
      backgroundColor: brand.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      title: Text(
        'Change Password',
        style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: _obscureCurrent,
            enabled: !busy,
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
            decoration: InputDecoration(
              labelText: 'Current password',
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          TextField(
            controller: _newCtrl,
            obscureText: _obscureNew,
            enabled: !busy,
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
            decoration: InputDecoration(
              labelText: 'New password (min 8 chars)',
              suffixIcon: IconButton(
                icon: Icon(_obscureNew
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
      ),
      actions: [
        PillButton(
          label: 'Cancel',
          variant: PillVariant.ghost,
          fullWidth: false,
          dense: true,
          onPressed: busy ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppSpacing.sm),
        PillButton(
          label: 'Update',
          fullWidth: false,
          dense: true,
          onPressed: busy ? null : _submit,
          loading: busy,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Log out
// ---------------------------------------------------------------------------

Future<void> _logOut(BuildContext context, WidgetRef ref) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final brand = ctx.brand;
      return AlertDialog(
        backgroundColor: brand.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        title: Text(
          'Log out?',
          style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
        ),
        content: Text(
          'You will need to sign in again to continue.',
          style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
        ),
        actions: [
          PillButton(
            label: 'Cancel',
            variant: PillVariant.ghost,
            fullWidth: false,
            dense: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(width: AppSpacing.sm),
          _DangerButton(
            label: 'Log out',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );
  if (confirm != true) return;
  await ref.read(profileViewModelProvider.notifier).logout();
  if (context.mounted) context.goNamed(AppRoutes.login);
}

// ---------------------------------------------------------------------------
// Delete account — typed-confirmation dialog
// ---------------------------------------------------------------------------

Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (confirmed != true) return;
  final err =
      await ref.read(profileViewModelProvider.notifier).deleteAccount();
  if (!context.mounted) return;
  if (err != null) {
    _showSnack(context, err, isError: true);
  } else {
    context.goNamed(AppRoutes.onboarding);
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState
    extends ConsumerState<_DeleteAccountDialog> {
  static const _phrase = 'DELETE';
  final _ctrl = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text.trim() == _phrase;
      if (ok != _canDelete) setState(() => _canDelete = ok);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final busy =
        ref.watch(profileViewModelProvider.select((s) => s.isEditing));
    return AlertDialog(
      backgroundColor: brand.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      title: Text(
        'Delete Account',
        style: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This permanently deletes your profile, sessions, and rewards. '
            'This cannot be undone.',
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Type $_phrase to confirm:',
            style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          TextField(
            controller: _ctrl,
            enabled: !busy,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: AppTextStyles.bodyMedium.copyWith(color: brand.textDark),
            decoration: const InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
      ),
      actions: [
        PillButton(
          label: 'Cancel',
          variant: PillVariant.ghost,
          fullWidth: false,
          dense: true,
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: AppSpacing.sm),
        _DangerButton(
          label: 'Delete',
          loading: busy,
          onPressed: (busy || !_canDelete)
              ? null
              : () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Red destructive CTA shaped like PillButton primary. Kept separate from
/// PillButton so the danger color stays semantic (brand.error) regardless
/// of mode and doesn't get confused with the standard primary.
class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const _DangerButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: brand.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: brand.error.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          minimumSize: Size.zero,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillBorder,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme mode tile — System / Light / Dark picker. Opens a small modal sheet
// (consistent with the Level and Subjects sheets) so the choice persists
// to SharedPreferences via the themeModeProvider.
// ---------------------------------------------------------------------------

class _ThemeModeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final mode = ref.watch(themeModeProvider);
    return ListTile(
      onTap: () => _openThemeModeSheet(context, ref, mode),
      leading: Icon(Icons.dark_mode_rounded, color: brand.primary),
      title: Text(
        'Theme',
        style: AppTextStyles.labelLarge.copyWith(
          color: brand.textDark, fontSize: 15,
        ),
      ),
      subtitle: Text(
        themeModeLabel(mode),
        style: AppTextStyles.bodySmall.copyWith(color: brand.textMuted),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: brand.textMuted),
    );
  }
}

void _openThemeModeSheet(
  BuildContext context,
  WidgetRef ref,
  ThemeMode current,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.brand.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.xxlRadius),
    ),
    builder: (sheetCtx) {
      final brand = sheetCtx.brand;
      Future<void> pick(ThemeMode m) async {
        await ref.read(themeModeProvider.notifier).setMode(m);
        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      }

      Widget option(ThemeMode m, IconData icon) {
        final selected = m == current;
        return ListTile(
          onTap: () => pick(m),
          leading: Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? brand.accent : brand.textMuted,
          ),
          title: Text(
            themeModeLabel(m),
            style: AppTextStyles.labelLarge.copyWith(color: brand.textDark),
          ),
          trailing: Icon(icon, color: brand.textMuted),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl - 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: brand.textMuted.withValues(alpha: 0.3),
                    borderRadius: AppRadius.xsBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Theme',
                style:
                    AppTextStyles.headingMedium.copyWith(color: brand.textDark),
              ),
              const SizedBox(height: AppSpacing.sm),
              option(ThemeMode.system, Icons.settings_suggest_rounded),
              option(ThemeMode.light, Icons.light_mode_rounded),
              option(ThemeMode.dark, Icons.dark_mode_rounded),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Snack helper
// ---------------------------------------------------------------------------

void _showSnack(BuildContext context, String msg, {bool isError = false}) {
  final brand = context.brand;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        msg,
        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
      ),
      backgroundColor: isError ? brand.error : brand.primary,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

// ---------------------------------------------------------------------------
// SUPPORT section launchers
// ---------------------------------------------------------------------------
//
// Each helper falls back to a snackbar when the config field is empty OR the
// platform refuses to handle the URI (no mail app, no Play Store, etc.). The
// snack copy stays close to the original "coming soon" tone so users still
// see a coherent UX before pricing/legal pages are live.

/// Returns a human-readable label for the current device locale — used as the
/// `Language` tile subtitle so it reflects reality instead of hardcoded copy.
String _deviceLocaleLabel(BuildContext context) {
  final locale = Localizations.maybeLocaleOf(context);
  if (locale == null) return 'English';
  final lang = locale.languageCode;
  final country = locale.countryCode;
  final base = switch (lang) {
        'en' => 'English',
        'bn' => 'বাংলা',
        'hi' => 'हिन्दी',
        'ur' => 'اردو',
        _ => lang.toUpperCase(),
      };
  return country == null || country.isEmpty
      ? base
      : '$base · $country';
}

Future<void> _launchStoreRating(
  BuildContext context,
  SupportConfig support,
) async {
  final isIos = Platform.isIOS;
  final id = isIos ? support.appStoreId : support.playStorePackageName;
  if (id.isEmpty) {
    _showSnack(context, 'In-app ratings coming soon.');
    return;
  }
  // Try the platform-native deep link first, fall back to the web URL so
  // emulators (which often lack a real Play Store) still resolve gracefully.
  final deepLink = Uri.parse(
    isIos
        ? 'itms-apps://itunes.apple.com/app/id$id'
        : 'market://details?id=$id',
  );
  final webLink = Uri.parse(
    isIos
        ? 'https://apps.apple.com/app/id$id'
        : 'https://play.google.com/store/apps/details?id=$id',
  );
  final deepLaunched =
      await launchUrl(deepLink, mode: LaunchMode.externalApplication);
  if (deepLaunched) return;
  final webLaunched =
      await launchUrl(webLink, mode: LaunchMode.externalApplication);
  if (!webLaunched && context.mounted) {
    _showSnack(context, "Couldn't open the store.", isError: true);
  }
}

// ---------------------------------------------------------------------------
// Shimmer loading
// ---------------------------------------------------------------------------

class _ProfileShimmer extends StatelessWidget {
  const _ProfileShimmer();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SkeletonGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 220, color: brand.border),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Container(
                      height: 86,
                      decoration: BoxDecoration(
                        color: brand.surface,
                        borderRadius: AppRadius.lgBorder,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: brand.surface,
                borderRadius: AppRadius.xlBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md + 2,
              ),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: brand.surface,
                  borderRadius: AppRadius.lgBorder,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
