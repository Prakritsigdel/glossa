import 'package:flutter/material.dart';

/// Placeholder pixel-art learner (16x18). Replace with the Figma character
/// art once exported; the PixelSprite widget can be swapped for an Image.
abstract final class LearnerSprite {
  // . = transparent, K = outline, H = hair, S = skin, R = red, Y = yellow,
  // B = blue
  static const boy = <String>[
    '....KKKKKKKK....',
    '...KHHHHHHHHK...',
    '..KHHHHHHHHHHK..',
    '..KHHSSSSSSHHK..',
    '..KHSSSSSSSSHK..',
    '..KSSKSSSSKSSK..',
    '..KSSSSSSSSSSK..',
    '...KSSSKKSSSK...',
    '....KKSSSSKK....',
    '...KRRKSSKRRK...',
    '..KRRRRRRRRRRK..',
    '..KRRRYYYYRRRK..',
    '..KSRRYYYYRRSK..',
    '..KSKRRRRRRKSK..',
    '...KKBBBBBBKK...',
    '....KBBKKBBK....',
    '....KBBK.KBBK...',
    '....KKKK.KKKK...',
  ];

  static const palette = <String, Color>{
    'K': Color(0xFF050D24),
    'H': Color(0xFF4A2F22),
    'S': Color(0xFFF2B27A),
    'R': Color(0xFFE5383B),
    'Y': Color(0xFFFFE08A),
    'B': Color(0xFF2F5DA8),
  };
}
