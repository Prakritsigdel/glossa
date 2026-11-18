import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/placeholder/models/placeholder_model.dart';
import '../../features/placeholder/views/placeholder_view.dart';
import '../../features/splash/views/splash_view.dart';
import '../../features/welcome/views/welcome_view.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeView(),
      ),
      // Placeholders - replaced screen by screen as they are built.
      GoRoute(
        path: AppRoutes.character,
        builder: (context, state) => const PlaceholderView(
          model: PlaceholderModel(
            title: 'Choose your character',
            note: 'T-05 - character selection and learner name.',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (context, state) => const PlaceholderView(
          model: PlaceholderModel(
            title: 'Choose a language',
            note: 'T-06 - Newari only for this release.',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const PlaceholderView(
          model: PlaceholderModel(
            title: 'Home',
            note: 'T-07 - town dashboard with level, XP and lessons.',
          ),
        ),
      ),
    ],
  );
});
