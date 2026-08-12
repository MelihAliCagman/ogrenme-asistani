import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/subject.dart';

/// Manages the user's subjects (ders) under `users/{uid}/subjects`.
class SubjectRepository {
  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects');
  }

  Future<List<Subject>> loadAll(String uid) async {
    final snapshot = await _collection(
      uid,
    ).orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => Subject.fromJson(doc.id, doc.data()))
        .toList();
  }

  /// Live updates of the user's subjects, so any screen watching this
  /// reflects additions/edits immediately without needing to be
  /// re-opened (screens like the tab bar keep old instances alive).
  Stream<List<Subject>> watchAll(String uid) {
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Subject.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<Subject> createSubject(
    String uid, {
    required String name,
    required Color color,
  }) async {
    final doc = _collection(uid).doc();
    final subject = Subject(
      id: doc.id,
      name: name,
      color: color,
      createdAt: DateTime.now(),
    );
    await doc.set(subject.toJson());
    return subject;
  }

  Future<void> updateSubject(
    String uid,
    String subjectId, {
    required String name,
    required Color color,
  }) {
    return _collection(uid).doc(subjectId).update({
      'name': name,
      'color': color.toARGB32(),
    });
  }

  Future<void> deleteSubject(String uid, String subjectId) {
    return _collection(uid).doc(subjectId).delete();
  }
}
