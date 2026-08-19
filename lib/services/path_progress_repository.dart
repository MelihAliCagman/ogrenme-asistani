import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/curriculum_path.dart';
import 'package:ogrenme_asistani/models/path_progress.dart';

/// Per-user progress through a `CurriculumPath` —
/// `users/{uid}/path_progress/{subjectKey}`. Covered by the same
/// `users/{uid}/**` owner-only security rule as every other per-user
/// subcollection in the app, so no new Firestore rule is needed for
/// this one.
class PathProgressRepository {
  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('path_progress');
  }

  Future<PathProgress> load(String uid, String subjectKey) async {
    final doc = await _collection(uid).doc(subjectKey).get();
    return PathProgress.fromJson(subjectKey, doc.data());
  }

  /// Marks one content kind of one node as completed. Written as a
  /// dotted field path (`nodeProgress.{nodeId}.{field}`) inside a
  /// merge-set so it only touches that single leaf — every other
  /// node's/kind's progress already stored is left untouched.
  Future<void> markContentCompleted(
    String uid,
    String subjectKey,
    String nodeId,
    PathContentKind kind,
  ) {
    return _collection(uid).doc(subjectKey).set({
      'nodeProgress.$nodeId.${_fieldFor(kind)}': true,
    }, SetOptions(merge: true));
  }

  String _fieldFor(PathContentKind kind) {
    switch (kind) {
      case PathContentKind.flashcards:
        return 'cardCompleted';
      case PathContentKind.multipleChoice:
        return 'quizCompleted';
      case PathContentKind.fillBlank:
        return 'fillBlankCompleted';
      case PathContentKind.trueFalse:
        return 'trueFalseCompleted';
    }
  }
}
