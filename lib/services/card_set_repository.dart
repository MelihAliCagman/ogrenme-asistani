import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardSetRepository {
  static const _storageKey = 'flashcard_sets';

  Future<List<FlashcardSet>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final rawList = jsonDecode(raw) as List;
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(FlashcardSet.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[CardSetRepository] Kayıtlı kartlar okunamadı: $e');
      return [];
    }
  }

  Future<void> saveAll(List<FlashcardSet> sets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sets.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
