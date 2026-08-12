import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/user_profile.dart';

class UserProfileRepository {
  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<UserProfile?> load(String uid) async {
    final snapshot = await _doc(uid).get();
    final raw = snapshot.data()?['userProfile'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return UserProfile.fromJson(raw);
  }

  Future<void> save(String uid, UserProfile profile) {
    return _doc(
      uid,
    ).set({'userProfile': profile.toJson()}, SetOptions(merge: true));
  }
}
