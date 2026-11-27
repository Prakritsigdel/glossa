import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/core/widgets/simple_illustration.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

String _createSubmissionId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class MatchWordsShuffleResult {
  const MatchWordsShuffleResult({
    required this.devanagari,
    required this.english,
  });

  final List<AnswerOption> devanagari;
  final List<AnswerOption> english;
}

class MatchWordsRandomizer {
  static MatchWordsShuffleResult randomize({
    required List<AnswerOption> options,
    Map<String, String> pairs = const {},
    Random? random,
  }) {
    final rng = random ?? Random();
    final devanagari = options.where((option) => option.isDevanagari).toList()
      ..shuffle(rng);
    final english = options.where((option) => !option.isDevanagari).toList()
      ..shuffle(rng);

    if (pairs.isNotEmpty && english.length > 1) {
      for (var shift = 0; shift < english.length; shift++) {
        final rotated = [...english.skip(shift), ...english.take(shift)];
        var aligned = false;
        final count = devanagari.length < rotated.length
            ? devanagari.length
            : rotated.length;
        for (var index = 0; index < count; index++) {
          if (pairs[devanagari[index].id] == rotated[index].id) {
            aligned = true;
            break;
          }
        }
        if (!aligned) {
          return MatchWordsShuffleResult(
            devanagari: devanagari,
            english: rotated,
          );
        }
      }
    }

    return MatchWordsShuffleResult(devanagari: devanagari, english: english);
  }
}

class LessonRunnerScreen extends ConsumerStatefulWidget {
  const LessonRunnerScreen({super.key});

  @override
  ConsumerState<LessonRunnerScreen> createState() => _LessonRunnerScreenState();
}

