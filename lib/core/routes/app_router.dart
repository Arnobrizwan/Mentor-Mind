import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mentor_minds/core/observability/analytics_service.dart';

import 'package:mentor_minds/presentation/screens/auth/login_screen.dart';
import 'package:mentor_minds/presentation/screens/auth/register_screen.dart';
import 'package:mentor_minds/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:mentor_minds/presentation/screens/materials/materials_screen.dart';
import 'package:mentor_minds/presentation/screens/notifications/notifications_screen.dart';
import 'package:mentor_minds/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:mentor_minds/presentation/screens/profile/profile_screen.dart';
import 'package:mentor_minds/presentation/screens/rewards/rewards_screen.dart';
import 'package:mentor_minds/presentation/screens/search/search_screen.dart';
import 'package:mentor_minds/presentation/screens/splash/splash_screen.dart';
import 'package:mentor_minds/presentation/screens/admin/admin_screen.dart';
import 'package:mentor_minds/presentation/screens/tutor/tutor_screen.dart';

// Route name constants — always navigate by name, never by path string.
abstract final class AppRoutes {
  static const splash      = 'splash';
  static const onboarding  = 'onboarding';
  static const login       = 'login';
  static const register    = 'register';
  static const dashboard          = 'dashboard';
  static const teacherDashboard   = 'teacherDashboard';
  static const tutor       = 'tutor';
  static const materials   = 'materials';
  static const search      = 'search';
  static const profile     = 'profile';
  static const rewards     = 'rewards';
  static const notifications = 'notifications';
  static const admin       = 'admin';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final analytics = ref.read(analyticsServiceProvider);
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    observers: [analytics.screenObserver],
    routes: [
      GoRoute(
        path: '/',
        name: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        name: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: AppRoutes.dashboard,
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/teacher',
        name: AppRoutes.teacherDashboard,
        builder: (_, __) => const _PlaceholderScreen(label: 'Teacher Dashboard'),
      ),
      GoRoute(
        path: '/tutor',
        name: AppRoutes.tutor,
        builder: (_, __) => const TutorScreen(),
      ),
      GoRoute(
        path: '/materials',
        name: AppRoutes.materials,
        builder: (_, __) => const MaterialsScreen(),
      ),
      GoRoute(
        path: '/search',
        name: AppRoutes.search,
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/rewards',
        name: AppRoutes.rewards,
        builder: (_, __) => const RewardsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: AppRoutes.admin,
        builder: (_, __) => const AdminScreen(),
      ),
    ],
  );
});

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          label,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 18),
        ),
      ),
    );
  }
}
