import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/glossa_colors.dart';
import '../../app/theme/glossa_typography.dart';
import '../constants/spacing.dart';
import 'glossa_button.dart';
import 'greek_key_border.dart';

/// RPG-styled 404 fallback screen for invalid routes.
class NotFoundScreen extends StatelessWidget {
  final String? uri;

  const NotFoundScreen({super.key, this.uri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlossaColors.blueDeep,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const GreekKeyBorder(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.pagePadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: GlossaColors.yellowPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: GlossaColors.blueNavy, width: 3),
                      ),
                      child: const Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: GlossaColors.blueNavy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      'Lost Traveler',
                      style: GlossaTypography.displayMediumOnDark,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      'The path you seek is shrouded in the Fog of Forgetting.',
                      style: GlossaTypography.bodyMediumOnDark,
                      textAlign: TextAlign.center,
                    ),
                    if (uri != null) ...[
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Route: $uri',
                        style: GlossaTypography.bodySmallOnDark,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: Spacing.xxxl),
                    GlossaButton(
                      label: 'Return to Town',
                      style: GlossaButtonStyle.secondary,
                      onPressed: () => context.go(AppRoutes.town),
                    ),
                  ],
                ),
              ),
            ),
            const GreekKeyBorder(),
          ],
        ),
      ),
    );
  }
}
