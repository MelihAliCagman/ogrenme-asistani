class StreakData {
  StreakData({
    required this.lastActiveDate,
    required this.currentStreak,
    required this.longestStreak,
    this.lastSubjectId,
    this.lastSubjectName,
  });

  factory StreakData.fromJson(Map<String, dynamic> json) {
    return StreakData(
      lastActiveDate: DateTime.tryParse(json['lastActiveDate'] as String? ?? ''),
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastSubjectId: json['lastSubjectId'] as String?,
      lastSubjectName: json['lastSubjectName'] as String?,
    );
  }

  factory StreakData.empty() =>
      StreakData(lastActiveDate: null, currentStreak: 0, longestStreak: 0);

  final DateTime? lastActiveDate;
  final int currentStreak;
  final int longestStreak;

  /// The subject (ders) the user most recently studied via a chat, card
  /// set, or quiz — `null` when that activity had no subject ("Genel").
  final String? lastSubjectId;
  final String? lastSubjectName;

  Map<String, dynamic> toJson() => {
    'lastActiveDate': lastActiveDate?.toIso8601String(),
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastSubjectId': lastSubjectId,
    'lastSubjectName': lastSubjectName,
  };
}
