import 'dart:async';

/// Controls the splash-screen delay and completion callback.
/// The view owns this controller's lifecycle and calls dispose when removed.
class SplashController {
  Timer? _timer;

  void start({required Duration duration, required void Function() onComplete}) {
    _timer?.cancel();
    _timer = Timer(duration, onComplete);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
