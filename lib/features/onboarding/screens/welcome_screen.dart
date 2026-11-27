import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlossaColors.blueDeep,
      body: SafeArea(
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
                    // Logo + decorative Devanagari
                    SizedBox(
                      height: 180,
                      child: Stack(
                        children: [
                          // Large faded Devanagari text
                          Positioned(
                            right: -20,
                            top: 0,
                            child: Text(
                              'भार',
                              style: TextStyle(
                                fontFamily: 'NotoSansDevanagari',
                                fontSize: 140,
                                fontWeight: FontWeight.w700,
                                color: GlossaColors.yellowPrimary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 0,
                            top: 16,
                            child: GlossaAppIcon(size: 48),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      'Hear the\nlanguage of\nhome.',
                      style: GlossaTypography.displayLargeOnDark.copyWith(
                        fontSize: 36,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'Short lessons built on real recordings of native speakers.',
                      style: GlossaTypography.bodyMediumOnDark,
                    ),
                    const SizedBox(height: Spacing.xxl),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: GlossaColors.white,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: GlossaColors.redAction,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: GlossaColors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: const [
                                _WaveformBar(height: 8),
                                _WaveformBar(height: 20),
                                _WaveformBar(height: 34),
                                _WaveformBar(height: 50),
                                _WaveformBar(height: 30),
                                _WaveformBar(height: 44),
                                _WaveformBar(height: 16),
                                _WaveformBar(height: 38),
                                _WaveformBar(height: 50),
                                _WaveformBar(height: 26),
                                _WaveformBar(height: 10),
                                _WaveformBar(height: 22),
                              ],
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Text(
                            'भाय्',
                            style: GlossaTypography.devanagariMedium.copyWith(
                              fontSize: 24,
                              color: GlossaColors.blueNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    GlossaButton(
                      label: 'New Game',
                      style: GlossaButtonStyle.primary,
                      onPressed: () => context.go(AppRoutes.signup),
                    ),
                    const SizedBox(height: Spacing.lg),
                    GlossaButton(
                      label: 'Continue (load save)',
                      style: GlossaButtonStyle.secondary,
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
            const GreekKeyBorder(),
          ],
        ),
      ),
    );
  }
}

class _WaveformBar extends StatelessWidget {
  const _WaveformBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: height,
      decoration: BoxDecoration(
        color: GlossaColors.redAction,
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
    );
  }
}
