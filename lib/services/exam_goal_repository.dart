import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/exam_goal.dart';

/// Manages the user's exam goals ("Sınav Hedeflerim") under
/// `users/{uid}/exam_goals`.
class ExamGoalRepository {
  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('exam_goals');
  }

  Future<List<ExamGoal>> loadAll(String uid) async {
    final snapshot = await _collection(uid).orderBy('date').get();
    return snapshot.docs
        .map((doc) => ExamGoal.fromJson(doc.id, doc.data()))
        .toList();
  }

  /// Live updates of the user's exam goals, ordered by date ascending —
  /// used by the Ana Sayfa countdown card and the Hedeflerim list.
  Stream<List<ExamGoal>> watchAll(String uid) {
    return _collection(uid).orderBy('date').snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ExamGoal.fromJson(doc.id, doc.data())).toList(),
    );
  }

  Future<void> createGoal(
    String uid, {
    required String name,
    required DateTime date,
    double? targetScore,
  }) async {
    final doc = _collection(uid).doc();
    await doc.set({
      'name': name,
      'date': date.toIso8601String(),
      'targetScore': targetScore,
    });
  }

  Future<void> updateGoal(
    String uid,
    String goalId, {
    required String name,
    required DateTime date,
    double? targetScore,
  }) {
    return _collection(uid).doc(goalId).update({
      'name': name,
      'date': date.toIso8601String(),
      'targetScore': targetScore,
    });
  }

  Future<void> deleteGoal(String uid, String goalId) {
    return _collection(uid).doc(goalId).delete();
  }
}
