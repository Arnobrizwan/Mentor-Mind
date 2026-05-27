import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import 'package:mentor_minds/application/viewmodels/config/remote_config_providers.dart';
import 'package:mentor_minds/application/viewmodels/profile/profile_viewmodel.dart';
import 'package:mentor_minds/core/constants/app_colors.dart';
import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/routes/app_router.dart';
import 'package:mentor_minds/data/models/profile_stats.dart';
import 'package:mentor_minds/data/models/profile_user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileViewModelProvider);

    ref.listen<ProfileState>(profileViewModelProvider, (prev, next) {
      final err = next.error;
      if (err != null && err != prev?.error) {
        _showSnack(context, err, isError: true);
        ref.read(profileViewModelProvider.notifier).clearError();
      }
    });

    final allSubjects =
        ref.watch(currentCurriculumConfigProvider).subjects;

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: state.isLoading || state.user == null
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
    final user = state.user!;
    return RefreshIndicator(
      color: AppColors.kAccent,
      onRefresh: () =>
          ref.read(profileViewModelProvider.notifier).fetchStats(user.uid),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(user: user)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _StatsRow(stats: state.stats),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child:
                  user.isPremium ? const _PremiumCard() : const _UpgradeCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: _SettingsList(user: user, allSubjects: allSubjects),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Center(
                child: Text(
                  'MentorMinds · v1.0',
                  style: AppTextStyles.bodySmall,
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
// Header
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  final ProfileUser user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploading = ref.watch(
      profileViewModelProvider.select((s) => s.uploadingAvatar),
    );

    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.kPrimary, AppColors.kSplashBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(AppRoutes.dashboard),
            ),
          ),
          Positioned(
            top: 8,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              tooltip: 'Edit profile',
              onPressed: () => _openEditSheet(context, user),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Avatar(user: user, uploading: uploading),
                const SizedBox(height: 10),
                Text(
                  user.name,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _RoleChip(user: user),
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
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.kAccent,
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
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
                      fontSize: 26,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [AppColors.kGold, Color(0xFFE08D0B)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.kGold.withValues(alpha: 0.45),
              blurRadius: 10,
              spreadRadius: 0,
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
            borderRadius: BorderRadius.circular(999),
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
            borderRadius: BorderRadius.circular(999),
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
            borderRadius: BorderRadius.circular(999),
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
// Stats
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final ProfileStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: '📚',
            value: stats.sessionCount.toString(),
            label: 'Sessions',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: '⭐',
            value: stats.points.toString(),
            label: 'Points',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: '🔥',
            value: '${stats.streakDays}d',
            label: 'Streak',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.kPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subscription cards
// ---------------------------------------------------------------------------

class _UpgradeCard extends ConsumerWidget {
  const _UpgradeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const features = [
      'Unlimited AI tutoring',
      'Diagram upload & analysis',
      'Full chat history search',
      'Advanced analytics',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
            'Upgrade to Premium 🚀',
            style: AppTextStyles.headingMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          for (final f in features) ...[
            Row(
              children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 10),
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
              label: const Text('Upgrade Now — ৳299/month'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
              const SizedBox(width: 6),
              Text(
                'Premium Member',
                style:
                    AppTextStyles.headingMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'All features unlocked. Thanks for supporting MentorMinds.',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
          const SizedBox(height: 14),
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
              _SwitchTile(
                icon: Icons.dark_mode_rounded,
                title: 'Dark Mode',
                value: false,
                onChanged: (_) => _showSnack(
                  context,
                  'Dark Mode is coming soon.',
                ),
              ),
              _Tile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English',
                onTap: () =>
                    _showSnack(context, 'More languages coming soon.'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            title: 'Support',
            children: [
              _Tile(
                icon: Icons.help_rounded,
                title: 'Help & FAQ',
                onTap: () => _showSnack(context, 'Help centre coming soon.'),
              ),
              _Tile(
                icon: Icons.policy_rounded,
                title: 'Privacy Policy',
                onTap: () =>
                    _showSnack(context, 'Privacy Policy coming soon.'),
              ),
              _Tile(
                icon: Icons.description_rounded,
                title: 'Terms of Service',
                onTap: () =>
                    _showSnack(context, 'Terms of Service coming soon.'),
              ),
              _Tile(
                icon: Icons.star_rate_rounded,
                title: 'Rate the App',
                onTap: () =>
                    _showSnack(context, 'In-app ratings coming soon.'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            title: 'Danger Zone',
            children: [
              _Tile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                titleColor: AppColors.kError,
                iconColor: AppColors.kError,
                onTap: () => _logOut(context, ref),
              ),
              _Tile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Account',
                titleColor: AppColors.kError,
                iconColor: AppColors.kError,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.kSurface,
            borderRadius: BorderRadius.circular(14),
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
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 56,
                    color: Color(0xFFEDEFF4),
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
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? AppColors.kPrimary),
      title: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: titleColor ?? AppColors.kTextDark,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.kTextMuted,
      ),
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
    return SwitchListTile.adaptive(
      secondary: Icon(icon, color: AppColors.kPrimary),
      title: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(fontSize: 15),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.kAccent,
    );
  }
}

// ---------------------------------------------------------------------------
// Edit-profile bottom sheet — holds name + optional picked avatar, saves both
// in one updateProfile call.
// ---------------------------------------------------------------------------

void _openEditSheet(BuildContext context, ProfileUser user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
    final state = ref.watch(profileViewModelProvider);
    final busy = state.isBusy;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final currentAvatarUrl = widget.user.avatarUrl;

    return Padding(
      padding:
          EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.kTextMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Edit Profile', style: AppTextStyles.headingMedium),
          const SizedBox(height: 18),

          // Avatar preview
          Center(
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.kAccent,
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
                          color: AppColors.kError,
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameCtrl,
            enabled: !busy,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Changes'),
            ),
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
    backgroundColor: AppColors.kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
    final busy =
        ref.watch(profileViewModelProvider.select((s) => s.isEditing));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.kTextMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('My Subjects', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          const Text(
            'Pick what you study. We tailor materials and tutor answers to this.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                  selectedColor: AppColors.kAccent.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.kAccent,
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save'),
            ),
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
    backgroundColor: AppColors.kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.kTextMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('My Level', style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          for (final l in const ['O Level', 'A Level'])
            ListTile(
              onTap: () => _pick(context, ref, l),
              leading: Icon(
                initial == l
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color:
                    initial == l ? AppColors.kAccent : AppColors.kTextMuted,
              ),
              title: Text(l, style: AppTextStyles.labelLarge),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change-password dialog (current + new)
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
    final busy =
        ref.watch(profileViewModelProvider.select((s) => s.isEditing));
    return AlertDialog(
      title: const Text('Change Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: _obscureCurrent,
            enabled: !busy,
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
          const SizedBox(height: 10),
          TextField(
            controller: _newCtrl,
            obscureText: _obscureNew,
            enabled: !busy,
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
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
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
    builder: (_) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again to continue.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.kError),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Log out'),
        ),
      ],
    ),
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
  final err = await ref.read(profileViewModelProvider.notifier).deleteAccount();
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
    final busy =
        ref.watch(profileViewModelProvider.select((s) => s.isEditing));
    return AlertDialog(
      title: const Text('Delete Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This permanently deletes your profile, sessions, and rewards. '
            'This cannot be undone.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Type $_phrase to confirm:',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            enabled: !busy,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.kError),
          onPressed: (busy || !_canDelete)
              ? null
              : () => Navigator.of(context).pop(true),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Snack helper
// ---------------------------------------------------------------------------

void _showSnack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.kError : AppColors.kPrimary,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

// ---------------------------------------------------------------------------
// Shimmer loading
// ---------------------------------------------------------------------------

class _ProfileShimmer extends StatelessWidget {
  const _ProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E9F2),
      highlightColor: const Color(0xFFF7F9FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 220, color: const Color(0xFFE6E9F2)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 86,
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.kSurface,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.kSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
