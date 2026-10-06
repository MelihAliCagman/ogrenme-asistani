import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/path_progress.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';
import 'package:ogrenme_asistani/models/set_format.dart';

/// The 4 content kinds a [CurriculumNode] can carry — also the 4 slices
/// of a node's progress ring on the path screen.
enum PathContentKind { flashcards, multipleChoice, fillBlank, trueFalse }

extension PathContentKindMeta on PathContentKind {
  SetFormat get setFormat {
    switch (this) {
      case PathContentKind.flashcards:
        return SetFormat.flashcards;
      case PathContentKind.multipleChoice:
        return SetFormat.multipleChoice;
      case PathContentKind.fillBlank:
        return SetFormat.fillBlank;
      case PathContentKind.trueFalse:
        return SetFormat.trueFalse;
    }
  }
}

/// One "part" of a node's flashcard content — e.g. "Kart Seti 2" of 5 —
/// materialized 1:1 into a real [FlashcardSet] the first time it's
/// opened, same wire format as [Flashcard] so no conversion step is
/// needed.
class CurriculumFlashcardPart {
  CurriculumFlashcardPart({required this.title, required this.cards});

  factory CurriculumFlashcardPart.fromJson(Map<String, dynamic> json) =>
      CurriculumFlashcardPart(
        title: json['title'] as String? ?? '',
        cards: ((json['cards'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Flashcard.fromJson)
            .toList(),
      );

  final String title;
  final List<Flashcard> cards;
}

/// One "part" of a node's quiz-shaped content (multiple choice, fill
/// blank, or true/false) — e.g. "Test 3" of 5 — materialized 1:1 into a
/// real [QuizSet] the first time it's opened.
class CurriculumQuizPart {
  CurriculumQuizPart({required this.title, required this.questions});

  factory CurriculumQuizPart.fromJson(Map<String, dynamic> json) =>
      CurriculumQuizPart(
        title: json['title'] as String? ?? '',
        questions: ((json['questions'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(QuizQuestion.fromJson)
            .toList(),
      );

  final String title;
  final List<QuizQuestion> questions;
}

/// One topic ("konu") inside a [CurriculumUnit] — a single Duolingo-style
/// node on the path. Each content kind is split into small, independently
/// completable parts (e.g. 50 multiple-choice questions become 5 "Test
/// N" parts of 10) instead of one long set, so a kind only counts as
/// finished once every one of its parts has been done at least once —
/// see [NodeProgress.isKindCompleted].
class CurriculumNode {
  CurriculumNode({
    required this.id,
    required this.order,
    required this.title,
    required this.estimatedMinutes,
    required this.flashcardParts,
    required this.multipleChoiceParts,
    required this.fillBlankParts,
    required this.trueFalseParts,
  });

  /// [unitId] is folded into [id] because the raw `id` field in a node's
  /// JSON (e.g. `"node1"`) is only unique *within* its unit — every unit
  /// reuses the same `node1..nodeN` ids. [id] is used as the progress
  /// lookup key ([PathProgress.progressFor]) and to derive the
  /// materialized flashcard/quiz set id ([PathDetailScreen]), so without
  /// this prefix two different units' first node would read/write the
  /// exact same progress entry and the exact same materialized set.
  factory CurriculumNode.fromJson(Map<String, dynamic> json, {required String unitId}) {
    List<CurriculumFlashcardPart> flashcardPartsFrom(String key) =>
        ((json[key] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CurriculumFlashcardPart.fromJson)
            .toList();
    List<CurriculumQuizPart> quizPartsFrom(String key) =>
        ((json[key] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CurriculumQuizPart.fromJson)
            .toList();
    return CurriculumNode(
      id: '${unitId}_${json['id'] as String? ?? ''}',
      order: json['order'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 10,
      flashcardParts: flashcardPartsFrom('flashcards'),
      multipleChoiceParts: quizPartsFrom('multipleChoice'),
      fillBlankParts: quizPartsFrom('fillBlank'),
      trueFalseParts: quizPartsFrom('trueFalse'),
    );
  }

  final String id;
  final int order;
  final String title;
  final int estimatedMinutes;
  final List<CurriculumFlashcardPart> flashcardParts;
  final List<CurriculumQuizPart> multipleChoiceParts;
  final List<CurriculumQuizPart> fillBlankParts;
  final List<CurriculumQuizPart> trueFalseParts;

  int partCountFor(PathContentKind kind) {
    switch (kind) {
      case PathContentKind.flashcards:
        return flashcardParts.length;
      case PathContentKind.multipleChoice:
        return multipleChoiceParts.length;
      case PathContentKind.fillBlank:
        return fillBlankParts.length;
      case PathContentKind.trueFalse:
        return trueFalseParts.length;
    }
  }

  bool hasContent(PathContentKind kind) => partCountFor(kind) > 0;

  /// Whether this node has any authored content at all. Outline-only
  /// nodes (a topic listed in the YKS müfredat whose questions are not
  /// written yet) have none and show as "Yakında".
  bool get hasAnyContent => PathContentKind.values.any(hasContent);

  /// A node is fully completed once every content kind it actually has
  /// content for is completed in [progress] — a kind the node has no
  /// content for (e.g. a future phase's nodes before their fill-blank
  /// set is authored) never blocks completion. A node with no content at
  /// all is never completed: otherwise an empty outline topic would count
  /// as done and unlock the next one.
  bool isFullyCompleted(NodeProgress progress) =>
      hasAnyContent &&
      PathContentKind.values
          .where(hasContent)
          .every((kind) => progress.isKindCompleted(kind, partCountFor(kind)));
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
            .map((n) => CurriculumNode.fromJson(n, unitId: id))
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

  /// Whether at least one topic of this unit has authored content.
  bool get hasContent => nodes.any((n) => n.hasAnyContent);

  /// Topics of this unit that have content — the ones that count toward
  /// the unit's progress.
  int get contentNodeCount => nodes.where((n) => n.hasAnyContent).length;
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
