import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/welcome_model.dart';

/// MVC Controller for welcome-screen decisions and journey state.
class WelcomeController extends StateNotifier<WelcomeModel> {
  WelcomeController() : super(const WelcomeModel());

  bool get hasSavedJourney => state.hasSavedJourney;

  /// Temporary setter for development previews.
  /// A repository will load/save this value when persistence is implemented.
  void setHasSavedJourney(bool value) {
    state = state.copyWith(hasSavedJourney: value);
  }
}

final welcomeControllerProvider =
    StateNotifierProvider<WelcomeController, WelcomeModel>(
  (ref) => WelcomeController(),
);
