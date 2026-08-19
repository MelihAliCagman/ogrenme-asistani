import 'package:ogrenme_asistani/models/curriculum_path.dart';

// Mutual import with curriculum_path.dart (it needs [NodeProgress] for
// [CurriculumNode.isFullyCompleted], this needs [PathContentKind] for
// [NodeProgress.isKindCompleted]) — fine in Dart, no cycle issue.

/// Per-node completion flags for the 4 content kinds a [CurriculumNode]
/// can carry. A kind the node has no content for is simply never set —
/// [CurriculumNode.isFullyCompleted] treats a contentless kind as
/// automatically satisfied rather than reading its `false` default as
/// "not done".
class NodeProgress {
  const NodeProgress({
    this.cardCompleted = false,
    this.quizCompleted = false,
    this.fillBlankCompleted = false,
    this.trueFalseCompleted = false,
  });

  factory NodeProgress.fromJson(Map<String, dynamic>? json) => NodeProgress(
    cardCompleted: json?['cardCompleted'] as bool? ?? false,
    quizCompleted: json?['quizCompleted'] as bool? ?? false,
    fillBlankCompleted: json?['fillBlankCompleted'] as bool? ?? false,
    trueFalseCompleted: json?['trueFalseCompleted'] as bool? ?? false,
  );

  final bool cardCompleted;
  final bool quizCompleted;
  final bool fillBlankCompleted;
  final bool trueFalseCompleted;

  bool isKindCompleted(PathContentKind kind) {
    switch (kind) {
      case PathContentKind.flashcards:
        return cardCompleted;
      case PathContentKind.multipleChoice:
        return quizCompleted;
      case PathContentKind.fillBlank:
        return fillBlankCompleted;
      case PathContentKind.trueFalse:
        return trueFalseCompleted;
    }
  }
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
