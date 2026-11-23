import 'package:material_ui/material_ui.dart';
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
import 'package:glossa_app/core/widgets/simple_illustration.dart';
import 'package:glossa_app/core/widgets/xp_tip_banner.dart';
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

/// Word to picture lesson — show a word, pick the correct picture.
class WordToPictureScreen extends ConsumerStatefulWidget {
  const WordToPictureScreen({super.key});

  @override
  ConsumerState<WordToPictureScreen> createState() =>
      _WordToPictureScreenState();
}

class _WordToPictureScreenState extends ConsumerState<WordToPictureScreen> {
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  late Exercise _exercise;
  String? _selectedOptionId;
  bool? _isCorrect;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _exercise = ref.read(gameStateProvider).exercises.first;
  }

  void _selectOption(String id) {
    if (_submitted) return;
    setState(() {
      _selectedOptionId = id;
      _isCorrect = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedOptionId == null) return;
    bool correct;
    try {
      correct = await ref
          .read(gameStateProvider.notifier)
          .checkAnswer(_exercise.id, selectedOptionId: _selectedOptionId);
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
        try {
          await ref.read(gameStateProvider.notifier).completeLesson();
          if (mounted) context.go(AppRoutes.levelUp);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.toString())));
          }
        }
      } else {
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
                _buildHeader(gs),
                const SizedBox(height: Spacing.xl),

                Text('Pick the picture', style: GlossaTypography.headlineLarge),
                const SizedBox(height: Spacing.lg),

                // ─── Word prompt card ───────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.xl),
                  decoration: BoxDecoration(
                    color: GlossaColors.blueNavy,
                    borderRadius: BorderRadius.circular(Spacing.cardRadius),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Show the Devanagari prompt for the correct answer
                      Text(
                        'ल', // The Devanagari for "House"
                        style: GlossaTypography.devanagariLarge.copyWith(
                          color: GlossaColors.yellowPrimary,
                        ),
                      ),
                      const SizedBox(width: Spacing.lg),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: GlossaColors.blueDeep,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: GlossaColors.yellowPrimary,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          color: GlossaColors.yellowPrimary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xxl),

                // ─── 2×2 picture grid ───────────────
                Expanded(
                  child: ShakeWidget(
                    key: _shakeKey,
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: Spacing.md,
                      mainAxisSpacing: Spacing.md,
                      childAspectRatio: 1.0,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _exercise.options.map((opt) {
                        final isSelected = _selectedOptionId == opt.id;
                        final isCorrectOpt =
                            _submitted && isSelected && _isCorrect == true;
                        final isWrongSelection =
                            _submitted && isSelected && _isCorrect == false;

                        Color bg = GlossaColors.white;
                        Color border = GlossaColors.blueNavy;
                        if (isCorrectOpt && _submitted) {
                          bg = GlossaColors.successGreen.withValues(
                            alpha: 0.25,
                          );
                          border = GlossaColors.successGreen;
                        } else if (isWrongSelection) {
                          bg = GlossaColors.redAction.withValues(alpha: 0.15);
                          border = GlossaColors.redAction;
                        } else if (isSelected) {
                          bg = GlossaColors.yellowPrimary.withValues(
                            alpha: 0.6,
                          );
                        }

                        return GestureDetector(
                          onTap: () => _selectOption(opt.id),
                          child: AnimatedContainer(
                            duration: GlossaMotion.selection,
                            curve: GlossaMotion.snappy,
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(
                                Spacing.cardRadius,
                              ),
                              border: Border.all(color: border, width: 2.5),
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SimpleIllustration(
                                  imageKey: opt.imageKey ?? 'house',
                                  size: 60,
                                ),
                                const SizedBox(height: Spacing.sm),
                                Text(
                                  opt.text,
                                  style: GlossaTypography.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const XpTipBanner(tip: 'Listen to the word and match it!'),
                const SizedBox(height: Spacing.md),

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

  Widget _buildHeader(GameState gs) {
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
            Expanded(child: LessonProgressBar(progress: 0.6)),
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
