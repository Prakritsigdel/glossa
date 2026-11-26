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

/// DialogueComplete exercise: fill in the missing response line.
///
/// Shows a 2-3 line dialogue with one missing response. The learner selects
/// from response options to complete the dialogue.
class DialogueCompleteContent extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onComplete;

  const DialogueCompleteContent({
    super.key,
    required this.exercise,
    required this.onComplete,
  });

  @override
  ConsumerState<DialogueCompleteContent> createState() =>
      _DialogueCompleteContentState();
}

class _DialogueCompleteContentState
    extends ConsumerState<DialogueCompleteContent> {
  String? _selectedOptionId;
  bool _submitted = false;
  bool _isChecking = false;
  bool? _isCorrect;

  Exercise get exercise => widget.exercise;
  VoidCallback get onComplete => widget.onComplete;

  List<Map<String, dynamic>> get _dialogue => exercise.dialogueStructure ?? [];
  List<AnswerOption> get _options => exercise.options;

  @override
  void initState() {
    super.initState();
  }

  void _selectOption(String id) {
    if (_submitted || _isChecking) return;
    setState(() {
      _selectedOptionId = id;
    });
  }

  Future<void> _submit() async {
    if (_selectedOptionId == null || _isChecking) return;
    setState(() => _isChecking = true);

    bool correct;
    try {
      correct = await ref
          .read(gameStateProvider.notifier)
          .checkAnswer(exercise.id, selectedOptionId: _selectedOptionId);
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
          _selectedOptionId = null;
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

  static bool _containsDevanagari(String text) {
    return text.contains(RegExp(r'[\u0900-\u097F]'));
  }

  Widget _buildDialogueLine(Map<String, dynamic> line, int index) {
    final isMissing = line['missing'] == true;
    final speaker = line['speaker'] ?? '?';
    final text = line['text'] ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: isMissing
            ? GlossaColors.creamPale
            : GlossaColors.white,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(
          color: isMissing
              ? GlossaColors.yellowPrimary
              : GlossaColors.blueNavy,
          width: isMissing ? 3 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isMissing
                      ? GlossaColors.yellowPrimary.withValues(alpha: 0.3)
                      : GlossaColors.blueNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Spacing.cardRadius),
                ),
                child: Text(
                  speaker.toUpperCase(),
                  style: GlossaTypography.labelSmall.copyWith(
                    color: isMissing
                        ? GlossaColors.textDark
                        : GlossaColors.blueNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isMissing) ...[
                const SizedBox(width: Spacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: GlossaColors.redAction.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Spacing.cardRadius),
                  ),
                  child: const Text(
                    'MISSING',
                    style: TextStyle(
                      color: GlossaColors.redAction,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            isMissing ? '___' : text,
            style: _containsDevanagari(text)
                ? GlossaTypography.devanagariMedium.copyWith(fontSize: 20)
                : GlossaTypography.headlineSmall,
          ),
          if (!isMissing && line['romanization'] != null &&
              line['romanization'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                line['romanization'],
                style: GlossaTypography.bodySmall.copyWith(
                  color: GlossaColors.textSubtle,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.instruction, style: GlossaTypography.headlineLarge),
          const SizedBox(height: Spacing.md),

          // Dialogue display
          Text(
            'Dialogue',
            style: GlossaTypography.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          ..._dialogue.asMap().entries.map((entry) {
            return _buildDialogueLine(entry.value, entry.key);
          }),
          const SizedBox(height: Spacing.xxl),

          // Response options
          Text(
            'Select the missing response',
            style: GlossaTypography.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: _options.map((opt) {
              final isSelected = _selectedOptionId == opt.id;
              final isCorrectOpt =
                  _submitted && isSelected && _isCorrect == true;
              final isWrongSelection =
                  _submitted && isSelected && _isCorrect == false;

              Color bg = GlossaColors.white;
              Color border = GlossaColors.blueNavy;
              if (isCorrectOpt && _submitted) {
                bg = GlossaColors.successGreen.withValues(alpha: 0.25);
                border = GlossaColors.successGreen;
              } else if (isWrongSelection) {
                bg = GlossaColors.redAction.withValues(alpha: 0.15);
                border = GlossaColors.redAction;
              } else if (isSelected) {
                bg = GlossaColors.yellowPrimary.withValues(alpha: 0.6);
              }

              return GestureDetector(
                onTap: () => _selectOption(opt.id),
                child: AnimatedContainer(
                  duration: GlossaMotion.selection,
                  curve: GlossaMotion.snappy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(Spacing.cardRadius),
                    border: Border.all(color: border, width: 2.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.text,
                        style: opt.isDevanagari
                            ? GlossaTypography.devanagariMedium.copyWith(
                                fontSize: 16,
                              )
                            : GlossaTypography.labelMedium,
                      ),
                      if (opt.isDevanagari &&
                          opt.romanization != null &&
                          opt.romanization!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            opt.romanization!,
                            style: GlossaTypography.bodySmall.copyWith(
                              color: GlossaColors.textSubtle,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xl),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GlossaButton(
                  label: 'Reset',
                  style: GlossaButtonStyle.secondary,
                  onPressed: _submitted || _isChecking
                      ? null
                      : () => setState(() {
                            _selectedOptionId = null;
                            _submitted = false;
                            _isCorrect = null;
                          }),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: GlossaButton(
                  label: 'Check answer',
                  loadingLabel: 'Checking...',
                  style: GlossaButtonStyle.primary,
                  onPressed:
                      _selectedOptionId != null && !_submitted && !_isChecking
                          ? _submit
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          if (_submitted && _isCorrect == true) ...[
            const XpTipBanner(
              tip: 'Great dialogue response!',
            ),
          ],
        ],
      ),
    );
  }
}
