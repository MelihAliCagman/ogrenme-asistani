import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

/// A curated, read-only lesson shown in the Keşfet (Discover) tab.
/// Content lives in the public `sample_lessons` Firestore collection so
/// new lessons can be added later without an app update.
class SampleLesson {
  SampleLesson({
    required this.id,
    required this.title,
    required this.color,
    required this.summaryText,
    required this.flashcards,
    required this.quizQuestions,
  });

  factory SampleLesson.fromJson(String id, Map<String, dynamic> json) {
    final rawCards = json['flashcards'] as List? ?? [];
    final rawQuestions = json['quizQuestions'] as List? ?? [];
    return SampleLesson(
      id: id,
      title: json['title'] as String? ?? 'Örnek Ders',
      color: Color(json['color'] as int? ?? Colors.deepPurple.toARGB32()),
      summaryText: json['summaryText'] as String? ?? '',
      flashcards: rawCards
          .whereType<Map<String, dynamic>>()
          .map(Flashcard.fromJson)
          .toList(),
      quizQuestions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestion.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final Color color;
  final String summaryText;
  final List<Flashcard> flashcards;
  final List<QuizQuestion> quizQuestions;

  static const icon = Icons.explore_outlined;

  Map<String, dynamic> toJson() => {
    'title': title,
    'color': color.toARGB32(),
    'summaryText': summaryText,
    'flashcards': flashcards.map((c) => c.toJson()).toList(),
    'quizQuestions': quizQuestions.map((q) => q.toJson()).toList(),
  };
}
