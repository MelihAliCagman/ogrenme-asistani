/// A snapshot of an unfinished flashcard "Quiz Modu" (swipe Bildim/
/// Bilemedim) session — same idea as [QuizInProgress] but for the
/// flip-card flow, kept deliberately minimal (no per-card right/wrong
/// detail, just where the user left off).
class FlashcardInProgress {
  FlashcardInProgress({
    required this.order,
    required this.currentIndex,
    required this.correctCount,
    required this.incorrectCount,
  });

  factory FlashcardInProgress.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'] as List? ?? [];
    return FlashcardInProgress(
      order: rawOrder.whereType<num>().map((n) => n.toInt()).toList(),
      currentIndex: json['currentIndex'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
    );
  }

  /// Shuffled card order for this session (indices into the parent
  /// [FlashcardSet.cards]) — replayed as-is on resume.
  final List<int> order;
  final int currentIndex;
  final int correctCount;
  final int incorrectCount;

  Map<String, dynamic> toJson() => {
    'order': order,
    'currentIndex': currentIndex,
    'correctCount': correctCount,
    'incorrectCount': incorrectCount,
  };
}
