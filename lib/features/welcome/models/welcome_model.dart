/// Data required by the Welcome feature.
/// Replace the temporary value with persisted progress when storage is added.
class WelcomeModel {
  const WelcomeModel({this.hasSavedJourney = false});

  final bool hasSavedJourney;

  WelcomeModel copyWith({bool? hasSavedJourney}) {
    return WelcomeModel(
      hasSavedJourney: hasSavedJourney ?? this.hasSavedJourney,
    );
  }
}
