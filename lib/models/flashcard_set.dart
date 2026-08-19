import 'package:ogrenme_asistani/models/flashcard.dart';

class FlashcardSet {
  FlashcardSet({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.cards,
    this.subjectId,
    this.isManual = false,
  });

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'cards': cards.map((c) => c.toJson()).toList(),
    'subjectId': subjectId,
    'isManual': isManual,
  };
}
