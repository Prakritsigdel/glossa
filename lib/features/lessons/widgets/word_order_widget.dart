import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/xp_tip_banner.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

/// WordOrder exercise: scrambled Newari word tiles → ordered sentence.
///
/// Shows scrambled Newari word tiles with romanization. The learner taps
/// tiles to build the ordered sentence, then submits for validation.
/// Repeated words use distinct tile instances.
class WordOrderContent extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;

  const WordOrderContent({
    super.key,
    required this.exercise,
    required this.onComplete,
  });

  @override
  ConsumerState<WordOrderContent> createState() => _WordOrderState();
}

class _WordOrderState extends ConsumerState<WordOrderContent> {
  final List<String> _orderedTileIds = [];
  final Set<String> _selectedIdSet = {};
  bool _submitted = false;
  bool _isChecking = false;
  bool? _isCorrect;

  Exercise get exercise => widget.exercise;
  VoidCallback get onComplete => widget.onComplete;

  List<AnswerOption> get _availableTiles => exercise.wordTiles;
  List<AnswerOption> get _orderedTiles =>
      _availableTiles.where((t) => _selectedIdSet.contains(t.id)).toList();

  void _addTile(String tileId) {
    if (_submitted || _isChecking) return;
    if (_selectedIdSet.contains(tileId)) return;
    setState(() {
      _selectedIdSet.add(tileId);
      _orderedTileIds.add(tileId);
    });
  }

  void _removeTile(String tileId) {
    if (_submitted || _isChecking) return;
    setState(() {
      _selectedIdSet.remove(tileId);
      _orderedTileIds.remove(tileId);
    });
  }

  void _reset() {
    setState(() {
      _orderedTileIds.clear();
      _selectedIdSet.clear();
      _submitted = false;
      _isCorrect = null;
    });
  }

  Future<void> _submit() async {
    if (_orderedTileIds.isEmpty || _isChecking) return;
    setState(() => _isChecking = true);

    bool correct;
    try {
      correct = await ref
          .read(gameStateProvider.notifier)
          .checkAnswer(exercise.id, selectedTileIds: List.from(_orderedTileIds));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }

    if (!mounted) return;
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });

    if (!correct) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _orderedTileIds.clear();
          _selectedIdSet.clear();
          _submitted = false;
          _isCorrect = null;
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) onComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.instruction, style: GlossaTypography.headlineLarge),
          const SizedBox(height: Spacing.md),

          // Available (scrambled) tiles
          Text(
            'Scrambled tiles — tap to add to sentence',
            style: GlossaTypography.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: _availableTiles.map((tile) {
              final alreadySelected = _selectedIdSet.contains(tile.id);
              Color bg = alreadySelected
                  ? GlossaColors.successGreen.withValues(alpha: 0.25)
                  : GlossaColors.white;
              Color border = alreadySelected
                  ? GlossaColors.successGreen
                  : GlossaColors.blueNavy;

              return GestureDetector(
                onTap: alreadySelected ? null : () => _addTile(tile.id),
                child: AnimatedContainer(
                  duration: GlossaMotion.selection,
                  curve: GlossaMotion.snappy,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(Spacing.cardRadius),
                    border: Border.all(color: border, width: 2.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tile.text,
                          style: tile.isDevanagari
                              ? GlossaTypography.devanagariMedium.copyWith(
                                  fontSize: 20,
                                )
                              : GlossaTypography.headlineSmall,
                        ),
                        if (tile.isDevanagari &&
                            tile.romanization != null &&
                            tile.romanization!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              tile.romanization!,
                              style: GlossaTypography.bodySmall.copyWith(
                                color: GlossaColors.textSubtle,
                                fontStyle: FontStyle.italic,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xxl),

          // Ordered sentence area
          Text(
            'Your sentence',
            style: GlossaTypography.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: GlossaColors.creamPale,
              borderRadius: BorderRadius.circular(Spacing.cardRadius),
              border: Border.all(color: GlossaColors.blueNavy, width: 2),
            ),
            child: _orderedTiles.isEmpty
                ? Center(
                    child: Text(
                      'Tap tiles above to build the sentence',
                      style: GlossaTypography.bodySmall.copyWith(
                        color: GlossaColors.textSubtle,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: Spacing.md,
                    runSpacing: Spacing.md,
                    children: _orderedTiles.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final tile = entry.value;
                      return Chip(
                        label: Text(
                          '$idx. ${tile.text}',
                          style: tile.isDevanagari
                              ? GlossaTypography.devanagariSmall.copyWith(
                                  fontSize: 14,
                                )
                              : GlossaTypography.labelMedium,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeTile(tile.id),
                        backgroundColor: GlossaColors.white,
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: Spacing.xl),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GlossaButton(
                  label: 'Reset',
                  style: GlossaButtonStyle.secondary,
                  onPressed: _submitted || _isChecking ? null : _reset,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: GlossaButton(
                  label: 'Check answer',
                  loadingLabel: 'Checking...',
                  style: GlossaButtonStyle.primary,
                  onPressed:
                      _orderedTileIds.isNotEmpty && !_submitted && !_isChecking
                          ? _submit
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          if (_submitted && _isCorrect == true) ...[
            const XpTipBanner(
              tip: 'Correct sentence order!',
            ),
          ],
        ],
      ),
    );
  }
}
