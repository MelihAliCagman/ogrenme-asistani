import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatRepository {
  static const _storageKey = 'chat_messages';

  Future<List<ChatMessage>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final rawList = jsonDecode(raw) as List;
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[ChatRepository] Kayıtlı mesajlar okunamadı: $e');
      return [];
    }
  }

  Future<void> saveAll(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
