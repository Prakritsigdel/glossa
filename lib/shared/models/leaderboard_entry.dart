/// A single row in the leaderboard.
class LeaderboardEntry {
  final int rank;
  final String name;
  final int level;
  final String className;
  final int xp;
  final int heroIndex; // 0=boy, 1=girl
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.level,
    required this.className,
    required this.xp,
    this.heroIndex = 0,
    this.isCurrentUser = false,
  });
}
