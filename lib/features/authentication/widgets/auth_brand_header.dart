import 'package:flutter/material.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/widgets/logo_widget.dart';

/// Shared welcome artwork used at the top of the login and signup screens.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 280,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -94,
                top: 3,
                child: Text(
                  'भाय्',
                  style: const TextStyle(
                    fontFamily: GlossaTypography.devanagariFontFamily,
                    fontSize: 200,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: GlossaColors.yellowPrimary,
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                top: 12,
                child: GlossaAppIcon(size: 48),
              ),
            ],
          ),
        ),
        Text(
          'Hear the language of home.',
          style: GlossaTypography.displayLargeOnDark.copyWith(
            color: GlossaColors.yellowPrimary,
            fontSize: 42,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Short lessons built on real recordings of native speakers.',
          style: GlossaTypography.bodySmall.copyWith(
            color: GlossaColors.white,
            height: 1.25,
            fontSize: 13.5
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: GlossaColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GlossaColors.blueNavy, width: 2),
            boxShadow: const [
              BoxShadow(
                color: GlossaColors.blueNavy,
                offset: Offset(2, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: GlossaColors.redAction,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: GlossaColors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Short values (6) render as dots; taller ones as bars.
                    for (final h in const <double>[
                      6, 22, 30, 24, 6, 26, 32, 22, 6, 28, 6, 20,
                    ])
                      Container(
                        width: 6,
                        height: h,
                        decoration: BoxDecoration(
                          color: GlossaColors.redAction,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'भाय्',
                style: TextStyle(
                  fontFamily: GlossaTypography.devanagariFontFamily,
                  fontWeight: FontWeight.w800,
                  color: GlossaColors.blueNavy,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}