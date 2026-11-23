import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/motion/glossa_motion.dart';
import 'package:glossa_app/core/motion/motion_widgets.dart';
import 'package:glossa_app/core/widgets/audio_waveform.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

/// Fill in the blank lesson screen with interactive feedback & animated question transitions.
class FillBlankScreen extends ConsumerStatefulWidget {
  const FillBlankScreen({super.key});

  @override
  ConsumerState<FillBlankScreen> createState() => _FillBlankScreenState();
}

class _FillBlankScreenState extends ConsumerState<FillBlankScreen> {
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  late List<Exercise> _exercises;
  int _exerciseIndex = 0;
  String? _selectedOptionId;
  bool? _isCorrect; // null = not answered, true/false
  bool _submitted = false;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _exercises = ref.read(gameStateProvider).exercises;
  }

  Exercise get _current => _exercises[_exerciseIndex];

  void _selectOption(String id) {
    if (_submitted) return;
    setState(() {
      _selectedOptionId = id;
      _isCorrect = null;
    });
  }

  void _toggleAudio() {
    setState(() => _isPlayingAudio = !_isPlayingAudio);
    if (_isPlayingAudio) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isPlayingAudio) {
          setState(() => _isPlayingAudio = false);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedOptionId == null) return;
    bool correct;
    try {
      correct = await ref
          .read(gameStateProvider.notifier)
          .checkAnswer(_current.id, selectedOptionId: _selectedOptionId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });

    if (!correct) {
      _shakeKey.currentState?.shake();
    }

    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      if (correct) {
        if (_exerciseIndex < _exercises.length - 1) {
          setState(() {
            _exerciseIndex++;
            _selectedOptionId = null;
            _isCorrect = null;
            _submitted = false;
            _isPlayingAudio = false;
          });
          ref.read(gameStateProvider.notifier).nextExercise();
        } else {
          try {
            await ref.read(gameStateProvider.notifier).completeLesson();
            if (mounted) {
              context.go(AppRoutes.levelUp);
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        }
      } else {
        // Allow retry on wrong answer
        setState(() {
          _selectedOptionId = null;
          _isCorrect = null;
          _submitted = false;
        });
      }
    });
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
    final progress = (_exerciseIndex + 1) / _exercises.length;

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
                // ─── Header ─────────────────────────
                _buildHeader(gs, progress),
                const SizedBox(height: Spacing.xl),

                Text('Around the House', style: GlossaTypography.headlineLarge),
                const SizedBox(height: Spacing.lg),

                // ─── Audio card ─────────────────────
                GestureDetector(
                  onTap: _toggleAudio,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(
                      color: GlossaColors.white,
                      borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      border: Border.all(
                        color: GlossaColors.blueNavy,
                        width: 2.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isPlayingAudio
                                ? GlossaColors.redAction
                                : GlossaColors.blueDeep,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isPlayingAudio
                                ? Icons.pause_rounded
                                : Icons.volume_up_rounded,
                            color: GlossaColors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: AudioWaveform(
                            isPlaying: _isPlayingAudio,
                            height: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                // ─── Animated Question Container ────
                AnimatedSwitcher(
                  duration: GlossaMotion.pageTransition,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.08, 0.0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_exerciseIndex),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sentence card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Spacing.lg),
                          decoration: BoxDecoration(
                            color: GlossaColors.creamPale,
                            borderRadius: BorderRadius.circular(
                              Spacing.cardRadius,
                            ),
                            border: Border.all(
                              color: GlossaColors.blueNavy,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _current.prompt ?? 'दौ ___',
                                style: GlossaTypography.devanagariMedium
                                    .copyWith(fontSize: 28),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Text(
                                _current.promptHint ?? '',
                                style: GlossaTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Spacing.xxl),

                        // Answer chips wrapped in ShakeWidget
                        Text(
                          _current.instruction,
                          style: GlossaTypography.headlineSmall,
                        ),
                        const SizedBox(height: Spacing.md),
                        ShakeWidget(
                          key: _shakeKey,
                          child: Wrap(
                            spacing: Spacing.md,
                            runSpacing: Spacing.md,
                            children: _current.options.map((opt) {
                              final isSelected = _selectedOptionId == opt.id;
                              final isCorrectOption =
                                  _submitted &&
                                  isSelected &&
                                  _isCorrect == true;
                              final isWrongSelection =
                                  _submitted &&
                                  isSelected &&
                                  _isCorrect == false;

                              Color bg = GlossaColors.white;
                              Color border = GlossaColors.blueNavy;
                              if (isCorrectOption && _submitted) {
                                bg = GlossaColors.successGreen.withValues(
                                  alpha: 0.25,
                                );
                                border = GlossaColors.successGreen;
                              } else if (isWrongSelection) {
                                bg = GlossaColors.redAction.withValues(
                                  alpha: 0.15,
                                );
                                border = GlossaColors.redAction;
                              } else if (isSelected) {
                                bg = GlossaColors.yellowPrimary.withValues(
                                  alpha: 0.6,
                                );
                                border = GlossaColors.blueNavy;
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
                                    borderRadius: BorderRadius.circular(
                                      Spacing.cardRadius,
                                    ),
                                    border: Border.all(
                                      color: border,
                                      width: 2.5,
                                    ),
                                    boxShadow: isSelected
                                        ? const [
                                            BoxShadow(
                                              color: GlossaColors.blueNavy,
                                              offset: Offset(0, 2),
                                              blurRadius: 0,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    opt.text,
                                    style: opt.isDevanagari
                                        ? GlossaTypography.devanagariSmall
                                        : GlossaTypography.headlineSmall,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ─── Submit ─────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xl),
                  child: GlossaButton(
                    label: 'Cast answer',
                    style: GlossaButtonStyle.primary,
                    onPressed: _selectedOptionId != null && !_submitted
                        ? _submit
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

  Widget _buildHeader(GameState gs, double progress) {
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
            'Unit 1',
            style: GlossaTypography.labelSmall.copyWith(
              color: GlossaColors.blueDeep,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
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
            Expanded(child: LessonProgressBar(progress: progress)),
            const SizedBox(width: Spacing.sm),
            HeroAvatar(
              heroIndex: gs.user.heroIndex,
              level: gs.user.level,
              size: 40,
              animateIdle: true,
            ),
          ],
        ),
      ],
    );
  }
}
