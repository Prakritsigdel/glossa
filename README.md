# Glossa

Gamified mobile app for learning Newari (Nepal Bhasa). Flutter, Riverpod, GoRouter.

## First-time setup

This folder holds the app source (`lib/`, `test/`, `assets/`, `pubspec.yaml`).
The Android/iOS platform folders come from `flutter create`:

```bash
flutter create glossa --org com.glossa --platforms=android
# copy this folder's contents over the new project, replacing files:
#   lib/  test/  assets/  pubspec.yaml  analysis_options.yaml  README.md
cd glossa
flutter pub get
flutter run
flutter test
```

If `pub get` reports a version conflict, run `flutter pub upgrade --major-versions`.

## Architecture (MVC)

The app is organised using **Model–View–Controller (MVC)** within each feature.
Riverpod is retained as the state-management mechanism, and GoRouter is retained
for navigation. These are supporting tools, not separate architectural patterns.

```text
lib/
  main.dart
  app.dart
  core/
    theme/       shared colours and typography
    router/      GoRouter configuration and route paths
    widgets/     reusable UI components
  features/
    splash/
      models/       (reserved for splash data)
      views/        splash_view.dart
      controllers/  splash_controller.dart
    welcome/
      models/       welcome_model.dart, learner_sprite.dart
      views/        welcome_view.dart
      controllers/  welcome_controller.dart
    placeholder/
      models/       placeholder_model.dart
      views/        placeholder_view.dart
      controllers/  placeholder_controller.dart
```

### MVC responsibilities

- **Model:** Holds feature data. Example: `WelcomeModel` stores whether a saved
  learning journey exists.
- **View:** Displays UI and forwards user/lifecycle events. Example:
  `WelcomeView` renders the welcome screen.
- **Controller:** Contains feature decisions and updates model state. Example:
  `WelcomeController` exposes and updates the welcome state through Riverpod.
- **Core:** Shared app infrastructure (theme, routing and reusable visual widgets).

### Current implementation notes

- The welcome journey flag is still temporary in-memory state and defaults to
  `false`; it is not connected to a database yet.
- Splash timing is handled by `SplashController`.
- Character selection, language selection and home are still placeholder views.
- Add repositories/services under a feature when persistent storage or API calls
  are introduced; do not put database queries directly in Views.

## Conventions

- Style values come from `AppColors` / `AppTextStyles`, never hardcoded in screens.
- Route paths come from `AppRoutes`.
- One feature = one folder under `features/`.
- Branch per task (e.g. `feature/T-05-character-select`), pull request, review before merge.

## Fonts

Bundled (no network needed): Press Start 2P and DM Sans, both SIL Open Font
License 1.1 (see `assets/fonts/OFL-PressStart2P.txt`).


## Welcome screen styling

The welcome view follows the supplied visual reference: royal-blue background, butter-yellow decorative header, bold DMSans headline, compact audio-preview card, and red/yellow action buttons. Shared palette values are defined in `lib/core/theme/app_colors.dart`. The audio preview is currently decorative; connect a native-speaker recording before enabling playback.
