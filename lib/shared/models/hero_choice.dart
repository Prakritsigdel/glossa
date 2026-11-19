/// A selectable hero character.
class HeroChoice {
  final int index;
  final String label;
  final String description;

  const HeroChoice({
    required this.index,
    required this.label,
    this.description = '',
  });
}

/// A selectable language.
class LanguageChoice {
  final String id;
  final String nameNative;
  final String nameEnglish;
  final String letterSymbol;
  final String subtitle;
  final bool isStarter;

  const LanguageChoice({
    required this.id,
    required this.nameNative,
    required this.nameEnglish,
    required this.letterSymbol,
    this.subtitle = '',
    this.isStarter = false,
  });
}
