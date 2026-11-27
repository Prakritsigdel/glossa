import 'package:flutter/material.dart';
import '../constants/assets.dart';

/// Small app icon, loaded from the real logo image.
class GlossaAppIcon extends StatelessWidget {
  final double size;

  const GlossaAppIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Image.asset(
        AssetPaths.logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

