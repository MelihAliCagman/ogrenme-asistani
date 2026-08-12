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

  /// Live updates of the user's chat sessions, ordered like [loadAll].
  /// Used by screens that must reflect deletions/renames made elsewhere
  /// (e.g. the subject detail screen) without needing to be reopened.
  Stream<List<ChatSession>> watchAll(String uid) {
    return _collection(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatSession.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Generates an id for a new chat without writing anything — the
  /// document is only created once the first message is actually sent
  /// (see [createWithId]), so an abandoned draft never shows up in the
  /// chat list.
  String newChatId(String uid) => _collection(uid).doc().id;

  /// Persists a chat that was until now just a local draft (see
  /// [newChatId]). Called right before saving the first message.
  Future<void> createWithId(
    String uid,
    String chatId, {
    String? subjectId,
    String title = ChatSession.defaultTitle,
    bool titleEditedByUser = false,
  }) {
    final now = DateTime.now();
    final session = ChatSession(
      id: chatId,
      title: title,
      createdAt: now,
      updatedAt: now,
      subjectId: subjectId,
      titleEditedByUser: titleEditedByUser,
    );
    return _collection(uid).doc(chatId).set(session.toJson());
  }

  Future<ChatSession?> getById(String uid, String chatId) async {
    final doc = await _collection(uid).doc(chatId).get();
    final data = doc.data();
    if (data == null) return null;
    return ChatSession.fromJson(doc.id, data);
  }

  /// Updates the chat title. Pass [editedByUser] true only for an
  /// explicit user rename — once set, automatic title generation from
  /// the first message must no longer overwrite it.
  Future<void> updateTitle(
    String uid,
    String chatId,
    String title, {
    bool editedByUser = false,
  }) {
    return _collection(uid).doc(chatId).update({
      'title': title,
      if (editedByUser) 'titleEditedByUser': true,
    });
  }

  Future<void> touchUpdatedAt(String uid, String chatId) {
    return _collection(
      uid,
    ).doc(chatId).update({'updatedAt': DateTime.now().toIso8601String()});
  }

  Future<void> deleteChat(String uid, String chatId) async {
    final chatDoc = _collection(uid).doc(chatId);
    final messages = await chatDoc.collection('messages').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(chatDoc);
    await batch.commit();
  }

  Future<void> updateSubject(String uid, String chatId, String? subjectId) {
    return _collection(uid).doc(chatId).update({'subjectId': subjectId});
  }

  /// Reassigns every chat pointing at [subjectId] back to "Genel" (no
  /// subject) — used when the subject itself gets deleted.
  Future<void> clearSubjectFromChats(String uid, String subjectId) async {
    final snapshot = await _collection(
      uid,
    ).where('subjectId', isEqualTo: subjectId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'subjectId': null});
    }
    await batch.commit();
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
