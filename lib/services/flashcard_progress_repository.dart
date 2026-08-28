import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/flashcard_in_progress.dart';

/// Per-user, per-card-set "still mid-session" snapshot —
/// `users/{uid}/flashcard_progress/{cardSetId}`. Same shape/lifecycle as
/// [QuizProgressRepository] but for the flashcard "Quiz Modu" swipe flow.
class FlashcardProgressRepository {
  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('flashcard_progress');
  }

  Future<FlashcardInProgress?> load(String uid, String cardSetId) async {
    final doc = await _collection(uid).doc(cardSetId).get();
    final data = doc.data();
    if (data == null) return null;
    return FlashcardInProgress.fromJson(data);
  }

  Future<void> save(String uid, String cardSetId, FlashcardInProgress progress) {
    return _collection(uid).doc(cardSetId).set(progress.toJson());
  }

  Future<void> clear(String uid, String cardSetId) {
    return _collection(uid).doc(cardSetId).delete();
  }
}
