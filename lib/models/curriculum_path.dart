import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

/// One topic ("konu") inside a [CurriculumUnit] — a single Duolingo-style
/// node on the path. Content reuses the exact same wire format as
/// [Flashcard]/[QuizQuestion] everywhere else in the app, so a node's
/// content can be copied straight into a normal [FlashcardSet]/[QuizSet]
/// with no conversion step.
class CurriculumNode {
  CurriculumNode({
    required this.id,
    required this.order,
    required this.title,
    required this.estimatedMinutes,
    required this.flashcards,
    required this.multipleChoice,
    required this.fillBlank,
    required this.trueFalse,
  });

  factory CurriculumNode.fromJson(Map<String, dynamic> json) {
    List<Flashcard> cardsFrom(String key) => ((json[key] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Flashcard.fromJson)
        .toList();
    List<QuizQuestion> questionsFrom(String key) => ((json[key] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestion.fromJson)
        .toList();
    return CurriculumNode(
      id: json['id'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 10,
      flashcards: cardsFrom('flashcards'),
      multipleChoice: questionsFrom('multipleChoice'),
      fillBlank: questionsFrom('fillBlank'),
      trueFalse: questionsFrom('trueFalse'),
    );
  }

  final String id;
  final int order;
  final String title;
  final int estimatedMinutes;
  final List<Flashcard> flashcards;
  final List<QuizQuestion> multipleChoice;
  final List<QuizQuestion> fillBlank;
  final List<QuizQuestion> trueFalse;
}

/// A unit ("ünite") — an ordered group of [CurriculumNode]s. Units seeded
/// with just a title and no nodes yet show as locked/"Yakında" until
/// their content is authored in a later phase.
class CurriculumUnit {
  CurriculumUnit({
    required this.id,
    required this.order,
    required this.title,
    required this.nodes,
  });

  factory CurriculumUnit.fromJson(String id, Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List? ?? [];
    final nodes =
        rawNodes
            .whereType<Map<String, dynamic>>()
            .map(CurriculumNode.fromJson)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return CurriculumUnit(
      id: id,
      order: json['order'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      nodes: nodes,
    );
  }

  final String id;
  final int order;
  final String title;
  final List<CurriculumNode> nodes;

  bool get isComingSoon => nodes.isEmpty;
}

/// The full "Ders Yolu" (skill path) for one subject — a public,
/// read-only curriculum map seeded once via the admin tool, same pattern
/// as `sample_lessons`/`SampleLesson`.
class CurriculumPath {
  CurriculumPath({
    required this.subjectKey,
    required this.title,
    required this.units,
  });

  factory CurriculumPath.fromJson(
    String subjectKey,
    Map<String, dynamic> json,
    List<CurriculumUnit> units,
  ) {
    final sorted = List.of(units)..sort((a, b) => a.order.compareTo(b.order));
    return CurriculumPath(
      subjectKey: subjectKey,
      title: json['title'] as String? ?? subjectKey,
      units: sorted,
    );
  }

  final String subjectKey;
  final String title;
  final List<CurriculumUnit> units;

  /// Every node across every unit, in path order — the flat sequence
  /// that drives unlock progression (node i unlocks once node i-1's
  /// test is passed).
  List<CurriculumNode> get allNodes =>
      units.expand((unit) => unit.nodes).toList();
}
