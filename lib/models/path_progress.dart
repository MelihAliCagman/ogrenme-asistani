/// A user's progress through one [CurriculumPath] —
/// `users/{uid}/path_progress/{subjectKey}`. Only completed node ids are
/// stored; unlock state is derived from path order at read time (see
/// [CurriculumPath.allNodes]).
class PathProgress {
  PathProgress({required this.subjectKey, required this.completedNodeIds});

  factory PathProgress.fromJson(String subjectKey, Map<String, dynamic>? json) {
    final raw = json?['completedNodeIds'] as List? ?? [];
    return PathProgress(
      subjectKey: subjectKey,
      completedNodeIds: raw.whereType<String>().toSet(),
    );
  }

  final String subjectKey;
  final Set<String> completedNodeIds;

  bool isCompleted(String nodeId) => completedNodeIds.contains(nodeId);
}
