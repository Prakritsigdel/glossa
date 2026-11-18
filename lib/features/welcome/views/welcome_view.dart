import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/welcome_controller.dart';

/// Welcome landing page styled to match the supplied Glossa design.
class WelcomeView extends ConsumerWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSavedJourney = ref.watch(
      welcomeControllerProvider.select((model) => model.hasSavedJourney),
    );

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          // Pattern positioned at the very top
          const Positioned(
            top: 5,
            left: 5,
            right: 5,
            child: _TopPattern(),
          ),

          // Main screen content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _BrandArtwork(),
                              const SizedBox(height: 4),
                              const _Intro(),
                              const SizedBox(height: 14),
                              const _AudioPreview(),
                              const SizedBox(height: 12),
                              _WelcomeActions(
                                hasSavedJourney: hasSavedJourney,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Positioned(
            bottom: 5,
            left: 5,
            right: 5,
            child: _TopPattern(),
          ),
        ],
      ),
    );
  }
}

class _TopPattern extends StatelessWidget {
  const _TopPattern();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 10,
        width: double.infinity,
        child: CustomPaint(painter: _PatternPainter()),
      );
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.butter
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const cell = 13.0;
    for (double x = 0; x < size.width; x += cell) {
      final path = Path()
        ..moveTo(x + 1, 1)
        ..lineTo(x + 1, 8)
        ..lineTo(x + 9, 8)
        ..lineTo(x + 9, 3)
        ..lineTo(x + 5, 3);
      canvas.drawPath(path, paint);
    }
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) => false;
}

class _BrandArtwork extends StatelessWidget {
  const _BrandArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 7,
              top: 10,
              child: Text(
                'ग्लोसा',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 180,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -8,
                  color: AppColors.butter,
                ),
              ),
            ),
            Positioned(
              left: 1,
              top: 0,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: const [
                    BoxShadow(color: AppColors.navyDeep, offset: Offset(2, 3)),
                  ],
                ),
                child: const Icon(
                  Icons.mark_chat_unread_rounded,
                  color: AppColors.navy,
                  size: 25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hear the\nlanguage of\nhome.',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 36,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
              color: AppColors.cream,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Short lessons built on real recordings of\nnative speakers.',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: AppColors.cream,
            ),
          ),
        ],
      );
}

class _AudioPreview extends StatelessWidget {
  const _AudioPreview();

  static const _barHeights = <double>[
    8,
    13,
    18,
    10,
    23,
    15,
    9,
    20,
    14,
    24,
    11,
    17,
    8,
    21,
    13,
    18,
    10,
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.navyDeep, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.navyDeep, offset: Offset(2, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.navyDeep, width: 1.5),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final height in _barHeights)
                    Container(
                      width: 2.5,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'भाय्',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.navyDeep,
              ),
            ),
          ],
        ),
      );
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({required this.hasSavedJourney});

  final bool hasSavedJourney;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WelcomeButton(
            label: 'New Game',
            fill: AppColors.red,
            foreground: Colors.white,
            onPressed: () => context.push(AppRoutes.character),
          ),
          const SizedBox(height: 8),
          _WelcomeButton(
            label: 'Continue (load save)',
            fill: AppColors.butter,
            foreground: AppColors.navyDeep,
            onPressed:
                hasSavedJourney ? () => context.push(AppRoutes.home) : null,
          ),
        ],
      );
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.fill,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color fill;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height:55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.navyDeep,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: AppColors.navyDeep, offset: Offset(2, 3)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: Material(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
