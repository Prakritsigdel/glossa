import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/bottom_nav_bar.dart';

/// Persistent shell for the 3 main application tabs (Town, Leaderboard, Profile).
/// Uses [StatefulNavigationShell] to preserve scroll positions and state.
class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          // If user presses Android back while on Leaderboard or Profile, return to Town
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: GlossaBottomNavBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
        ),
      ),
    );
  }
}
