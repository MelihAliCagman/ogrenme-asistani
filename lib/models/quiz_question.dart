/// The kind of question a [QuizQuestion] represents. Multiple choice and
/// true/false are both stored as `options` + `correctIndex` (true/false
/// just has two options), so all scoring/history code that indexes into
/// `options`/`correctIndex` keeps working unchanged for both. Fill-blank
/// stores its single correct answer as `options[0]` (`correctIndex` 0)
/// for the same reason, with the question text containing a blank
/// marker (e.g. "____").
enum QuestionType { multipleChoice, trueFalse, fillBlank }

QuestionType _typeFromJson(String? raw) {
  switch (raw) {
    case 'trueFalse':
      return QuestionType.trueFalse;
    case 'fillBlank':
      return QuestionType.fillBlank;
    default:
      return QuestionType.multipleChoice;
  }
}

String _typeToJson(QuestionType type) {
  switch (type) {
    case QuestionType.trueFalse:
      return 'trueFalse';
    case QuestionType.fillBlank:
      return 'fillBlank';
    case QuestionType.multipleChoice:
      return 'multipleChoice';
  }
}

class QuizQuestion {
  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.type = QuestionType.multipleChoice,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? [];
    return QuizQuestion(
      question: json['question'] as String? ?? '',
      options: rawOptions.whereType<String>().toList(),
      correctIndex: json['correctIndex'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
      type: _typeFromJson(json['type'] as String?),
    );
  }

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final QuestionType type;

  /// The correct answer text — for fill-blank questions this is the
  /// expected fill-in, for others it's the correct option's text.
  String get answerText => options[correctIndex];

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
    'type': _typeToJson(type),
  };
}
