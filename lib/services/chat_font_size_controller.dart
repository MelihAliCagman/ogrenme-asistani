import 'package:flutter/foundation.dart';
import 'package:ogrenme_asistani/services/chat_font_size.dart';
import 'package:ogrenme_asistani/services/chat_font_size_repository.dart';

class ChatFontSizeController {
  ChatFontSizeController._();

  static final ValueNotifier<ChatFontSize> fontSize = ValueNotifier(
    ChatFontSize.medium,
  );
  static final ChatFontSizeRepository _repository = ChatFontSizeRepository();

  static Future<void> initialize() async {
    fontSize.value = await _repository.load();
  }

  static Future<void> setFontSize(ChatFontSize size) async {
    fontSize.value = size;
    await _repository.save(size);
  }
}
