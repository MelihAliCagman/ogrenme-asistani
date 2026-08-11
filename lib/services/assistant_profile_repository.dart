import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/assistant_profile.dart';

class AssistantProfileRepository {
  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<AssistantProfile?> load(String uid) async {
    final snapshot = await _doc(uid).get();
    final raw = snapshot.data()?['assistantProfile'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return AssistantProfile.fromJson(raw);
  }

  Future<void> save(String uid, AssistantProfile profile) {
    return _doc(
      uid,
    ).set({'assistantProfile': profile.toJson()}, SetOptions(merge: true));
  }
}
