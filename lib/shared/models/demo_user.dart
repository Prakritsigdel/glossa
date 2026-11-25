/// Represents the demo user / player state.
class DemoUser {
  final String id;
  final String name;
  final String email;
  final int heroIndex; // 0 = boy, 1 = girl
  final String heroClassName;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int streak;
  final int wordsFound;
  final int lessonsCompleted;
  final String? activeCourseId;

  const DemoUser({
    required this.id,
    required this.name,
    required this.email,
    this.heroIndex = 0,
    this.heroClassName = 'Traveler',
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 100,
    this.streak = 0,
    this.wordsFound = 0,
    this.lessonsCompleted = 0,
    this.activeCourseId,
  });

  DemoUser copyWith({
    String? id,
    String? name,
    String? email,
    int? heroIndex,
    String? heroClassName,
    int? level,
    int? xp,
    int? xpToNextLevel,
    int? streak,
    int? wordsFound,
    int? lessonsCompleted,
    String? activeCourseId,
    bool clearActiveCourse = false,
  }) {
    return DemoUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      heroIndex: heroIndex ?? this.heroIndex,
      heroClassName: heroClassName ?? this.heroClassName,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      streak: streak ?? this.streak,
      wordsFound: wordsFound ?? this.wordsFound,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      activeCourseId: clearActiveCourse
          ? null
          : (activeCourseId ?? this.activeCourseId),
    );
  }

  String get levelTitle {
    if (level <= 2) return 'Traveler';
    if (level <= 4) return 'Speaker';
    if (level <= 6) return 'Guardian';
    return 'Master';
  }
}

/// Empty unauthenticated state. Progress values stay at their model defaults.
const DemoUser guestUser = DemoUser(id: '', name: 'Guest', email: '');
