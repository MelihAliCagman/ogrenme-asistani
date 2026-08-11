import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:ogrenme_asistani/services/json_list_storage.dart';

class ChatRepository {
  final _storage = JsonListStorage<ChatMessage>(
    storageKey: 'chat_messages',
    fromJson: ChatMessage.fromJson,
    toJson: (message) => message.toJson(),
    logTag: 'ChatRepository',
  );

  Future<List<ChatMessage>> loadAll() => _storage.loadAll();

  Future<void> saveAll(List<ChatMessage> messages) => _storage.saveAll(messages);
}
