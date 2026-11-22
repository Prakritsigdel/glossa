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
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/core/widgets/xp_tip_banner.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

import 'lesson_runner_screen.dart';

/// Match words lesson screen â€” tap a Devanagari word then its English pair.
class MatchWordsScreen extends ConsumerStatefulWidget {
  const MatchWordsScreen({super.key});

  @override
  ConsumerState<MatchWordsScreen> createState() => _MatchWordsScreenState();
}

class _MatchWordsScreenState extends ConsumerState<MatchWordsScreen> {
  String? _selectedDevanagariId;
  String? _selectedEnglishId;
  final Set<String> _matchedIds = {};
  String? _wrongPairFlashId; // briefly flash red on wrong
  bool _completing = false; // FIX 4: guard against duplicate completeLesson() calls
  List<_MatchItem> _devanagariItems = [];
  List<_MatchItem> _englishItems = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final exercises = ref.read(gameStateProvider).exercises;
      if (exercises.isNotEmpty) {
        final exercise = exercises.first;
        final randomized = MatchWordsRandomizer.randomize(
          options: exercise.options,
          pairs: exercise.pairs,
        );
        _devanagariItems = randomized.devanagari
            .map((o) => _MatchItem(id: o.id, text: o.text, isDevanagari: true))
            .toList();
        _englishItems = randomized.english
            .map((o) => _MatchItem(id: o.id, text: o.text, isDevanagari: false))
            .toList();
        _initialized = true;
      }
    }
  }

  void _onTapDevanagari(String id) {
    if (_matchedIds.contains(id)) return;
    setState(() {
      _selectedDevanagariId = id;
      _wrongPairFlashId = null;
    });
    _tryMatch();
  }

  void _onTapEnglish(String id) {
    if (_matchedIds.contains(id)) return;
    setState(() {
      _selectedEnglishId = id;
      _wrongPairFlashId = null;
    });
    _tryMatch();
  }

  Future<void> _tryMatch() async {
    if (_selectedDevanagariId == null || _selectedEnglishId == null) return;
    final devanagariId = _selectedDevanagariId!;
    final englishId = _selectedEnglishId!;
    final exerciseId = ref.read(gameStateProvider).exercises.first.id;
    bool correct;
    try {
      correct = await ref
          .read(gameStateProvider.notifier)
          .checkAnswer(exerciseId, selectedPairs: {devanagariId: englishId});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (correct) {
      // Correct match
      setState(() {
        _matchedIds.add(devanagariId);
        _matchedIds.add(englishId);
      });
      ref
          .read(gameStateProvider.notifier)
          .addMatchedPair(devanagariId, englishId);
      _selectedDevanagariId = null;
      _selectedEnglishId = null;

      Future.delayed(const Duration(milliseconds: 400), () async {
        if (!mounted || _completing) return;
        if (_matchedIds.length == _devanagariItems.length * 2) {
          setState(() => _completing = true);
          try {
            await ref.read(gameStateProvider.notifier).completeLesson();
            if (mounted) context.go(AppRoutes.levelUp);
          } catch (error) {
            if (mounted) {
              setState(() => _completing = false);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        }
      });
    } else {
      // Wrong match
      setState(() => _wrongPairFlashId = englishId);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _wrongPairFlashId = null;
          _selectedDevanagariId = null;
          _selectedEnglishId = null;
        });
      });
    }
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave lesson?'),
        content: const Text('Your progress in this lesson will be lost.'),
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

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final progress = _matchedIds.length / (_devanagariItems.length * 2);

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
                // â”€â”€â”€ Lesson header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                _LessonHeader(
                  unitLabel: 'Unit 1',
                  progress: progress,
                  heroIndex: gs.user.heroIndex,
                  level: gs.user.level,
                  onClose: _showLeaveDialog,
                ),
                const SizedBox(height: Spacing.xl),

                // â”€â”€â”€ Instruction â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Text('Match the words', style: GlossaTypography.headlineLarge),
                const SizedBox(height: Spacing.md),

                // â”€â”€â”€ Audio pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: GlossaColors.yellowPrimary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GlossaColors.blueNavy, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.volume_up_rounded,
                        color: GlossaColors.blueNavy,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hear the voice',
                        style: GlossaTypography.labelMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                // â”€â”€â”€ Match grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (int i = 0; i < _devanagariItems.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.md),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _MatchChip(
                                    text: _devanagariItems[i].text,
                                    isDevanagari: true,
                                    isMatched: _matchedIds.contains(
                                      _devanagariItems[i].id,
                                    ),
                                    isSelected:
                                        _selectedDevanagariId ==
                                        _devanagariItems[i].id,
                                    isWrong: false,
                                    onTap: () => _onTapDevanagari(
                                      _devanagariItems[i].id,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: _MatchChip(
                                    text: _englishItems[i].text,
                                    isDevanagari: false,
                                    isMatched: _matchedIds.contains(
                                      _englishItems[i].id,
                                    ),
                                    isSelected:
                                        _selectedEnglishId ==
                                        _englishItems[i].id,
                                    isWrong:
                                        _wrongPairFlashId ==
                                        _englishItems[i].id,
                                    onTap: () =>
                                        _onTapEnglish(_englishItems[i].id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: Spacing.lg),
                        const XpTipBanner(
                          tip: 'Match words faster to earn streak bonuses!',
                        ),
                      ],
                    ),
                  ),
                ),

                // â”€â”€â”€ Bottom action â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xl),
                  child: GlossaButton(
                    label: 'Attack!',
                    style: GlossaButtonStyle.dark,
                    onPressed: _matchedIds.length == _devanagariItems.length * 2
                        && !_completing
                        ? () async {
                            if (_completing) return;
                            setState(() => _completing = true);
                            try {
                              await ref
                                  .read(gameStateProvider.notifier)
                                  .completeLesson();
                              if (context.mounted) {
                                context.go(AppRoutes.levelUp);
                              }
                            } catch (error) {
                              if (context.mounted) {
                                setState(() => _completing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          }
                        : null,
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

class _MatchItem {
  final String id;
  final String text;
  final bool isDevanagari;
  _MatchItem({
    required this.id,
    required this.text,
    required this.isDevanagari,
  });
}

class _MatchChip extends StatelessWidget {
  final String text;
  final bool isDevanagari;
  final bool isMatched;
  final bool isSelected;
  final bool isWrong;
  final VoidCallback onTap;

  const _MatchChip({
    required this.text,
    required this.isDevanagari,
    required this.isMatched,
    required this.isSelected,
    required this.isWrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    if (isMatched) {
      bgColor = GlossaColors.successGreen.withValues(alpha: 0.2);
      borderColor = GlossaColors.successGreen;
    } else if (isWrong) {
      bgColor = GlossaColors.redAction.withValues(alpha: 0.15);
      borderColor = GlossaColors.redAction;
    } else if (isSelected) {
      bgColor = GlossaColors.yellowPrimary.withValues(alpha: 0.6);
      borderColor = GlossaColors.blueNavy;
    } else {
      bgColor = GlossaColors.white;
      borderColor = GlossaColors.blueNavy;
    }

    Widget chipContent = AnimatedContainer(
      duration: GlossaMotion.selection,
      curve: GlossaMotion.snappy,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: isSelected ? GlossaColors.blueNavy : GlossaColors.cardShadow,
            offset: isSelected ? const Offset(0, 3) : const Offset(0, 2),
            blurRadius: isSelected ? 0 : 3,
          ),
        ],
      ),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: GlossaMotion.selection,
          style: isDevanagari
              ? GlossaTypography.devanagariSmall.copyWith(
                  color: isMatched
                      ? GlossaColors.successGreen
                      : GlossaColors.textDark,
                )
              : GlossaTypography.headlineSmall.copyWith(
                  color: isMatched
                      ? GlossaColors.successGreen
                      : GlossaColors.textDark,
                ),
          child: Text(text),
        ),
      ),
    );

    if (isWrong) {
      chipContent = ShakeWidget(deltaX: 6.0, child: chipContent);
    }

    return GestureDetector(
      onTap: isMatched ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: GlossaMotion.selection,
        opacity: isMatched ? 0.75 : 1.0,
        child: chipContent,
      ),
    );
  }
}

/// Shared lesson header used across all lesson screens.
class _LessonHeader extends StatelessWidget {
  final String unitLabel;
  final double progress;
  final int heroIndex;
  final int level;
  final VoidCallback onClose;

  const _LessonHeader({
    required this.unitLabel,
    required this.progress,
    required this.heroIndex,
    required this.level,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: GlossaColors.blueDeep.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GlossaColors.blueDeep, width: 1.5),
          ),
          child: Text(
            unitLabel,
            style: GlossaTypography.labelSmall.copyWith(
              color: GlossaColors.blueDeep,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            GestureDetector(
              onTap: onClose,
              child: const Icon(
                Icons.close_rounded,
                color: GlossaColors.blueNavy,
                size: 28,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(child: LessonProgressBar(progress: progress)),
            const SizedBox(width: Spacing.sm),
            HeroAvatar(heroIndex: heroIndex, level: level, size: 40),
          ],
        ),
      ],
    );
  }
}


