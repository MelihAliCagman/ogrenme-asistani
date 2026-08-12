import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ogrenme_asistani/models/quiz_attempt.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/services/firestore_list_storage.dart';
import 'package:ogrenme_asistani/services/json_list_storage.dart';

class QuizSetRepository {
  final _localStorage = JsonListStorage<QuizSet>(
    storageKey: 'quiz_sets',
    fromJson: QuizSet.fromJson,
    toJson: (set) => set.toJson(),
    logTag: 'QuizSetRepository',
  );

  final _cloudStorage = FirestoreListStorage<QuizSet>(
    fromJson: QuizSet.fromJson,
    toJson: (set) => set.toJson(),
    idOf: (set, index) => set.id,
    logTag: 'QuizSetRepository',
  );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('quiz_sets');
  }

  Future<List<QuizSet>> loadAll() async {
    final uid = _uid;
    if (uid == null) return _localStorage.loadAll();
    return _cloudStorage.loadAll(_collection(uid));
  }

  Future<void> saveAll(List<QuizSet> sets) {
    final uid = _uid;
    if (uid == null) return _localStorage.saveAll(sets);
    return _cloudStorage.saveAll(_collection(uid), sets);
  }

  Stream<List<QuizSet>> watchAll() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _collection(
      uid,
    ).snapshots().map((s) => s.docs.map((d) => QuizSet.fromJson(d.data())).toList());
  }

  /// Reassigns every quiz set pointing at [subjectId] back to "Genel"
  /// (no subject) — used when the subject itself gets deleted.
  Future<void> clearSubjectFromSets(String subjectId) async {
    final sets = await loadAll();
    final affected = sets.where((s) => s.subjectId == subjectId).toList();
    if (affected.isEmpty) return;
    final updated = sets
        .map((s) => s.subjectId == subjectId ? s.withSubjectId(null) : s)
        .toList();
    await saveAll(updated);
  }

  /// Appends a completed attempt to the given quiz set's history.
  Future<void> addAttempt(String quizSetId, QuizAttempt attempt) async {
    final sets = await loadAll();
    final updated = sets
        .map(
          (s) => s.id == quizSetId
              ? s.withAttempts([...s.attempts, attempt])
              : s,
        )
        .toList();
    await saveAll(updated);
  }
}
