import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> markNodeCompleted(String uid, String subjectKey, String nodeId) {
    return _collection(uid).doc(subjectKey).set({
      'completedNodeIds': FieldValue.arrayUnion([nodeId]),
    }, SetOptions(merge: true));
  }
}
