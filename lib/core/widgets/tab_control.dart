import 'package:material_ui/material_ui.dart';
import '../../app/theme/glossa_colors.dart';
import '../../app/theme/glossa_typography.dart';
import '../../core/constants/spacing.dart';

/// Segmented tab control used in auth screens (New game / Load game).
class GlossaTabControl extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const GlossaTabControl({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GlossaColors.white,
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(color: GlossaColors.blueNavy, width: 2),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? GlossaColors.blueNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(Spacing.cardRadius - 4),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: GlossaTypography.labelMedium.copyWith(
                      color: isSelected ? GlossaColors.white : GlossaColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
