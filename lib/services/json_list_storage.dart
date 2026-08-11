import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a list of JSON-serializable items under a single
/// SharedPreferences key. Shared by repositories that store a simple
/// list (chat messages, flashcard sets, ...) as one JSON blob.
class JsonListStorage<T> {
  JsonListStorage({
    required this.storageKey,
    required this.fromJson,
    required this.toJson,
    required this.logTag,
  });

  final String storageKey;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toJson;
  final String logTag;

  Future<List<T>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final rawList = jsonDecode(raw) as List;
      return rawList.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (e) {
      debugPrint('[$logTag] Kayıtlı veri okunamadı: $e');
      return [];
    }
  }

  Future<void> saveAll(List<T> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map(toJson).toList());
    await prefs.setString(storageKey, raw);
  }
}
