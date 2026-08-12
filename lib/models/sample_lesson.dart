import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

enum SampleDifficulty {
  easy('easy', 'Kolay'),
  medium('medium', 'Orta'),
  hard('hard', 'Zor');

  const SampleDifficulty(this.key, this.label);

  final String key;
  final String label;

  static SampleDifficulty fromKey(String key) => SampleDifficulty.values
      .firstWhere((d) => d.key == key, orElse: () => SampleDifficulty.medium);
}

/// The flashcards + quiz questions for one difficulty level of a
/// [SampleLesson].
class SampleDifficultyContent {
  SampleDifficultyContent({required this.flashcards, required this.quizQuestions});

  factory SampleDifficultyContent.fromJson(Map<String, dynamic> json) {
    final rawCards = json['flashcards'] as List? ?? [];
    final rawQuestions = json['quizQuestions'] as List? ?? [];
    return SampleDifficultyContent(
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

  final List<Flashcard> flashcards;
  final List<QuizQuestion> quizQuestions;

  Map<String, dynamic> toJson() => {
    'flashcards': flashcards.map((c) => c.toJson()).toList(),
    'quizQuestions': quizQuestions.map((q) => q.toJson()).toList(),
  };
}

/// A curated, read-only lesson shown in the Keşfet (Discover) tab.
/// Content lives in the public `sample_lessons` Firestore collection so
/// new lessons can be added later without an app update. Each lesson has
/// separate flashcards/quiz questions per [SampleDifficulty] level.
class SampleLesson {
  SampleLesson({
    required this.id,
    required this.title,
    required this.color,
    required this.summaryText,
    required this.levels,
  });

  factory SampleLesson.fromJson(String id, Map<String, dynamic> json) {
    final rawLevels = json['levels'] as Map<String, dynamic>? ?? {};
    return SampleLesson(
      id: id,
      title: json['title'] as String? ?? 'Örnek Ders',
      color: Color(json['color'] as int? ?? Colors.deepPurple.toARGB32()),
      summaryText: json['summaryText'] as String? ?? '',
      levels: {
        for (final entry in rawLevels.entries)
          SampleDifficulty.fromKey(entry.key): SampleDifficultyContent.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
    );
  }

  final String id;
  final String title;
  final Color color;
  final String summaryText;
  final Map<SampleDifficulty, SampleDifficultyContent> levels;

  static const icon = Icons.explore_outlined;

  int get totalFlashcards =>
      levels.values.fold(0, (sum, c) => sum + c.flashcards.length);
  int get totalQuizQuestions =>
      levels.values.fold(0, (sum, c) => sum + c.quizQuestions.length);

  Map<String, dynamic> toJson() => {
    'title': title,
    'color': color.toARGB32(),
    'summaryText': summaryText,
    'levels': {
      for (final entry in levels.entries) entry.key.key: entry.value.toJson(),
    },
  };
}
