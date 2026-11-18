import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/waveform.dart';
import '../../../core/widgets/wordmark.dart';
import '../controllers/splash_controller.dart';

/// Splash View: renders the splash UI and delegates its timing to the controller.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  final SplashController _controller = SplashController();

  @override
  void initState() {
    super.initState();
    _controller.start(
      duration: const Duration(milliseconds: 2200),
      onComplete: () {
        if (mounted) context.go(AppRoutes.welcome);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(child: Wordmark(size: 40)),
              SizedBox(height: 28),
              SizedBox(width: 220, child: Waveform(barCount: 15, height: 48)),
            ],
          ),
        ),
      ),
    );
  }
}
