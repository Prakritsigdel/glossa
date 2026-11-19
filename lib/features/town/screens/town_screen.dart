import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_card.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';

class TownScreen extends ConsumerStatefulWidget {
  const TownScreen({super.key});

  @override
  ConsumerState<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends ConsumerState<TownScreen> {
  bool _isExpanded = false;

  void _startLesson(Lesson lesson) {
    if (lesson.status == LessonStatus.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Level ${lesson.requiredLevel} required to unlock "${lesson.title}"!'),
        ),
      );
      return;
    }
    ref.read(gameStateProvider.notifier).startLesson(lesson.id);
    context.go(AppRoutes.battleLoading);
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final user = gs.user;
    final lessons = gs.lessons;
    final cleared = lessons.where((l) => l.status == LessonStatus.cleared).length;
    final displayLessons = _isExpanded ? lessons : lessons.take(3).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.lg),
                    // Player header
                    Row(
                      children: [
                        HeroAvatar(heroIndex: user.heroIndex, level: user.level, size: 50),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user.languageName} · Lv ${user.level} ${user.heroClassName}',
                                style: GlossaTypography.bodySmall,
                              ),
                              Text('Ready, ${user.name}?',
                                  style: GlossaTypography.headlineLarge),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    GlossaProgressBar(
                      progress: user.xp / user.xpToNextLevel,
                      fillColor: GlossaColors.redAction,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Row(
                      children: [
                        Text('${user.xp} / ${user.xpToNextLevel} XP',
                            style: GlossaTypography.bodySmall),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: GlossaColors.streakGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('🔥 ${user.streak} day streak',
                              style: GlossaTypography.labelSmall
                                  .copyWith(color: GlossaColors.white, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xl),
                    // Word of the day
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: GlossaColors.blueNavy,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Word of the day',
                                  style: GlossaTypography.labelSmall
                                      .copyWith(color: Colors.white60)),
                              const SizedBox(height: 2),
                            ],
                          ),
                          const SizedBox(width: Spacing.md),
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: GlossaColors.yellowPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                wordOfTheDay['devanagari']!,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansDevanagari',
                                  fontSize: 18, fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Text(wordOfTheDay['english']!,
                                style: GlossaTypography.headlineMedium
                                    .copyWith(color: GlossaColors.white)),
                          ),
                          Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(
                              color: GlossaColors.redAction,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow,
                                color: GlossaColors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    // World progress
                    Row(
                      children: [
                        Expanded(
                          child: Text('World 1: Home & Food',
                              style: GlossaTypography.headlineMedium),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
                          ),
                          child: Text('$cleared / ${lessons.length} cleared',
                              style: GlossaTypography.labelSmall
                                  .copyWith(color: GlossaColors.textDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    GlossaProgressBar(
                      progress: cleared / lessons.length,
                      fillColor: GlossaColors.redAction,
                    ),
                    const SizedBox(height: Spacing.xl),
                    // Lesson path
                    ...displayLessons.asMap().entries.map((entry) {
                      final i = entry.key;
                      final lesson = entry.value;
                      final isLast = i == displayLessons.length - 1;
                      return _LessonPathItem(
                        lesson: lesson,
                        isLast: isLast,
                        onStart: lesson.status == LessonStatus.current
                            ? () => _startLesson(lesson)
                            : null,
                      );
                    }),
                    // Expand/collapse button
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: GlossaColors.yellowPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: GlossaColors.blueNavy, width: 2),
                          ),
                          child: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: GlossaColors.textDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    // Family Voices
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: GlossaColors.creamPale,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                        border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(
                              color: GlossaColors.redAction,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow,
                                color: GlossaColors.white, size: 20),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Family Voices',
                                    style: GlossaTypography.headlineSmall),
                                Text('Aji added 12 words.',
                                    style: GlossaTypography.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonPathItem extends StatelessWidget {
  final Lesson lesson;
  final bool isLast;
  final VoidCallback? onStart;

  const _LessonPathItem({
    required this.lesson,
    required this.isLast,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path node
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: lesson.status == LessonStatus.current
                          ? GlossaColors.redAction
                          : GlossaColors.blueNavy,
                      width: 2,
                    ),
                  ),
                  child: Center(child: _nodeContent),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: GlossaColors.blueNavy.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          // Lesson card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Spacing.lg),
              child: GlossaCard(
                backgroundColor: lesson.status == LessonStatus.locked
                    ? GlossaColors.creamPale
                    : GlossaColors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lesson.title,
                              style: GlossaTypography.headlineSmall.copyWith(
                                color: lesson.status == LessonStatus.locked
                                    ? GlossaColors.textSubtle
                                    : GlossaColors.textDark,
                              )),
                          const SizedBox(height: 2),
                          Text(lesson.subtitle,
                              style: GlossaTypography.bodySmall),
                        ],
                      ),
                    ),
                    _statusBadge,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _nodeColor {
    switch (lesson.status) {
      case LessonStatus.cleared:
        return GlossaColors.successGreen;
      case LessonStatus.current:
        return GlossaColors.white;
      case LessonStatus.locked:
        return GlossaColors.creamPale;
    }
  }

  Widget get _nodeContent {
    switch (lesson.status) {
      case LessonStatus.cleared:
        return const Icon(Icons.check, color: GlossaColors.white, size: 20);
      case LessonStatus.current:
        return Text('GO', style: GlossaTypography.labelSmall
            .copyWith(color: GlossaColors.redAction, fontWeight: FontWeight.w900, fontSize: 10));
      case LessonStatus.locked:
        return Text('Lv ${lesson.requiredLevel}',
            style: GlossaTypography.labelSmall.copyWith(fontSize: 9));
    }
  }

  Widget get _statusBadge {
    switch (lesson.status) {
      case LessonStatus.cleared:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
          ),
          child: Text('Cleared', style: GlossaTypography.labelSmall
              .copyWith(color: GlossaColors.textDark)),
        );
      case LessonStatus.current:
        return GestureDetector(
          onTap: onStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: GlossaColors.redAction,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Go!', style: GlossaTypography.labelSmall
                .copyWith(color: GlossaColors.white, fontWeight: FontWeight.w700)),
          ),
        );
      case LessonStatus.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlossaColors.disabledGray, width: 1.5),
          ),
          child: Text('Lv ${lesson.requiredLevel}',
              style: GlossaTypography.labelSmall),
        );
    }
  }
}
