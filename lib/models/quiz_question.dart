class QuizQuestion {
  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? [];
    return QuizQuestion(
      question: json['question'] as String? ?? '',
      options: rawOptions.whereType<String>().toList(),
      correctIndex: json['correctIndex'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
}
