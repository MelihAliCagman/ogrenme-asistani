import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:ogrenme_asistani/services/firestore_list_storage.dart';

/// Stores the messages of a single chat session at
/// `users/{uid}/chats/{chatId}/messages`.
class ChatRepository {
  ChatRepository({required this.chatId});

  final String chatId;

  final _cloudStorage = FirestoreListStorage<ChatMessage>(
    fromJson: ChatMessage.fromJson,
    toJson: (message) => message.toJson(),
    idOf: (message, index) => index.toString(),
    logTag: 'ChatRepository',
  );

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages');
  }

  Future<List<ChatMessage>> loadAll() {
    final collection = _collection;
    if (collection == null) return Future.value([]);
    return _cloudStorage.loadAll(collection);
  }

  Future<void> saveAll(List<ChatMessage> messages) {
    final collection = _collection;
    if (collection == null) return Future.value();
    return _cloudStorage.saveAll(collection, messages);
  }
}
