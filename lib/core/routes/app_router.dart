import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mentor_minds/core/observability/analytics_service.dart';
import 'package:mentor_minds/data/services/firebase_providers.dart';

import 'package:mentor_minds/presentation/screens/auth/login_screen.dart';
import 'package:mentor_minds/presentation/screens/auth/register_screen.dart';
import 'package:mentor_minds/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:mentor_minds/presentation/screens/materials/materials_screen.dart';
import 'package:mentor_minds/presentation/screens/notifications/notifications_screen.dart';
import 'package:mentor_minds/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:mentor_minds/presentation/screens/profile/profile_screen.dart';
import 'package:mentor_minds/presentation/screens/profile/teacher_profile_screen.dart';
import 'package:mentor_minds/presentation/screens/rewards/rewards_screen.dart';
import 'package:mentor_minds/presentation/screens/search/search_screen.dart';
import 'package:mentor_minds/presentation/screens/splash/splash_screen.dart';
import 'package:mentor_minds/presentation/screens/admin/admin_screen.dart';
import 'package:mentor_minds/presentation/screens/dashboard/teacher_dashboard_screen.dart';
import 'package:mentor_minds/presentation/screens/inbox/teacher_inbox_screen.dart';
import 'package:mentor_minds/presentation/screens/legal/legal_screen.dart';
import 'package:mentor_minds/presentation/screens/tutor/tutor_screen.dart';

/// Returns the right "home" route name for the currently signed-in user.
///
/// Resolution order:
///   1. ID token claim `role` — fast, no Firestore round-trip
///   2. Firestore `/users/{uid}.role` — source of truth; used when the claim
///      is missing or returns the default 'student' (seed accounts and any
///      user who pre-dates the role-claim cloud function fall here)
///   3. `AppRoutes.dashboard` (student) as final fallback
///
/// Used by shared-screen back buttons AND by the router-level redirect guard
/// in this file, so a teacher / admin can never end up on the student
/// dashboard regardless of which sign-up path they came through.
Future<String> resolveHomeRouteName(WidgetRef ref) async {
  final auth = ref.read(firebaseAuthProvider);
  final user = auth.currentUser;
  if (user == null) return AppRoutes.dashboard;

  // 1. Fast path — claim on the cached ID token.
  try {
    final token = await user.getIdTokenResult();
    final role = token.claims?['role'] as String?;
    if (role == 'teacher') return AppRoutes.teacherDashboard;
    if (role == 'admin') return AppRoutes.admin;
    // Note: we deliberately DO NOT return early on role == 'student'. The
    // default claim set by the on-user-create function is 'student', and
    // seeded accounts may never have had their claim upgraded — we need to
    // check Firestore to be sure.
  } catch (_) {}

  // 2. Source-of-truth fallback — /users/{uid}.role
  try {
    final firestore = ref.read(firestoreProvider);
    final doc = await firestore.collection('users').doc(user.uid).get();
    final role = (doc.data()?['role'] as String?)?.trim();
    if (role == 'teacher') return AppRoutes.teacherDashboard;
    if (role == 'admin') return AppRoutes.admin;
  } catch (_) {}

  return AppRoutes.dashboard;
}

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
  static const teacherProfile = 'teacherProfile';
  static const teacherInbox   = 'teacherInbox';
  static const rewards     = 'rewards';
  static const notifications = 'notifications';
  static const admin       = 'admin';
  static const helpFaq     = 'helpFaq';
  static const privacy     = 'privacy';
  static const terms       = 'terms';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final analytics = ref.read(analyticsServiceProvider);
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    observers: [analytics.screenObserver],
    // Bulletproof guard: any teacher/admin that lands on /dashboard (e.g. via
    // a stale back-stack, deep link, or a screen that hasn't been updated to
    // the role-aware helper) is rewritten to their own home. No matter what
    // any individual screen does, a teacher cannot end up on the student
    // dashboard.
    redirect: (context, state) async {
      if (state.matchedLocation != '/dashboard') return null;
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) return null; // splash will handle unauthenticated state

      // Same dual lookup as resolveHomeRouteName — claim first, then
      // Firestore. Seeded teacher / admin accounts may not have the role
      // claim set, so we MUST fall back to /users/{uid}.role to catch them.
      try {
        final token = await user.getIdTokenResult();
        final role = token.claims?['role'] as String?;
        if (role == 'teacher') return '/dashboard/teacher';
        if (role == 'admin') return '/admin';
      } catch (_) {}

      try {
        final fs = ref.read(firestoreProvider);
        final doc = await fs.collection('users').doc(user.uid).get();
        final role = (doc.data()?['role'] as String?)?.trim();
        if (role == 'teacher') return '/dashboard/teacher';
        if (role == 'admin') return '/admin';
      } catch (_) {}

      return null;
    },
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
        builder: (_, __) => const TeacherDashboardScreen(),
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
        path: '/profile/teacher',
        name: AppRoutes.teacherProfile,
        builder: (_, __) => const TeacherProfileScreen(),
      ),
      GoRoute(
        path: '/inbox/teacher',
        name: AppRoutes.teacherInbox,
        builder: (_, __) => const TeacherInboxScreen(),
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
      GoRoute(
        path: '/help',
        name: AppRoutes.helpFaq,
        builder: (_, __) => const LegalScreen(doc: LegalDoc.helpFaq),
      ),
      GoRoute(
        path: '/privacy',
        name: AppRoutes.privacy,
        builder: (_, __) => const LegalScreen(doc: LegalDoc.privacy),
      ),
      GoRoute(
        path: '/terms',
        name: AppRoutes.terms,
        builder: (_, __) => const LegalScreen(doc: LegalDoc.terms),
      ),
    ],
  );
});
