import 'package:ogrenme_asistani/models/flashcard.dart';

class FlashcardSet {
  FlashcardSet({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.cards,
    this.subjectId,
    this.isManual = false,
    this.source,
  });

  /// [source] value for a set materialized from a Ders Yolları curriculum
  /// node ([PathDetailScreen]) — used to exclude these from the Setlerim
  /// general list without touching the underlying data.
  static const sourceCurriculumPath = 'curriculum_path';

  factory FlashcardSet.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List? ?? [];
    return FlashcardSet(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Kart Seti',
      createdAt: DateTime.parse(json['createdAt'] as String),
      cards: rawCards
          .whereType<Map<String, dynamic>>()
          .map(Flashcard.fromJson)
          .toList(),
      subjectId: json['subjectId'] as String?,
      isManual: json['isManual'] as bool? ?? false,
      source: json['source'] as String?,
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final List<Flashcard> cards;
  final String? subjectId;

  /// Whether the user typed these cards in by hand instead of generating
  /// them with AI — shown as a small badge in set lists.
  final bool isManual;

  /// Where this set came from — `null` for a normal user-created set,
  /// [sourceCurriculumPath] for one materialized from a Ders Yolları node.
  final String? source;

  /// Re-syncs the card content while keeping id/etc. — used by the Ders
  /// Yolları path screen to refresh an already-materialized set if the
  /// source curriculum node's content was corrected upstream after the
  /// user's first copy was made.
  FlashcardSet withCards(List<Flashcard> cards) => FlashcardSet(
    id: id,
    title: title,
    createdAt: createdAt,
    cards: cards,
    subjectId: subjectId,
    isManual: isManual,
    source: source,
  );

  FlashcardSet withSource(String? source) => FlashcardSet(
    id: id,
    title: title,
    createdAt: createdAt,
    cards: cards,
    subjectId: subjectId,
    isManual: isManual,
    source: source,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'cards': cards.map((c) => c.toJson()).toList(),
    'subjectId': subjectId,
    'isManual': isManual,
    'source': source,
  };
}
