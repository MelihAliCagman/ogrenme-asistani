import 'package:ogrenme_asistani/models/curriculum_path.dart';

// Mutual import with curriculum_path.dart (it needs [NodeProgress] for
// [CurriculumNode.isFullyCompleted], this needs [PathContentKind] for
// [NodeProgress.isKindCompleted]) — fine in Dart, no cycle issue.

/// Per-node completion state for the 4 content kinds a [CurriculumNode]
/// can carry — now tracked per *part* (e.g. which of the 5 "Test N"
/// multiple-choice parts have been finished at least once) rather than
/// one flag per kind, since a kind only counts as done once every one of
/// its parts has been completed — see [isKindCompleted]. A kind the node
/// has no content for is simply never set — [CurriculumNode.isFullyCompleted]
/// treats a contentless kind as automatically satisfied rather than
/// reading an empty completed-parts set as "not done".
class NodeProgress {
  const NodeProgress({
    this.completedFlashcardParts = const {},
    this.completedMultipleChoiceParts = const {},
    this.completedFillBlankParts = const {},
    this.completedTrueFalseParts = const {},
  });

  factory NodeProgress.fromJson(Map<String, dynamic>? json) {
    final rawParts = json?['completedParts'] as Map<String, dynamic>? ?? {};
    Set<int> partsFor(String key) => ((rawParts[key] as List?) ?? [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    return NodeProgress(
      completedFlashcardParts: partsFor('flashcards'),
      completedMultipleChoiceParts: partsFor('multipleChoice'),
      completedFillBlankParts: partsFor('fillBlank'),
      completedTrueFalseParts: partsFor('trueFalse'),
    );
  }

  final Set<int> completedFlashcardParts;
  final Set<int> completedMultipleChoiceParts;
  final Set<int> completedFillBlankParts;
  final Set<int> completedTrueFalseParts;

  Set<int> completedPartsFor(PathContentKind kind) {
    switch (kind) {
      case PathContentKind.flashcards:
        return completedFlashcardParts;
      case PathContentKind.multipleChoice:
        return completedMultipleChoiceParts;
      case PathContentKind.fillBlank:
        return completedFillBlankParts;
      case PathContentKind.trueFalse:
        return completedTrueFalseParts;
    }
  }

  bool isPartCompleted(PathContentKind kind, int partIndex) =>
      completedPartsFor(kind).contains(partIndex);

  /// A kind counts as completed once every one of its [totalParts] has
  /// been finished at least once (never true for a kind with 0 parts).
  bool isKindCompleted(PathContentKind kind, int totalParts) =>
      totalParts > 0 && completedPartsFor(kind).length >= totalParts;
}

/// A user's progress through one [CurriculumPath] —
/// `users/{uid}/path_progress/{subjectKey}`. Stores, per node, which of
/// the 4 content kinds have been completed; a node counts as done once
/// every kind it actually has content for is completed (see
/// [CurriculumNode.isFullyCompleted]), and unlock state for the next
/// node is derived from that at read time.
class PathProgress {
  PathProgress({required this.subjectKey, required this.nodeProgress});

  factory PathProgress.fromJson(String subjectKey, Map<String, dynamic>? json) {
    final raw = json?['nodeProgress'] as Map<String, dynamic>? ?? {};
    return PathProgress(
      subjectKey: subjectKey,
      nodeProgress: raw.map(
        (nodeId, value) => MapEntry(
          nodeId,
          NodeProgress.fromJson(value as Map<String, dynamic>?),
        ),
      ),
    );
  }

  final String subjectKey;
  final Map<String, NodeProgress> nodeProgress;

  NodeProgress progressFor(String nodeId) =>
      nodeProgress[nodeId] ?? const NodeProgress();

  bool isNodeCompleted(CurriculumNode node) =>
      node.isFullyCompleted(progressFor(node.id));
}