class _LessonRunnerScreenState extends ConsumerState<LessonRunnerScreen> {
  bool _completing = false;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(gameStateProvider).needsCompletion) {
        unawaited(_completeSavedRun());
      }
    });
  }

  void _showLeaveDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave lesson?'),
        content: const Text(
          'Your answers are saved. You can resume this lesson later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(gameStateProvider.notifier).resetLesson();
              context.go(AppRoutes.town);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    final notifier = ref.read(gameStateProvider.notifier);
    final gs = ref.read(gameStateProvider);
    if (_advancing || _completing) return;
    if (gs.isReviewingMistakes) {
      setState(() => _advancing = true);
      try {
        final queue = await notifier.refreshReviewQueue();
        if (!mounted) return;
        if (queue.isEmpty) {
          await _completeSavedRun();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      } finally {
        if (mounted) setState(() => _advancing = false);
      }
      return;
    }
    if (gs.currentExerciseIndex < gs.exercises.length - 1) {
      notifier.nextExercise();
      return;
    }
    setState(() => _advancing = true);
    try {
      final queue = await notifier.refreshReviewQueue();
      if (!mounted) return;
      if (queue.isNotEmpty) {
        notifier.beginMistakeReview(queue);
        return;
      }
      await _completeSavedRun();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Future<void> _completeSavedRun() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await ref.read(gameStateProvider.notifier).completeLesson();
      if (mounted) {
        ref.invalidate(townMapProvider);
        context.go(AppRoutes.levelUp);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    if (gs.exercises.isEmpty) {
      return Scaffold(
        backgroundColor: GlossaColors.creamBackground,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No exercises found for this lesson.'),
                const SizedBox(height: Spacing.md),
                GlossaButton(
                  label: 'Back to Town',
                  onPressed: () => context.go(AppRoutes.town),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Exercise? exercise;
    var exerciseProgress = 0.0;
    var progressLabel = '';
    if (gs.isReviewingMistakes) {
      final reviewId = gs.reviewQueue.isEmpty ? null : gs.reviewQueue.first;
      for (final item in gs.exercises) {
        if (item.id == reviewId) {
          exercise = item;
          break;
        }
      }
      final completedReviews = gs.reviewTotalCount - gs.reviewQueue.length;
      exerciseProgress = gs.reviewTotalCount == 0
          ? 0
          : (completedReviews + 1) / gs.reviewTotalCount;
      progressLabel =
          'Review ${completedReviews + 1} of ${gs.reviewTotalCount} · ${gs.reviewQueue.length} remaining';
    } else if (gs.currentExerciseIndex >= 0 &&
        gs.currentExerciseIndex < gs.exercises.length) {
      exercise = gs.exercises[gs.currentExerciseIndex];
      exerciseProgress = (gs.currentExerciseIndex + 1) / gs.exercises.length;
      progressLabel =
          'Exercise ${gs.currentExerciseIndex + 1} of ${gs.exercises.length}';
    }
    if (exercise == null) {
      return Scaffold(
        backgroundColor: GlossaColors.creamBackground,
        body: SafeArea(
          child: _ExerciseUnavailable(
            message:
                'This lesson is out of sync. Return to Town and try again.',
          ),
        ),
      );
    }

    final earnedSoFar = gs.exercises.fold<int>(0, (total, item) {
      return total + (gs.answers[item.id]?['correct'] == true ? item.xp : 0);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showLeaveDialog();
      },
      child: Scaffold(
        backgroundColor: GlossaColors.creamBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showLeaveDialog,
                      child: const Icon(
                        Icons.close_rounded,
                        color: GlossaColors.blueNavy,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: LessonProgressBar(progress: exerciseProgress),
                    ),
                    const SizedBox(width: Spacing.sm),
                    _XpPill(xp: earnedSoFar),
                    const SizedBox(width: Spacing.sm),
                    HeroAvatar(
                      heroIndex: gs.user.heroIndex,
                      level: gs.user.level,
                      size: 40,
                      animateIdle: true,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text(progressLabel, style: GlossaTypography.bodySmall),
                if (gs.isReviewingMistakes) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Reviewing mistakes',
                    style: GlossaTypography.headlineSmall.copyWith(
                      color: GlossaColors.redAction,
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.md),
                Expanded(
                  child: _completing || _advancing || gs.needsCompletion
                      ? const Center(child: CircularProgressIndicator())
                      : _buildExercise(exercise, gs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExercise(Exercise exercise, GameState gameState) {
    void onContinue() => unawaited(_continue());
    final problem = _exerciseProblem(exercise);
    if (problem != null) {
      return _ExerciseUnavailable(message: problem);
    }

    switch (exercise.type) {
      case ExerciseType.matchWords:
        return _MatchWordsExercise(
          key: ValueKey('${exercise.id}-${gameState.isReviewingMistakes}'),
          exercise: exercise,
          onContinue: onContinue,
        );
      case ExerciseType.fillBlank:
        return _ChoiceExercise(
          key: ValueKey(
            '${exercise.id}-${gameState.isReviewingMistakes}-${gameState.reviewRetryNonce}',
          ),
          exercise: exercise,
          fillBlank: true,
          review: gameState.isReviewingMistakes,
          onContinue: onContinue,
        );
      case ExerciseType.pictureToWord:
        return _ChoiceExercise(
          key: ValueKey(
            '${exercise.id}-${gameState.isReviewingMistakes}-${gameState.reviewRetryNonce}',
          ),
          exercise: exercise,
          fillBlank: false,
          review: gameState.isReviewingMistakes,
          onContinue: onContinue,
        );
      case ExerciseType.wordToPicture:
        return _WordToPictureExercise(
          key: ValueKey(
            '${exercise.id}-${gameState.isReviewingMistakes}-${gameState.reviewRetryNonce}',
          ),
          exercise: exercise,
          review: gameState.isReviewingMistakes,
          onContinue: onContinue,
        );
      case ExerciseType.translate:
      case ExerciseType.wordOrder:
      case ExerciseType.dialogueComplete:
        return _ExerciseUnavailable(
          message: 'This exercise format is not supported in this lesson.',
        );
    }
  }

  String? _exerciseProblem(Exercise exercise) {
    final optionIds = exercise.options.map((option) => option.id).toSet();
    if (optionIds.length != exercise.options.length) {
      return 'This exercise has duplicate answer choices and cannot be shown.';
    }

    switch (exercise.type) {
      case ExerciseType.matchWords:
        final newariCount = exercise.options
            .where((option) => option.isDevanagari)
            .length;
        final englishCount = exercise.options.length - newariCount;
        if (newariCount == 0 ||
            englishCount == 0 ||
            newariCount != englishCount) {
          return 'The matching choices for this exercise are incomplete.';
        }
        break;
      case ExerciseType.fillBlank:
        final layout = exercise.layout;
        final sentence = layout?['sentence'];
        final tile = layout?['tile'];
        final hasBlank =
            sentence is List &&
            sentence.whereType<Map>().any((part) => part['blank'] == true);
        if (exercise.options.isEmpty ||
            !hasBlank ||
            (tile != null && tile is! Map)) {
          return 'The answer choices or blank for this exercise are missing.';
        }
        break;
      case ExerciseType.pictureToWord:
        if (exercise.options.isEmpty) {
          return 'The answer choices for this exercise are missing.';
        }
        if (!SimpleIllustration.supports(exercise.imageKey)) {
          return 'The illustration for this exercise is unavailable.';
        }
        break;
      case ExerciseType.wordToPicture:
        if (exercise.options.isEmpty) {
          return 'The answer choices for this exercise are missing.';
        }
        if (exercise.options.any(
          (option) => !SimpleIllustration.supports(option.imageKey),
        )) {
          return 'One or more illustrations for this exercise are unavailable.';
        }
        break;
      case ExerciseType.translate:
      case ExerciseType.wordOrder:
      case ExerciseType.dialogueComplete:
        return 'This exercise format is not supported in this lesson.';
    }
    return null;
  }
}

class _ExerciseUnavailable extends ConsumerWidget {
  const _ExerciseUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline,
          color: GlossaColors.redAction,
          size: 40,
        ),
        const SizedBox(height: Spacing.md),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: Spacing.md),
        GlossaButton(
          label: 'Back to Town',
          onPressed: () {
            ref.read(gameStateProvider.notifier).resetLesson();
            context.go(AppRoutes.town);
          },
        ),
      ],
    ),
  );
}

class _XpPill extends StatelessWidget {
  const _XpPill({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: GlossaColors.yellowPrimary,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GlossaColors.blueNavy, width: 1.5),
    ),
    child: Text('+$xp XP', style: GlossaTypography.labelSmall),
  );
}

class _ChoiceExercise extends ConsumerStatefulWidget {
  const _ChoiceExercise({
    super.key,
    required this.exercise,
    required this.fillBlank,
    required this.review,
    required this.onContinue,
  });

  final Exercise exercise;
  final bool fillBlank;
  final bool review;
  final VoidCallback onContinue;

  @override
  ConsumerState<_ChoiceExercise> createState() => _ChoiceExerciseState();
}

class _ChoiceExerciseState extends ConsumerState<_ChoiceExercise> {
  String? _selectedId;
  String? _submissionId;
  String? _error;
  Map<String, dynamic>? _result;
  bool _checking = false;

  Future<void> _check() async {
    final selectedId = _selectedId;
    if (selectedId == null || _checking || _result != null) return;
    _submissionId ??= _createSubmissionId();
    setState(() => _checking = true);
    try {
      final result = await ref
          .read(gameStateProvider.notifier)
          .submitExerciseAnswer(
            widget.exercise.id,
            submissionId: _submissionId,
            review: widget.review,
            selectedOptionId: selectedId,
          );
      if (mounted) {
        setState(() {
          _result = result;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to check your answer.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final layout = exercise.layout ?? const <String, dynamic>{};
    final tile = layout['tile'] as Map<String, dynamic>? ?? const {};
    final sentence = layout['sentence'] as List? ?? const [];
    AnswerOption? selected;
    for (final option in exercise.options) {
      if (option.id == _selectedId) {
        selected = option;
        break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.fillBlank ? 'Fill in the blank' : 'Name the picture',
            style: GlossaTypography.headlineLarge,
          ),
          const SizedBox(height: Spacing.lg),
          if (widget.fillBlank)
            _FillBlankPrompt(
              exercise: exercise,
              tile: tile,
              sentence: sentence,
              selected: selected,
              onClear: _result == null && !_checking && _error == null
                  ? () => setState(() => _selectedId = null)
                  : null,
            )
          else
            _PicturePrompt(imageKey: exercise.imageKey),
          const SizedBox(height: Spacing.lg),
          if (widget.fillBlank)
            Text('Choose an answer', style: GlossaTypography.headlineSmall),
          if (widget.fillBlank) const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: exercise.options.map((option) {
              final isSelected = option.id == _selectedId;
              return _AnswerChip(
                option: option,
                selected: isSelected,
                ghost: widget.fillBlank && isSelected,
                disabled: _checking || _result != null || _error != null,
                correct:
                    (_result?['correct'] == true && isSelected) ||
                    _result?['correct_option_id'] == option.id,
                wrong: _result?['correct'] == false && isSelected,
                onTap: () =>
                    setState(() => _selectedId = isSelected ? null : option.id),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.lg),
          if (_result == null) ...[
            if (_error != null) ...[
              Text(_error!, style: GlossaTypography.bodySmall),
              const SizedBox(height: Spacing.sm),
            ],
            GlossaButton(
              label: _error == null
                  ? (widget.fillBlank ? 'Check' : 'Check answer')
                  : 'Retry check',
              loadingLabel: 'Checking...',
              style: GlossaButtonStyle.primary,
              onPressed: _selectedId != null && !_checking ? _check : null,
            ),
          ] else ...[
            _AnswerFeedback(
              correct: _result!['correct'] as bool,
              answer: _result!['correct_answer'] as Map<String, dynamic>?,
            ),
            const SizedBox(height: Spacing.md),
            if (widget.review && _result!['correct'] != true)
              GlossaButton(
                label: 'Try Again',
                style: GlossaButtonStyle.dark,
                onPressed: () => setState(() {
                  _selectedId = null;
                  _submissionId = null;
                  _result = null;
                  _error = null;
                }),
              )
            else
              GlossaButton(
                label: 'Continue',
                style: GlossaButtonStyle.dark,
                onPressed: widget.onContinue,
              ),
          ],
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}

class _FillBlankPrompt extends StatelessWidget {
  const _FillBlankPrompt({
    required this.exercise,
    required this.tile,
    required this.sentence,
    required this.selected,
    required this.onClear,
  });

  final Exercise exercise;
  final Map<String, dynamic> tile;
  final List sentence;
  final AnswerOption? selected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final imageKey = tile['image_key'] as String?;
      final isRecognition = exercise.variant == 'recognition';
      final tileCard = Container(
        constraints: const BoxConstraints(minHeight: 100),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: GlossaColors.white,
          borderRadius: BorderRadius.circular(Spacing.cardRadius),
          border: Border.all(color: GlossaColors.blueNavy, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (SimpleIllustration.supports(imageKey))
              SimpleIllustration(
                imageKey: imageKey!,
                size: constraints.maxWidth < 360 ? 56 : 72,
              )
            else
              Text(
                tile['text'] as String? ?? '',
                textAlign: TextAlign.center,
                softWrap: true,
                style: isRecognition
                    ? GlossaTypography.devanagariMedium
                    : GlossaTypography.headlineSmall,
              ),
            if (isRecognition && tile['roman'] is String) ...[
              const SizedBox(height: 4),
              Text(
                tile['roman'] as String,
                textAlign: TextAlign.center,
                softWrap: true,
                style: GlossaTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      );
      final sentencePrompt = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 5,
        runSpacing: 8,
        children: [
          for (final item in sentence)
            if (item is Map && item['blank'] == true)
              GestureDetector(
                onTap: onClear,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    maxWidth: 180,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: GlossaColors.creamPale,
                    border: const Border(
                      bottom: BorderSide(
                        color: GlossaColors.blueNavy,
                        width: 2,
                      ),
                    ),
                  ),
                  child: selected == null
                      ? const Text('     ')
                      : Text(
                          selected!.text,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: selected!.isDevanagari
                              ? GlossaTypography.devanagariSmall
                              : GlossaTypography.labelMedium,
                        ),
                ),
              )
            else if (item is Map)
              Text(
                item['text']?.toString() ?? '',
                softWrap: true,
                style: GlossaTypography.labelMedium,
              ),
        ],
      );
      if (constraints.maxWidth < 380) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tileCard,
            const SizedBox(height: Spacing.sm),
            sentencePrompt,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 2, child: tileCard),
          const SizedBox(width: Spacing.md),
          Expanded(flex: 3, child: sentencePrompt),
        ],
      );
    },
  );
}

class _PicturePrompt extends StatelessWidget {
  const _PicturePrompt({required this.imageKey});

  final String? imageKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.clamp(120.0, 240.0).toDouble();
      return Center(
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 1.1,
            child: Container(
              decoration: BoxDecoration(
                color: GlossaColors.yellowPrimary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(Spacing.cardRadius),
                border: Border.all(color: GlossaColors.blueNavy, width: 2.5),
              ),
              child: Center(
                child: SimpleIllustration.supports(imageKey)
                    ? SimpleIllustration(
                        imageKey: imageKey!,
                        size: (width * 0.58).clamp(72.0, 128.0).toDouble(),
                      )
                    : const Text(
                        'Illustration unavailable',
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.option,
    required this.selected,
    required this.ghost,
    required this.disabled,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final AnswerOption option;
  final bool selected;
  final bool ghost;
  final bool disabled;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? GlossaColors.successGreen
        : wrong
        ? GlossaColors.redAction
        : GlossaColors.blueNavy;
    return GestureDetector(
      onTap: disabled || ghost ? null : onTap,
      child: Opacity(
        opacity: ghost ? 0.35 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? GlossaColors.yellowPrimary.withValues(alpha: 0.65)
                : GlossaColors.white,
            borderRadius: BorderRadius.circular(Spacing.cardRadius),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (SimpleIllustration.supports(option.imageKey))
                SimpleIllustration(imageKey: option.imageKey!, size: 56)
              else
                Text(
                  option.text,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: option.isDevanagari
                      ? GlossaTypography.devanagariSmall
                      : GlossaTypography.labelMedium,
                ),
              if (option.isDevanagari &&
                  option.romanization != null &&
                  !SimpleIllustration.supports(option.imageKey))
                Text(
                  option.romanization!,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GlossaTypography.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchWordsExercise extends ConsumerStatefulWidget {
  const _MatchWordsExercise({
    super.key,
    required this.exercise,
    required this.onContinue,
  });

  final Exercise exercise;
  final VoidCallback onContinue;

  @override
  ConsumerState<_MatchWordsExercise> createState() =>
      _MatchWordsExerciseState();
}

class _MatchWordsExerciseState extends ConsumerState<_MatchWordsExercise> {
  late final List<AnswerOption> _newari;
  late final List<AnswerOption> _english;
  final Set<String> _matched = {};
  String? _selectedNewari;
  String? _selectedEnglish;
  Map<String, dynamic>? _feedback;
  String? _submissionId;
  String? _error;
  bool _wrongPair = false;
  Timer? _wrongPairTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final restoredPairs =
        ref
            .read(gameStateProvider)
            .matchedPairsByExercise[widget.exercise.id] ??
        const <String, String>{};
    _matched
      ..addAll(restoredPairs.keys)
      ..addAll(restoredPairs.values);
    final shuffled = MatchWordsRandomizer.randomize(
      options: widget.exercise.options,
      random: Random(),
    );
    _newari = shuffled.devanagari;
    _english = shuffled.english;
  }

  Future<void> _checkPair() async {
    if (_selectedNewari == null ||
        _selectedEnglish == null ||
        _checking ||
        _feedback != null) {
      return;
    }
    final devanagariId = _selectedNewari!;
    final englishId = _selectedEnglish!;
    _submissionId ??= _createSubmissionId();
    setState(() => _checking = true);
    try {
      final result = await ref
          .read(gameStateProvider.notifier)
          .submitExerciseAnswer(
            widget.exercise.id,
            submissionId: _submissionId,
            selectedPairs: {devanagariId: englishId},
          );
      if (!mounted) return;
      final pairs = result['matched_pairs'];
      final pairCorrect = result['pair_correct'] == true;
      setState(() {
        if (pairs is Map) {
          _matched
            ..clear()
            ..addAll(pairs.keys.whereType<String>())
            ..addAll(pairs.values.whereType<String>());
        }
        _submissionId = null;
        _error = null;
        if (result['is_final'] == true) _feedback = result;
        _wrongPair = !pairCorrect;
        if (_feedback == null && pairCorrect) {
          _selectedNewari = null;
          _selectedEnglish = null;
        }
      });
      if (!pairCorrect && result['is_final'] != true) {
        _wrongPairTimer?.cancel();
        _wrongPairTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted || _feedback != null) return;
          setState(() {
            _selectedNewari = null;
            _selectedEnglish = null;
            _wrongPair = false;
          });
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to check this pair.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _selectNewari(String id) {
    if (_checking ||
        _feedback != null ||
        _error != null ||
        _wrongPair ||
        _matched.contains(id)) {
      return;
    }
    final selectedId = _selectedNewari == id ? null : id;
    setState(() => _selectedNewari = selectedId);
    if (selectedId != null && _selectedEnglish != null) {
      unawaited(_checkPair());
    }
  }

  void _selectEnglish(String id) {
    if (_checking ||
        _feedback != null ||
        _error != null ||
        _wrongPair ||
        _matched.contains(id)) {
      return;
    }
    final selectedId = _selectedEnglish == id ? null : id;
    setState(() => _selectedEnglish = selectedId);
    if (selectedId != null && _selectedNewari != null) {
      unawaited(_checkPair());
    }
  }

  @override
  void dispose() {
    _wrongPairTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: Spacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Match the words', style: GlossaTypography.headlineLarge),
        const SizedBox(height: Spacing.sm),
        Text(
          '${_matched.length ~/ 2} / ${_newari.length} matched',
          style: GlossaTypography.bodySmall,
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: _newari.map((option) {
                  final matched = _matched.contains(option.id);
                  return _MatchCard(
                    option: option,
                    matched: matched,
                    selected: _selectedNewari == option.id,
                    wrong: _wrongPair && _selectedNewari == option.id,
                    disabled:
                        _checking ||
                        _feedback != null ||
                        _error != null ||
                        _wrongPair,
                    onTap: () => _selectNewari(option.id),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                children: _english.map((option) {
                  return _MatchCard(
                    option: option,
                    matched: _matched.contains(option.id),
                    selected: _selectedEnglish == option.id,
                    wrong: _wrongPair && _selectedEnglish == option.id,
                    disabled:
                        _checking ||
                        _feedback != null ||
                        _error != null ||
                        _wrongPair,
                    onTap: () => _selectEnglish(option.id),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        if (_checking)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          const SizedBox(height: Spacing.md),
          Text(_error!, style: GlossaTypography.bodySmall),
          const SizedBox(height: Spacing.sm),
          GlossaButton(
            label: 'Retry pair',
            style: GlossaButtonStyle.primary,
            onPressed: _submissionId == null ? null : _checkPair,
          ),
        ] else if (_feedback != null) ...[
          const SizedBox(height: Spacing.md),
          Text(
            'All pairs matched. Matching mistakes: '
            '${_feedback!['mistake_count'] ?? 0}.',
            style: GlossaTypography.bodyMedium,
          ),
          const SizedBox(height: Spacing.md),
          GlossaButton(
            label: 'Continue',
            style: GlossaButtonStyle.dark,
            onPressed: widget.onContinue,
          ),
        ],
        const SizedBox(height: Spacing.xl),
      ],
    ),
  );
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.option,
    required this.matched,
    required this.selected,
    required this.wrong,
    required this.disabled,
    required this.onTap,
  });

  final AnswerOption option;
  final bool matched;
  final bool selected;
  final bool wrong;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = matched
        ? GlossaColors.successGreen
        : wrong
        ? GlossaColors.redAction
        : GlossaColors.blueNavy;
    return GestureDetector(
      onTap: disabled || matched ? null : onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 58),
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: matched
              ? GlossaColors.successGreen.withValues(alpha: 0.2)
              : selected
              ? GlossaColors.yellowPrimary.withValues(alpha: 0.65)
              : GlossaColors.white,
          borderRadius: BorderRadius.circular(Spacing.cardRadius),
          border: Border.all(color: border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                option.text,
                textAlign: TextAlign.center,
                softWrap: true,
                style: option.isDevanagari
                    ? GlossaTypography.devanagariSmall
                    : GlossaTypography.labelMedium,
              ),
            ),
            if (option.isDevanagari && option.romanization != null)
              Text(
                option.romanization!,
                textAlign: TextAlign.center,
                softWrap: true,
                style: GlossaTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WordToPictureExercise extends ConsumerStatefulWidget {
  const _WordToPictureExercise({
    super.key,
    required this.exercise,
    required this.review,
    required this.onContinue,
  });

  final Exercise exercise;
  final bool review;
  final VoidCallback onContinue;

  @override
  ConsumerState<_WordToPictureExercise> createState() =>
      _WordToPictureExerciseState();
}

class _WordToPictureExerciseState
    extends ConsumerState<_WordToPictureExercise> {
  String? _selectedId;
  String? _submissionId;
  String? _error;
  Map<String, dynamic>? _feedback;
  bool _checking = false;

  Future<void> _check() async {
    final selectedId = _selectedId;
    if (selectedId == null || _checking || _feedback != null) return;
    _submissionId ??= _createSubmissionId();
    setState(() => _checking = true);
    try {
      final result = await ref
          .read(gameStateProvider.notifier)
          .submitExerciseAnswer(
            widget.exercise.id,
            submissionId: _submissionId,
            review: widget.review,
            selectedOptionId: selectedId,
          );
      if (mounted) {
        setState(() {
          _feedback = result;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to check your answer.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick the picture', style: GlossaTypography.headlineLarge),
          const SizedBox(height: Spacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: GlossaColors.blueNavy,
              borderRadius: BorderRadius.circular(Spacing.cardRadius),
            ),
            child: Column(
              children: [
                Text(
                  exercise.newariScript ?? exercise.prompt ?? '',
                  textAlign: TextAlign.center,
                  style: GlossaTypography.devanagariLarge.copyWith(
                    color: GlossaColors.yellowPrimary,
                  ),
                ),
                if (exercise.romanization != null)
                  Text(
                    exercise.romanization!,
                    style: GlossaTypography.bodySmall.copyWith(
                      color: GlossaColors.white,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final aspectRatio = textScale >= 1.3
                  ? 0.55
                  : constraints.maxWidth < 360
                  ? 0.72
                  : 0.95;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: Spacing.md,
                mainAxisSpacing: Spacing.md,
                childAspectRatio: aspectRatio,
                children: exercise.options.map((option) {
                  final selected = option.id == _selectedId;
                  final correct =
                      (selected && _feedback?['correct'] == true) ||
                      _feedback?['correct_option_id'] == option.id;
                  final wrong = selected && _feedback?['correct'] == false;
                  final color = correct
                      ? GlossaColors.successGreen
                      : wrong
                      ? GlossaColors.redAction
                      : GlossaColors.blueNavy;
                  return GestureDetector(
                    onTap: _feedback != null || _checking || _error != null
                        ? null
                        : () => setState(
                            () => _selectedId = selected ? null : option.id,
                          ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? GlossaColors.yellowPrimary.withValues(alpha: 0.55)
                            : GlossaColors.white,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (SimpleIllustration.supports(option.imageKey))
                            SimpleIllustration(
                              imageKey: option.imageKey!,
                              size: 64,
                            ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            option.text,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GlossaTypography.devanagariSmall,
                          ),
                          if (option.romanization != null)
                            Text(
                              option.romanization!,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GlossaTypography.bodySmall.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: Spacing.lg),
          if (_feedback == null) ...[
            if (_error != null) ...[
              Text(_error!, style: GlossaTypography.bodySmall),
              const SizedBox(height: Spacing.sm),
            ],
            GlossaButton(
              label: _error == null ? 'Check answer' : 'Retry check',
              loadingLabel: 'Checking...',
              style: GlossaButtonStyle.primary,
              onPressed: _selectedId != null && !_checking ? _check : null,
            ),
          ] else ...[
            _AnswerFeedback(
              correct: _feedback!['correct'] as bool,
              answer: _feedback!['correct_answer'] as Map<String, dynamic>?,
            ),
            const SizedBox(height: Spacing.md),
            if (widget.review && _feedback!['correct'] != true)
              GlossaButton(
                label: 'Try Again',
                style: GlossaButtonStyle.dark,
                onPressed: () => setState(() {
                  _selectedId = null;
                  _submissionId = null;
                  _feedback = null;
                  _error = null;
                }),
              )
            else
              GlossaButton(
                label: 'Continue',
                style: GlossaButtonStyle.dark,
                onPressed: widget.onContinue,
              ),
          ],
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.correct, required this.answer});

  final bool correct;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    final pairs = answer?['pairs'] as List? ?? const [];
    final imageKey = answer?['image_key'] as String?;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: correct
            ? GlossaColors.successGreen.withValues(alpha: 0.2)
            : GlossaColors.redAction.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(
          color: correct ? GlossaColors.successGreen : GlossaColors.redAction,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? 'Correct!' : 'The correct answer:',
            softWrap: true,
            style: GlossaTypography.headlineSmall,
          ),
          if (answer != null && pairs.isEmpty) ...[
            const SizedBox(height: Spacing.sm),
            if (SimpleIllustration.supports(imageKey))
              SimpleIllustration(imageKey: imageKey!, size: 64),
            Text(
              answer!['newari']?.toString() ?? '',
              softWrap: true,
              style: GlossaTypography.devanagariMedium,
            ),
            if (answer!['romanization'] is String)
              Text(
                answer!['romanization'] as String,
                softWrap: true,
                style: GlossaTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            Text(answer!['english']?.toString() ?? '', softWrap: true),
          ],
          for (final pair in pairs)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${pair['newari']} (${pair['romanization']}) — ${pair['english']}',
                softWrap: true,
                style: GlossaTypography.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
