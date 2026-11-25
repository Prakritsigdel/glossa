import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/glossa_card.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class TownScreen extends ConsumerStatefulWidget {
  const TownScreen({super.key});

  @override
  ConsumerState<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends ConsumerState<TownScreen> {
  final bool _isExpanded = false;
  bool _isStartingLesson = false;

  void _startLesson(Lesson lesson) {
    if (_isStartingLesson) return;
    setState(() => _isStartingLesson = true);
    ref.read(gameStateProvider.notifier).startLesson(lesson.id).then((_) {
      if (mounted) {
        context.go(AppRoutes.battleLoading);
      }
    }).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        setState(() => _isStartingLesson = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final user = gs.user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
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
                    // Player header
                    Row(
                      children: [
                        HeroAvatar(
                          heroIndex: user.heroIndex,
                          level: user.level,
                          size: 50,
                          animateIdle: true,
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lv ${user.level} ${user.heroClassName}',
                                style: GlossaTypography.bodySmall,
                              ),
                              Text(
                                'Ready, ${user.name}?',
                                style: GlossaTypography.headlineLarge,
                              ),
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Spacing.sm,
                      runSpacing: Spacing.xs,
                      children: [
                        Text(
                          '${user.xp} / ${user.xpToNextLevel} XP',
                          style: GlossaTypography.bodySmall,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: GlossaColors.streakGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🔥 ${user.streak} day streak',
                            style: GlossaTypography.labelSmall.copyWith(
                              color: GlossaColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xl),
                    // Town map using townMap provider
                    Consumer(
                      builder: (context, ref, _) {
                        final lessonAsync = ref.watch(townMapProvider);
                        return lessonAsync.when(
                          data: (lessons) {
                            if (lessons.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(Spacing.xl),
                                decoration: BoxDecoration(
                                  color: GlossaColors.creamPale,
                                  borderRadius:
                                      BorderRadius.circular(Spacing.cardRadius),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.school_rounded,
                                        size: 48,
                                        color: GlossaColors.textSubtle),
                                    const SizedBox(height: Spacing.md),
                                    Text(
                                      'No lessons available yet. Check back soon!',
                                      style: GlossaTypography.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: Spacing.md),
                                    GlossaButton(
                                      label: 'Back to Town',
                                      onPressed: () =>
                                          context.go(AppRoutes.town),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Group lessons by unitId
                            final lessonsByUnit = <int, List<Lesson>>{};
                            for (final lesson in lessons) {
                              if (lesson.unitId != null) {
                                lessonsByUnit.putIfAbsent(
                                    lesson.unitId!, () => []).add(lesson);
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: lessonsByUnit.entries.map((entry) {
                                final unitId = entry.key;
                                final unitLessons = entry.value;
                                if (unitLessons.isEmpty) return const SizedBox.shrink();
                                final displayLessons = _isExpanded
                                    ? unitLessons
                                    : unitLessons.take(3).toList();
                                return _UnitSection(
                                  unitId: unitId,
                                  clearedInUnit: unitLessons
                                      .where((l) =>
                                          l.status == LessonStatus.completed)
                                      .length,
                                  totalInUnit: unitLessons.length,
                                  lessons: displayLessons,
                                  onStart: _startLesson,
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, _) => Center(
                            child: Text('Error loading lessons: $error'),
                          ),
                        );
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
    );
  }
}

class _LessonPathItem extends StatelessWidget {
  final Lesson lesson;
  final bool isLast;
  final void Function(Lesson)? onStart;

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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: lesson.status == LessonStatus.available
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
                backgroundColor: lesson.status == LessonStatus.locked || lesson.status == LessonStatus.unavailable
                    ? GlossaColors.creamPale
                    : GlossaColors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: GlossaTypography.headlineSmall.copyWith(
                              color: lesson.status == LessonStatus.locked || lesson.status == LessonStatus.unavailable
                                  ? GlossaColors.textSubtle
                                  : GlossaColors.textDark,
                            ),
                          ),
                          if (lesson.isCheckpoint || lesson.isCapstone)
                            Text(
                              lesson.isCapstone ? 'CAPSTONE' : 'CHECKPOINT',
                              style: GlossaTypography.labelSmall.copyWith(
                                color: GlossaColors.redAction,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.subtitle,
                            style: GlossaTypography.bodySmall,
                          ),
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
      case LessonStatus.completed:
        return GlossaColors.successGreen;
      case LessonStatus.available:
        return GlossaColors.white;
      case LessonStatus.locked:
        return GlossaColors.creamPale;
      case LessonStatus.unavailable:
        return GlossaColors.creamPale;
    }
  }

  Widget get _nodeContent {
    switch (lesson.status) {
      case LessonStatus.completed:
        return const Icon(Icons.check, color: GlossaColors.white, size: 20);
      case LessonStatus.available:
        return Text(
          'GO',
          style: GlossaTypography.labelSmall.copyWith(
            color: GlossaColors.redAction,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        );
      case LessonStatus.locked:
        return Text(
          'Lv ${lesson.requiredLevel}',
          style: GlossaTypography.labelSmall.copyWith(fontSize: 9),
        );
      case LessonStatus.unavailable:
        return const Icon(Icons.lock_outline, color: GlossaColors.textSubtle, size: 18);
    }
  }

  Widget get _statusBadge {
    switch (lesson.status) {
      case LessonStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
          ),
          child: Text(
            'Cleared',
            style: GlossaTypography.labelSmall.copyWith(
              color: GlossaColors.textDark,
            ),
          ),
        );
      case LessonStatus.available:
        return GestureDetector(
          onTap: onStart == null ? null : () => onStart!(lesson),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: GlossaColors.redAction,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Go!',
              style: GlossaTypography.labelSmall.copyWith(
                color: GlossaColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      case LessonStatus.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlossaColors.disabledGray, width: 1.5),
          ),
          child: Text(
            'Lv ${lesson.requiredLevel}',
            style: GlossaTypography.labelSmall,
          ),
        );
      case LessonStatus.unavailable:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: GlossaColors.disabledGray, width: 1.5),
          ),
          child: Text('Coming soon', style: GlossaTypography.labelSmall),
        );
    }
  }
}

class _UnitSection extends StatelessWidget {
  final int unitId;
  final int clearedInUnit;
  final int totalInUnit;
  final List<Lesson> lessons;
  final void Function(Lesson) onStart;

  const _UnitSection({
    required this.unitId,
    required this.clearedInUnit,
    required this.totalInUnit,
    required this.lessons,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            Text(
              _unitName(unitId),
              style: GlossaTypography.headlineMedium,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
              ),
              child: Text(
                '$clearedInUnit / $totalInUnit cleared',
                style: GlossaTypography.labelSmall.copyWith(
                  color: GlossaColors.textDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        GlossaProgressBar(
          progress: totalInUnit > 0 ? clearedInUnit / totalInUnit : 0,
          fillColor: clearedInUnit == totalInUnit
              ? GlossaColors.successGreen
              : GlossaColors.redAction,
        ),
        const SizedBox(height: Spacing.xl),
        ...lessons.map((lesson) => _LessonPathItem(
          lesson: lesson,
          isLast: lessons.last == lesson,
          onStart: onStart,
        )),
      ],
    );
  }

  String _unitName(int unitId) {
    switch (unitId) {
      case 1:
        return 'Greetings';
      case 2:
        return 'Family';
      case 3:
        return 'Numbers & Colors';
      case 4:
        return 'Food & Drinks';
      case 5:
        return 'Home & Routines';
      default:
        return 'Unit $unitId';
    }
  }
}
