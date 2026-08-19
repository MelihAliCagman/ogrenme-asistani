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

  /// Live updates of the user's flashcard sets. Falls back to an empty,
  /// never-updating stream when signed out (local-only storage has no
  /// change notifications).
  Stream<List<FlashcardSet>> watchAll() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _collection(uid).snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => FlashcardSet.fromJson(doc.data())).toList(),
    );
  }

  Future<void> saveAll(List<FlashcardSet> sets) {
    final uid = _uid;
    if (uid == null) return _localStorage.saveAll(sets);
    return _cloudStorage.saveAll(_collection(uid), sets);
  }

  /// Reassigns every flashcard set pointing at [subjectId] back to
  /// "Genel" (no subject) — used when the subject itself gets deleted.
  Future<void> clearSubjectFromSets(String subjectId) async {
    final sets = await loadAll();
    final affected = sets.where((s) => s.subjectId == subjectId).toList();
    if (affected.isEmpty) return;
    final updated = sets
        .map(
          (s) => s.subjectId == subjectId
              ? FlashcardSet(
                  id: s.id,
                  title: s.title,
                  createdAt: s.createdAt,
                  cards: s.cards,
                  subjectId: null,
                  isManual: s.isManual,
                )
              : s,
        )
        .toList();
    await saveAll(updated);
  }
}
