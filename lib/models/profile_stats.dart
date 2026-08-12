class ProfileStats {
  ProfileStats({
    required this.totalChats,
    required this.totalCardSets,
    required this.totalQuizSets,
    required this.totalCards,
    required this.totalQuizAttempts,
    required this.averageQuizScorePercent,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int totalChats;
  final int totalCardSets;
  final int totalQuizSets;
  final int totalCards;
  final int totalQuizAttempts;

  /// 0-100, `null` if no quiz has ever been attempted.
  final double? averageQuizScorePercent;

  final int currentStreak;
  final int longestStreak;

  int get totalSets => totalCardSets + totalQuizSets;
}
