import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/page_transitions.dart';
import '../../core/widgets/not_found_screen.dart';
import '../../features/onboarding/screens/landing_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';
import '../../features/onboarding/screens/welcome_screen.dart';
import '../../features/authentication/screens/signup_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/character/screens/character_selection_screen.dart';
import '../../features/town/screens/town_loading_screen.dart';
import '../../features/town/screens/town_screen.dart';
import '../../features/lessons/screens/battle_loading_screen.dart';
import '../../features/lessons/screens/lesson_runner_screen.dart';
import '../../features/progression/screens/level_up_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../shell/main_shell_screen.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const String landing = '/';
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String signup = '/signup';
  static const String login = '/login';
  static const String characterSelect = '/character-select';
  static const String townLoading = '/town-loading';
  static const String town = '/town';
  static const String battleLoading = '/battle-loading';
  static const String lessonRunner = '/lesson/runner';
  static const String levelUp = '/level-up';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.landing,
  errorBuilder: (context, state) => NotFoundScreen(uri: state.uri.toString()),
  routes: [
    // ─── Onboarding & Entry Flow ──────────────────────
    GoRoute(
      path: AppRoutes.landing,
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: AppRoutes.splash,
      pageBuilder: (context, state) => fadeTransitionPage(
        context: context,
        state: state,
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      pageBuilder: (context, state) => fadeTransitionPage(
        context: context,
        state: state,
        child: const WelcomeScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.signup,
      pageBuilder: (context, state) => slideFadeTransitionPage(
        context: context,
        state: state,
        child: const SignupScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (context, state) => slideFadeTransitionPage(
        context: context,
        state: state,
        child: const LoginScreen(),
      ),
    ),

    // ─── Character Selection (Onboarding + Profile Edit) ──
    GoRoute(
      path: AppRoutes.characterSelect,
      pageBuilder: (context, state) {
        final isEditing = state.uri.queryParameters['mode'] == 'edit';
        return slideFadeTransitionPage(
          context: context,
          state: state,
          child: CharacterSelectionScreen(isEditing: isEditing),
        );
      },
    ),


    // ─── Town Loading Transition ──────────────────────
    GoRoute(
      path: AppRoutes.townLoading,
      pageBuilder: (context, state) => fadeTransitionPage(
        context: context,
        state: state,
        child: const TownLoadingScreen(),
      ),
    ),

    // ─── Main Application Persistent Shell (Town / Leaderboard / Profile) ─
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.town,
              builder: (context, state) => const TownScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.leaderboard,
              builder: (context, state) => const LeaderboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // ─── Lesson & Battle Flow (Pushed over root navigator) ──
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.battleLoading,
      pageBuilder: (context, state) => battleEntranceTransitionPage(
        context: context,
        state: state,
        child: const BattleLoadingScreen(),
      ),
    ),
    // ─── Unified lesson runner (replaces 4 separate exercise screens) ──
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.lessonRunner,
      pageBuilder: (context, state) => fadeTransitionPage(
        context: context,
        state: state,
        child: const LessonRunnerScreen(),
      ),
    ),
    // ─── Level Up Celebration Screen ──────────────────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.levelUp,
      pageBuilder: (context, state) => celebrationTransitionPage(
        context: context,
        state: state,
        child: const LevelUpScreen(),
      ),
    ),
  ],
);
