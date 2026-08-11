import 'package:ogrenme_asistani/services/chat_font_size.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatFontSizeRepository {
  static const _storageKey = 'chat_font_size';

  Future<ChatFontSize> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    return ChatFontSize.values.firstWhere(
      (size) => size.name == raw,
      orElse: () => ChatFontSize.medium,
    );
  }

  Future<void> save(ChatFontSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, size.name);
  }
}
