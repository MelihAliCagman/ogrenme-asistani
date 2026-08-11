import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Persists a list of JSON-serializable items as one document per item
/// inside a given Firestore collection, mirroring the whole-list
/// load/save API of [JsonListStorage] so repositories can switch backends
/// without changing their callers. The caller supplies the collection
/// reference, so this works for both top-level and deeply nested
/// collections (e.g. `users/{uid}/chats/{chatId}/messages`).
class FirestoreListStorage<T> {
  FirestoreListStorage({
    required this.fromJson,
    required this.toJson,
    required this.idOf,
    required this.logTag,
  });

  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toJson;
  final String Function(T item, int index) idOf;
  final String logTag;

  Future<List<T>> loadAll(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    try {
      final snapshot = await collection.orderBy('order').get();
      return snapshot.docs.map((doc) => fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[$logTag] Firestore verisi okunamadı: $e');
      return [];
    }
  }

  Future<void> saveAll(
    CollectionReference<Map<String, dynamic>> collection,
    List<T> items,
  ) async {
    final existing = await collection.get();
    final batch = FirebaseFirestore.instance.batch();

    final newIds = <String>{};
    for (var i = 0; i < items.length; i++) {
      final id = idOf(items[i], i);
      newIds.add(id);
      final data = {...toJson(items[i]), 'order': i};
      batch.set(collection.doc(id), data);
    }
    for (final doc in existing.docs) {
      if (!newIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  Future<bool> isEmpty(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.limit(1).get();
    return snapshot.docs.isEmpty;
  }
}
