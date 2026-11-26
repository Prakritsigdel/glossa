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

const List<HeroChoice> heroChoices = [
  HeroChoice(index: 0, label: 'Boy', description: 'A brave young traveler.'),
  HeroChoice(index: 1, label: 'Girl', description: 'A courageous explorer.'),
];
