import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/motion/motion_widgets.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

/// Lesson complete / level-up celebration screen with particle fireworks and animated progression.
class LevelUpScreen extends ConsumerStatefulWidget {
  const LevelUpScreen({super.key});

  @override
  ConsumerState<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends ConsumerState<LevelUpScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _celebrationController;
  late Animation<double> _titleScale;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: GlossaMotion.celebration,
    )..forward();

    _titleScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final user = gs.user;
    final xpProgress = user.xpToNextLevel > 0
        ? (user.xp / user.xpToNextLevel).clamp(0.0, 1.0)
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(gameStateProvider.notifier).resetLesson();
          context.go(AppRoutes.town);
        }
      },
      child: Scaffold(
        backgroundColor: GlossaColors.blueDeep,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).padding.top + Spacing.xxl),

                      // ─── Yellow arch with hero + particle bursts ──
                      SizedBox(
                        width: 240,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const CelebrationParticles(size: 240),
                            Container(
                              width: 180,
                              height: 200,
                              decoration: BoxDecoration(
                                color: GlossaColors.yellowPrimary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(90),
                                  topRight: Radius.circular(90),
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                border: Border.all(
                                    color: GlossaColors.blueNavy, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    offset: Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HeroAvatarLarge(
                                    heroIndex: user.heroIndex,
                                    level: user.level,
                                    size: 110,
                                    animateIdle: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),

                      // ─── LEVEL UP! (Bouncing Elastic Entrance) ──
                      ScaleTransition(
                        scale: _titleScale,
                        child: Text(
                          gs.lastPassed ? 'LESSON PASSED' : 'TRY AGAIN',
                          style: GlossaTypography.displayLarge.copyWith(
                            color: GlossaColors.yellowPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Lv ${user.level} ${user.levelTitle}',
                        style: GlossaTypography.headlineMedium
                            .copyWith(color: GlossaColors.white),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Score: ${(gs.lastScore * 100).toStringAsFixed(0)}% · Pass mark: ${gs.lastPassingThreshold}%${gs.lastAlreadyCompleted ? ' · Already completed' : ''}',
                        textAlign: TextAlign.center,
                        style: GlossaTypography.bodyMedium.copyWith(
                          color: GlossaColors.white,
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),

                      // ─── XP progress ───────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.pagePadding * 2),
                        child: Column(
                          children: [
                            GlossaProgressBar(
                              progress: xpProgress,
                              fillColor: GlossaColors.yellowPrimary,
                              trackColor: GlossaColors.white.withValues(alpha: 0.2),
                              height: 14,
                            ),
                            const SizedBox(height: Spacing.sm),
                            Text(
                              '${user.xp} / ${user.xpToNextLevel} XP',
                              style: GlossaTypography.bodySmall
                                  .copyWith(color: GlossaColors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),

                      // ─── Learned words ─────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.pagePadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Words learned',
                                style: GlossaTypography.headlineSmall
                                  .copyWith(color: GlossaColors.white)),
                            const SizedBox(height: Spacing.md),
                            // FIX 5: use real words from the completed lesson
                            gs.lastWordsLearned.isNotEmpty
                              ? Wrap(
                                  spacing: Spacing.sm,
                                  runSpacing: Spacing.sm,
                                  children: gs.lastWordsLearned
                                      .map((w) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: GlossaColors.yellowPrimary
                                                  .withValues(alpha: 0.25),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: GlossaColors.yellowPrimary,
                                                  width: 1.5),
                                            ),
                                            child: Text(
                                              w,
                                              style: GlossaTypography.devanagariSmall
                                                  .copyWith(
                                                      color: GlossaColors
                                                          .yellowPrimary),
                                            ),
                                          ))
                                      .toList(),
                                )
                              : Text(
                                  'Keep learning!',
                                  style: GlossaTypography.bodySmall
                                      .copyWith(color: GlossaColors.white),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),

                      // ─── Stat cards ────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.pagePadding),
                        child: Row(
                          children: [
                            _StatCard(
                              value: '+${gs.lastXpEarned}',
                              label: 'XP',
                              color: GlossaColors.yellowPrimary,
                            ),
                            const SizedBox(width: Spacing.md),
                            _StatCard(
                              value: '${gs.lastCorrectAnswers}/${gs.lastTotalQuestions}',
                              label: 'Hits',
                              color: GlossaColors.successGreen,
                            ),
                            const SizedBox(width: Spacing.md),
                            _StatCard(
                              value: '🔥',
                              label: '${user.streak}d streak',
                              color: GlossaColors.redAction,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.xxxl),

                      // ─── Back to Town button ───────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.pagePadding),
                        child: GlossaButton(
                          label: gs.lastPassed ? 'Continue' : 'Retry lesson',
                          loadingLabel: gs.lastPassed ? 'Continuing...' : 'Retrying...',
                          style: GlossaButtonStyle.secondary,
                          onPressed: _navigating
                              ? null
                              : () async {
                                  setState(() => _navigating = true);
                                  final router = GoRouter.of(context);
                                  final notifier = ref.read(gameStateProvider.notifier);
                                  if (!gs.lastPassed && gs.activeLessonId != null) {
                                    await notifier.startLesson(gs.activeLessonId!);
                                    if (!mounted) return;
                                    router.go(AppRoutes.battleLoading);
                                  } else {
                                    notifier.resetLesson();
                                    if (mounted) router.go(AppRoutes.town);
                                  }
                                },
                        ),
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
        decoration: BoxDecoration(
          color: GlossaColors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Spacing.cardRadius),
          border: Border.all(
              color: GlossaColors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GlossaTypography.headlineLarge.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GlossaTypography.labelSmall
                  .copyWith(color: GlossaColors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
