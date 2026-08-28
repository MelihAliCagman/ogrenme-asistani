/// A snapshot of an unfinished [QuizSet] attempt — saved as the user
/// answers each question so leaving mid-way and coming back later offers
/// "Kaldığı Yerden Devam Et" instead of losing the attempt. Cleared once
/// the attempt is finished or explicitly restarted.
class QuizInProgress {
  QuizInProgress({
    required this.order,
    required this.currentIndex,
    required this.correctCount,
    required this.wrongIndices,
    required this.wrongSelections,
    required this.wrongTextAnswers,
  });

  factory QuizInProgress.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'] as List? ?? [];
    final rawWrongIndices = json['wrongIndices'] as List? ?? [];
    final rawSelections = json['wrongSelections'] as Map<String, dynamic>? ?? {};
    final rawTextAnswers = json['wrongTextAnswers'] as Map<String, dynamic>? ?? {};
    return QuizInProgress(
      order: rawOrder.whereType<num>().map((n) => n.toInt()).toList(),
      currentIndex: json['currentIndex'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      wrongIndices: rawWrongIndices.whereType<num>().map((n) => n.toInt()).toList(),
      wrongSelections: {
        for (final entry in rawSelections.entries) int.parse(entry.key): entry.value as int,
      },
      wrongTextAnswers: {
        for (final entry in rawTextAnswers.entries) int.parse(entry.key): entry.value as String,
      },
    );
  }

  /// Shuffled question order for this attempt (indices into the parent
  /// [QuizSet.questions]) — replayed as-is on resume so the remaining
  /// questions stay in the same sequence the user already started.
  final List<int> order;

  /// How far into [order] the user had gotten (0-based).
  final int currentIndex;
  final int correctCount;
  final List<int> wrongIndices;
  final Map<int, int> wrongSelections;
  final Map<int, String> wrongTextAnswers;

  Map<String, dynamic> toJson() => {
    'order': order,
    'currentIndex': currentIndex,
    'correctCount': correctCount,
    'wrongIndices': wrongIndices,
    'wrongSelections': {
      for (final entry in wrongSelections.entries) entry.key.toString(): entry.value,
    },
    'wrongTextAnswers': {
      for (final entry in wrongTextAnswers.entries) entry.key.toString(): entry.value,
    },
  };
}
