import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:ogrenme_asistani/models/chat_session.dart';

/// Manages chat session metadata under `users/{uid}/chats`, plus a
/// one-time migration of the old flat `users/{uid}/chat_messages`
/// collection (from before multi-chat support) into a proper session.
class ChatSessionRepository {
  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('chats');
  }

  Future<List<ChatSession>> loadAll(String uid) async {
    await _migrateLegacyFlatChat(uid);
    final snapshot = await _collection(
      uid,
    ).orderBy('updatedAt', descending: true).get();
    return snapshot.docs
        .map((doc) => ChatSession.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<ChatSession> createChat(String uid) async {
    final doc = _collection(uid).doc();
    final now = DateTime.now();
    final session = ChatSession(
      id: doc.id,
      title: ChatSession.defaultTitle,
      createdAt: now,
      updatedAt: now,
    );
    await doc.set(session.toJson());
    return session;
  }

  Future<void> updateTitle(String uid, String chatId, String title) {
    return _collection(uid).doc(chatId).update({'title': title});
  }

  Future<void> touchUpdatedAt(String uid, String chatId) {
    return _collection(
      uid,
    ).doc(chatId).update({'updatedAt': DateTime.now().toIso8601String()});
  }

  /// Old data (pre-multi-chat) lived directly under
  /// `users/{uid}/chat_messages`. If no chat sessions exist yet but that
  /// flat collection has messages, move them into a new session once.
  Future<void> _migrateLegacyFlatChat(String uid) async {
    final sessionsSnapshot = await _collection(uid).limit(1).get();
    if (sessionsSnapshot.docs.isNotEmpty) return;

    final legacyCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chat_messages');
    final legacySnapshot = await legacyCollection.orderBy('order').get();
    if (legacySnapshot.docs.isEmpty) return;

    final messages = legacySnapshot.docs
        .map((doc) => ChatMessage.fromJson(doc.data()))
        .toList();
    final firstUserMessage = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => messages.first,
    );

    final now = DateTime.now();
    final chatDoc = _collection(uid).doc();
    final title = _deriveTitle(firstUserMessage.text);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(chatDoc, {
      'title': title,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });
    for (var i = 0; i < messages.length; i++) {
      batch.set(chatDoc.collection('messages').doc(i.toString()), {
        ...messages[i].toJson(),
        'order': i,
      });
    }
    for (final doc in legacySnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  String _deriveTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ChatSession.defaultTitle;
    return trimmed.length > 40 ? '${trimmed.substring(0, 40)}...' : trimmed;
  }
}
