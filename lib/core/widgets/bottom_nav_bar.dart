import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/glossa_colors.dart';
import '../../app/theme/glossa_typography.dart';
import '../../app/router/app_router.dart';

/// Bottom navigation bar with three tabs: Town, Leaderboard, Hero.
class GlossaBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const GlossaBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  void _handleTap(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
    } else {
      switch (index) {
        case 0:
          context.go(AppRoutes.town);
          break;
        case 1:
          context.go(AppRoutes.leaderboard);
          break;
        case 2:
          context.go(AppRoutes.profile);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GlossaColors.creamPale,
        border: Border(
          top: BorderSide(color: GlossaColors.blueNavy, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                label: 'Town',
                icon: Icons.home_rounded,
                isSelected: currentIndex == 0,
                onTap: () => _handleTap(context, 0),
              ),
              _NavItem(
                label: 'Leaderboard',
                icon: Icons.leaderboard_rounded,
                isSelected: currentIndex == 1,
                onTap: () => _handleTap(context, 1),
              ),
              _NavItem(
                label: 'Hero',
                icon: Icons.person_rounded,
                isSelected: currentIndex == 2,
                onTap: () => _handleTap(context, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: GlossaColors.yellowPrimary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GlossaColors.blueNavy, width: 2),
              )
            : null,
        child: Text(
          label,
          style: GlossaTypography.labelMedium.copyWith(
            color: isSelected ? GlossaColors.textDark : GlossaColors.textSubtle,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
