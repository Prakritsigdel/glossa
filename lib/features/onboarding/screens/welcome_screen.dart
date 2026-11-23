import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/audio_waveform.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlossaColors.blueDeep,
      body: SafeArea(
        // top and bottom default to true, so the content stays clear of the
        // status bar (clock, battery) and the system navigation bar
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
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
                                color: GlossaColors.yellowPrimary.withValues(alpha: 0.3),
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
                      'Short lessons built on real recordings of\nnative speakers.',
                      style: GlossaTypography.bodyMediumOnDark,
                    ),
                    const SizedBox(height: Spacing.xxl),
                    // Audio preview strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg,
                        vertical: Spacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: GlossaColors.white,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isPlaying = !_isPlaying),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: GlossaColors.redAction,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: GlossaColors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: AudioWaveform(
                              isPlaying: _isPlaying,
                              barColor: GlossaColors.redAction,
                              height: 28,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Text(
                            'भाय्',
                            style: GlossaTypography.devanagariMedium.copyWith(
                              fontSize: 28,
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
