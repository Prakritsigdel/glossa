import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/audio_waveform.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go(AppRoutes.welcome);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlossaColors.blueDeep,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  const HeroAvatar(heroIndex: 0, level: 1, size: 80, showBorder: false),
                  const SizedBox(height: Spacing.sm),
                  // Shadow oval
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.pagePadding),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AudioWaveformIcon(color: GlossaColors.redAction, size: 36),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Loading your world...',
                        style: GlossaTypography.displayMediumOnDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Summoning native voices. Slow connection?\nHang tight.',
                        style: GlossaTypography.bodyMediumOnDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.xxxl),
                ],
              ),
            ),
            const GreekKeyBorder(),
          ],
        ),
      ),
    );
  }
}
