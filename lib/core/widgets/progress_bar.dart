import 'package:material_ui/material_ui.dart';
import '../../app/theme/glossa_colors.dart';
import '../motion/glossa_motion.dart';

/// Segmented progress bar with colored filled blocks (used in loading screens).
class SegmentedProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final int totalSegments;
  final Color filledColor;
  final Color emptyColor;
  final double height;

  const SegmentedProgressBar({
    super.key,
    required this.progress,
    this.totalSegments = 10,
    this.filledColor = GlossaColors.redAction,
    this.emptyColor = GlossaColors.disabledGray,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context) {
    final filledCount = (progress * totalSegments).round().clamp(0, totalSegments);
    return Row(
      children: List.generate(totalSegments, (i) {
        final isFilled = i < filledCount;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: height,
            margin: EdgeInsets.only(right: i < totalSegments - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: isFilled ? filledColor : emptyColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

/// Linear XP/lesson progress bar with rounded ends.
/// Smoothly animates fill changes over [GlossaMotion.xpFill].
class GlossaProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color fillColor;
  final Color trackColor;
  final double height;
  final Duration animationDuration;

  const GlossaProgressBar({
    super.key,
    required this.progress,
    this.fillColor = GlossaColors.redAction,
    this.trackColor = GlossaColors.progressTrack,
    this.height = 10,
    this.animationDuration = GlossaMotion.xpFill,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = GlossaMotion.shouldReduceMotion(context);
    final target = progress.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: target),
          duration: reduceMotion ? Duration.zero : animationDuration,
          curve: GlossaMotion.progress,
          builder: (context, animValue, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: animValue.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Two-tone progress bar used in lesson header (red filled / blue track).
class LessonProgressBar extends StatelessWidget {
  final double progress;

  const LessonProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return GlossaProgressBar(
      progress: progress,
      fillColor: GlossaColors.redAction,
      trackColor: GlossaColors.blueDeep.withValues(alpha: 0.3),
      height: 12,
      animationDuration: const Duration(milliseconds: 350),
    );
  }
}
