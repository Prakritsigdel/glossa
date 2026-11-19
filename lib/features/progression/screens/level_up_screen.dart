import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/greek_key_border.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

/// Lesson complete / level-up celebration screen.
class LevelUpScreen extends ConsumerWidget {
  const LevelUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

                    // ─── Yellow arch with hero ──────────
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
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HeroAvatarLarge(
                            heroIndex: user.heroIndex,
                            level: user.level,
                            size: 110,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),

                    // ─── LEVEL UP! ─────────────────────
                    Text(
                      'LEVEL UP!',
                      style: GlossaTypography.displayLarge.copyWith(
                        color: GlossaColors.yellowPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Lv ${user.level} ${user.levelTitle}',
                      style: GlossaTypography.headlineMedium
                          .copyWith(color: GlossaColors.white),
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
                          Wrap(
                            spacing: Spacing.sm,
                            runSpacing: Spacing.sm,
                            children: learnedWords
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
                            value: '+20',
                            label: 'XP',
                            color: GlossaColors.yellowPrimary,
                          ),
                          const SizedBox(width: Spacing.md),
                          _StatCard(
                            value: '4/4',
                            label: 'Hits',
                            color: GlossaColors.successGreen,
                          ),
                          const SizedBox(width: Spacing.md),
                          _StatCard(
                            value: '🔥',
                            label: 'Streak',
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
                        label: 'Back to Town',
                        style: GlossaButtonStyle.secondary,
                        onPressed: () {
                          ref.read(gameStateProvider.notifier).resetLesson();
                          context.go(AppRoutes.town);
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
