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

/// Translate exercise: English → Newari word tiles.
///
/// Shows an English prompt and a set of Newari word tiles. The learner
/// selects tiles in order to build the Newari translation. Repeated words
/// use distinct tile instances; unused distractor tiles may remain
/// unselected.
class TranslateContent extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;

  const TranslateContent({
    super.key,
    required this.exercise,
    required this.onComplete,
  });

  @override
  ConsumerState<TranslateContent> createState() => _TranslateContentState();
}

class _TranslateContentState extends ConsumerState<TranslateContent> {
  final List<String> _selectedTileIds = [];
  final Set<String> _selectedTileIdSet = {};
  bool _submitted = false;
  bool _isChecking = false;
  bool? _isCorrect;

  Exercise get exercise => widget.exercise;
  VoidCallback get onComplete => widget.onComplete;

  List<AnswerOption> get _availableTiles => exercise.wordTiles;
  List<AnswerOption> get _selectedTiles =>
      _availableTiles.where((t) => _selectedTileIdSet.contains(t.id)).toList();

  void _toggleTile(String tileId) {
    if (_submitted || _isChecking) return;
    setState(() {
      if (_selectedTileIdSet.contains(tileId)) {
        _selectedTileIdSet.remove(tileId);
        _selectedTileIds.remove(tileId);
      } else {
        _selectedTileIdSet.add(tileId);
        _selectedTileIds.add(tileId);
      }
    });
  }

  void _reset() {
    setState(() {
      _selectedTileIds.clear();
      _selectedTileIdSet.clear();
      _submitted = false;
      _isCorrect = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedTileIds.isEmpty || _isChecking) return;
    setState(() => _isChecking = true);

    bool correct;
    try {
      correct = await ref
          .read(gameStateProvider.notifier)
          .checkAnswer(exercise.id, selectedTileIds: List.from(_selectedTileIds));
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
          _selectedTileIds.clear();
          _selectedTileIdSet.clear();
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

          // English prompt
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: GlossaColors.creamPale,
              borderRadius: BorderRadius.circular(Spacing.cardRadius),
              border: Border.all(color: GlossaColors.blueNavy, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translate to Newari',
                  style: GlossaTypography.bodySmall,
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  exercise.prompt ?? '',
                  style: GlossaTypography.headlineMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxl),

          // Newari word tiles
          Text(
            'Newari word tiles',
            style: GlossaTypography.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: _availableTiles.map((tile) {
              final isSelected = _selectedTileIdSet.contains(tile.id);
              final tileIndex =
                  _selectedTileIds.indexWhere((id) => id == tile.id);
              final displayOrder = tileIndex >= 0 ? tileIndex + 1 : null;

              Color bg = GlossaColors.white;
              Color border = GlossaColors.blueNavy;
              if (_submitted && _isCorrect == true && isSelected) {
                bg = GlossaColors.successGreen.withValues(alpha: 0.25);
                border = GlossaColors.successGreen;
              } else if (_submitted && _isCorrect == false && isSelected) {
                bg = GlossaColors.redAction.withValues(alpha: 0.15);
                border = GlossaColors.redAction;
              } else if (isSelected) {
                bg = GlossaColors.yellowPrimary.withValues(alpha: 0.6);
              }

              return GestureDetector(
                onTap: () => _toggleTile(tile.id),
                child: AnimatedContainer(
                  duration: GlossaMotion.selection,
                  curve: GlossaMotion.snappy,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(Spacing.cardRadius),
                    border: Border.all(color: border, width: 2.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (displayOrder != null)
                        Text(
                          '$displayOrder',
                          style: GlossaTypography.labelSmall.copyWith(
                            color: GlossaColors.textSubtle,
                            fontSize: 10,
                          ),
                        ),
                      Text(
                        tile.text,
                        style: tile.isDevanagari
                            ? GlossaTypography.devanagariMedium.copyWith(
                                fontSize: 20,
                              )
                            : GlossaTypography.headlineSmall,
                      ),
                      if (tile.isDevanagari && tile.romanization != null && tile.romanization!.isNotEmpty)
                        Text(
                          tile.romanization!,
                          style: GlossaTypography.bodySmall.copyWith(
                            color: GlossaColors.textSubtle,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xl),

          // Selected answer preview
          if (_selectedTiles.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: GlossaColors.creamPale,
                borderRadius: BorderRadius.circular(Spacing.cardRadius),
                border: Border.all(color: GlossaColors.blueNavy, width: 1),
              ),
              child: Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: _selectedTiles.map((tile) {
                  final idx = _selectedTileIds.indexOf(tile.id) + 1;
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
                    onDeleted: () => _toggleTile(tile.id),
                    backgroundColor: GlossaColors.white,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],

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
                      _selectedTileIds.isNotEmpty && !_submitted && !_isChecking
                          ? _submit
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          if (_submitted && _isCorrect == true) ...[
            const XpTipBanner(
              tip: 'Correct! Well done.',
            ),
          ],
        ],
      ),
    );
  }
}
