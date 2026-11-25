import 'package:flutter/material.dart';

import '../../app/theme/glossa_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/spacing.dart';
import '../motion/motion_widgets.dart';

/// Returns the sprite for a hero's gender and current level.
///
/// The character sheet defines appearance changes at levels 1, 3, 5, and 10.
/// Girl Lv10 art is not included yet, so girl heroes retain the Lv5 sprite.
String heroSpriteAsset(int heroIndex, int level) {
  final isGirl = heroIndex == 1;
  if (level >= 10) {
    return isGirl ? AssetPaths.heroGirlLv5 : AssetPaths.heroBoyLv10;
  }
  if (level >= 5) {
    return isGirl ? AssetPaths.heroGirlLv5 : AssetPaths.heroBoyLv5;
  }
  if (level >= 3) {
    return isGirl ? AssetPaths.heroGirlLv3 : AssetPaths.heroBoyLv3;
  }
  return isGirl ? AssetPaths.heroGirlLv1 : AssetPaths.heroBoyLv1;
}

/// Pixel-art style hero avatar that changes appearance as the hero levels up.
class HeroAvatar extends StatelessWidget {
  final int heroIndex; // 0 = boy, 1 = girl
  final int level;
  final double size;
  final bool showBorder;
  final bool animateIdle;

  const HeroAvatar({
    super.key,
    this.heroIndex = 0,
    this.level = 1,
    this.size = 60,
    this.showBorder = true,
    this.animateIdle = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = ClipRRect(
      borderRadius: BorderRadius.circular(Spacing.cardRadius - 2),
      child: SizedBox.expand(
        child: Image.asset(
          heroSpriteAsset(heroIndex, level),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
        ),
      ),
    );

    if (animateIdle) {
      avatar = IdleBobbing(offsetDistance: 2.5, child: avatar);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GlossaColors.yellowPrimary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: showBorder
            ? Border.all(color: GlossaColors.blueNavy, width: 2)
            : null,
      ),
      child: avatar,
    );
  }
}

/// Large hero avatar for character selection and profile views.
class HeroAvatarLarge extends StatelessWidget {
  final int heroIndex;
  final int level;
  final double size;
  final bool animateIdle;

  const HeroAvatarLarge({
    super.key,
    this.heroIndex = 0,
    this.level = 1,
    this.size = 120,
    this.animateIdle = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = Image.asset(
      heroSpriteAsset(heroIndex, level),
      width: size,
      height: size + 20,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );

    if (animateIdle) {
      avatar = IdleBobbing(offsetDistance: 3.5, child: avatar);
    }

    return Container(
      width: size,
      height: size + 20,
      decoration: BoxDecoration(
        color: GlossaColors.yellowPrimary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
      ),
      child: avatar,
    );
  }
}
