import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/quiz_in_progress.dart';

/// Per-user, per-quiz-set "still mid-attempt" snapshot —
/// `users/{uid}/quiz_progress/{quizSetId}`. One doc per set (only one
/// unfinished attempt makes sense at a time); overwritten as the
/// attempt advances and deleted once it's finished or restarted.
class QuizProgressRepository {
  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('quiz_progress');
  }

  Future<QuizInProgress?> load(String uid, String quizSetId) async {
    final doc = await _collection(uid).doc(quizSetId).get();
    final data = doc.data();
    if (data == null) return null;
    return QuizInProgress.fromJson(data);
  }

  Future<void> save(String uid, String quizSetId, QuizInProgress progress) {
    return _collection(uid).doc(quizSetId).set(progress.toJson());
  }

  Future<void> clear(String uid, String quizSetId) {
    return _collection(uid).doc(quizSetId).delete();
  }
}
