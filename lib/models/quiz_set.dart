import 'package:ogrenme_asistani/models/quiz_attempt.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

class QuizSet {
  QuizSet({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.questions,
    this.subjectId,
    this.attempts = const [],
  });

  factory QuizSet.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List? ?? [];
    final rawAttempts = json['attempts'] as List? ?? [];
    return QuizSet(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Test Seti',
      createdAt: DateTime.parse(json['createdAt'] as String),
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestion.fromJson)
          .toList(),
      subjectId: json['subjectId'] as String?,
      attempts: rawAttempts
          .whereType<Map<String, dynamic>>()
          .map(QuizAttempt.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final List<QuizQuestion> questions;
  final String? subjectId;
  final List<QuizAttempt> attempts;

  /// The question type shared by every question in this set (a set is
  /// always generated as a single format), or `null` if it has none.
  QuestionType? get format => questions.isEmpty ? null : questions.first.type;

  QuizSet withSubjectId(String? subjectId) => QuizSet(
    id: id,
    title: title,
    createdAt: createdAt,
    questions: questions,
    subjectId: subjectId,
    attempts: attempts,
  );

  QuizSet withTitle(String title) => QuizSet(
    id: id,
    title: title,
    createdAt: createdAt,
    questions: questions,
    subjectId: subjectId,
    attempts: attempts,
  );

  QuizSet withAttempts(List<QuizAttempt> attempts) => QuizSet(
    id: id,
    title: title,
    createdAt: createdAt,
    questions: questions,
    subjectId: subjectId,
    attempts: attempts,
  );

  /// Re-syncs the question content while keeping id/attempts/etc. — used
  /// by the Ders Yolları path screen to refresh an already-materialized
  /// set if the source curriculum node's content was corrected upstream
  /// after the user's first copy was made.
  QuizSet withQuestions(List<QuizQuestion> questions) => QuizSet(
    id: id,
    title: title,
    createdAt: createdAt,
    questions: questions,
    subjectId: subjectId,
    attempts: attempts,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'questions': questions.map((q) => q.toJson()).toList(),
    'subjectId': subjectId,
    'attempts': attempts.map((a) => a.toJson()).toList(),
  };
}
