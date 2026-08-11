import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/services/firestore_list_storage.dart';
import 'package:ogrenme_asistani/services/json_list_storage.dart';
import 'package:ogrenme_asistani/services/local_to_cloud_migration.dart';

class CardSetRepository {
  final _localStorage = JsonListStorage<FlashcardSet>(
    storageKey: 'flashcard_sets',
    fromJson: FlashcardSet.fromJson,
    toJson: (set) => set.toJson(),
    logTag: 'CardSetRepository',
  );

  final _cloudStorage = FirestoreListStorage<FlashcardSet>(
    fromJson: FlashcardSet.fromJson,
    toJson: (set) => set.toJson(),
    idOf: (set, index) => set.id,
    logTag: 'CardSetRepository',
  );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('flashcard_sets');
  }

  Future<List<FlashcardSet>> loadAll() async {
    final uid = _uid;
    if (uid == null) return _localStorage.loadAll();

    await LocalToCloudMigration.runOnce(
      uid: uid,
      key: 'flashcard_sets',
      migrate: () async {
        final localSets = await _localStorage.loadAll();
        if (localSets.isEmpty) return;
        if (!await _cloudStorage.isEmpty(_collection(uid))) return;
        await _cloudStorage.saveAll(_collection(uid), localSets);
      },
    );

    return _cloudStorage.loadAll(_collection(uid));
  }

  Future<void> saveAll(List<FlashcardSet> sets) {
    final uid = _uid;
    if (uid == null) return _localStorage.saveAll(sets);
    return _cloudStorage.saveAll(_collection(uid), sets);
  }
}
