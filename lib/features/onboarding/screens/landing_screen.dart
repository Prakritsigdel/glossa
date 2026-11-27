import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/features/authentication/widgets/auth_brand_header.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  Timer? _autoNav;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );
    _entranceController.forward();
    // Auto-advance to the session-restore splash after the entrance animation.
    _autoNav = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) context.go(AppRoutes.splash);
    });
  }

  @override
  void dispose() {
    _autoNav?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  void _skip() {
    _autoNav?.cancel();
    context.go(AppRoutes.splash);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlossaColors.blueDeep,
      body: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.pagePadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Spacing.lg),
                        // Logo + decorative Devanagari background
                        const AuthBrandHeader(),
                        const SizedBox(height: Spacing.xxxl),
                        // New Game button (red)
                        GlossaButton(
                          label: 'New Game',
                          style: GlossaButtonStyle.primary,
                          onPressed: () {
                            _autoNav?.cancel();
                            context.go(AppRoutes.signup);
                          },
                        ),
                        const SizedBox(height: Spacing.lg),
                        // Continue button (yellow)
                        GlossaButton(
                          label: 'Continue (load save)',
                          style: GlossaButtonStyle.secondary,
                          onPressed: () {
                            _autoNav?.cancel();
                            context.go(AppRoutes.login);
                          },
                        ),
                        const SizedBox(height: Spacing.xxl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
