class QuizAttempt {
  QuizAttempt({
    required this.completedAt,
    required this.correctCount,
    required this.totalCount,
    required this.wrongQuestionIndices,
    this.wrongSelections = const {},
    this.wrongTextAnswers = const {},
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    final rawIndices = json['wrongQuestionIndices'] as List? ?? [];
    final rawSelections =
        json['wrongSelections'] as Map<String, dynamic>? ?? {};
    final rawTextAnswers =
        json['wrongTextAnswers'] as Map<String, dynamic>? ?? {};
    return QuizAttempt(
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
      correctCount: json['correctCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      wrongQuestionIndices: rawIndices.whereType<int>().toList(),
      wrongSelections: {
        for (final entry in rawSelections.entries)
          int.parse(entry.key): entry.value as int,
      },
      wrongTextAnswers: {
        for (final entry in rawTextAnswers.entries)
          int.parse(entry.key): entry.value as String,
      },
    );
  }

  final DateTime completedAt;
  final int correctCount;
  final int totalCount;

  /// Indices into the parent [QuizSet.questions] list (stable across
  /// shuffled attempts) that were answered incorrectly.
  final List<int> wrongQuestionIndices;

  /// For each wrong question index, the original (unshuffled) option
  /// index the user picked — lets the history view show exactly which
  /// wrong answer they chose.
  final Map<int, int> wrongSelections;

  /// For each wrong fill-blank question index, the free text the user
  /// actually typed — lets the history view show it instead of an
  /// option index.
  final Map<int, String> wrongTextAnswers;

  Map<String, dynamic> toJson() => {
    'completedAt': completedAt.toIso8601String(),
    'correctCount': correctCount,
    'totalCount': totalCount,
    'wrongQuestionIndices': wrongQuestionIndices,
    'wrongSelections': {
      for (final entry in wrongSelections.entries)
        entry.key.toString(): entry.value,
    },
    'wrongTextAnswers': {
      for (final entry in wrongTextAnswers.entries)
        entry.key.toString(): entry.value,
    },
  };
}
