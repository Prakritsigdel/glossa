import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/screens/landing_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';
import '../../features/onboarding/screens/welcome_screen.dart';
import '../../features/authentication/screens/signup_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/character/screens/character_selection_screen.dart';
import '../../features/languages/screens/language_selection_screen.dart';
import '../../features/town/screens/town_loading_screen.dart';
import '../../features/town/screens/town_screen.dart';
import '../../features/lessons/screens/battle_loading_screen.dart';
import '../../features/lessons/screens/match_words_screen.dart';
import '../../features/lessons/screens/fill_blank_screen.dart';
import '../../features/lessons/screens/picture_to_word_screen.dart';
import '../../features/lessons/screens/word_to_picture_screen.dart';
import '../../features/progression/screens/level_up_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../core/widgets/not_found_screen.dart';
import '../shell/main_shell_screen.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const String landing = '/';
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String signup = '/signup';
  static const String login = '/login';
  static const String characterSelect = '/character-select';
  static const String languageSelect = '/language-select';
  static const String townLoading = '/town-loading';
  static const String town = '/town';
  static const String battleLoading = '/battle-loading';
  static const String matchWords = '/lesson/match-words';
  static const String fillBlank = '/lesson/fill-blank';
  static const String pictureToWord = '/lesson/picture-to-word';
  static const String wordToPicture = '/lesson/word-to-picture';
  static const String levelUp = '/level-up';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';
}

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.landing,
  errorBuilder: (context, state) =>
      NotFoundScreen(uri: state.uri.toString()),
  routes: [
    // ─── Onboarding & Entry Flow ──────────────────────
    GoRoute(
      path: AppRoutes.landing,
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),

    // ─── Character & Language Selection (Onboarding + Profile Edit) ──
    GoRoute(
      path: AppRoutes.characterSelect,
      builder: (context, state) {
        final isEditing = state.uri.queryParameters['mode'] == 'edit';
        return CharacterSelectionScreen(isEditing: isEditing);
      },
    ),
    GoRoute(
      path: AppRoutes.languageSelect,
      builder: (context, state) {
        final isEditing = state.uri.queryParameters['mode'] == 'edit';
        return LanguageSelectionScreen(isEditing: isEditing);
      },
    ),

    // ─── Town Loading Transition ──────────────────────
    GoRoute(
      path: AppRoutes.townLoading,
      builder: (context, state) => const TownLoadingScreen(),
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
      builder: (context, state) => const BattleLoadingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.matchWords,
      builder: (context, state) => const MatchWordsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.fillBlank,
      builder: (context, state) => const FillBlankScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pictureToWord,
      builder: (context, state) => const PictureToWordScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.wordToPicture,
      builder: (context, state) => const WordToPictureScreen(),
    ),

    // ─── Level Up Celebration Screen ──────────────────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.levelUp,
      builder: (context, state) => const LevelUpScreen(),
    ),
  ],
);
