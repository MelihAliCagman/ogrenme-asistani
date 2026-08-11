import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/chat_session.dart';
import 'package:ogrenme_asistani/screens/chat_screen.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _repository = ChatSessionRepository();
  List<ChatSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    final sessions = await _repository.loadAll(uid);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _createChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final session = await _repository.createChat(uid);
    if (!mounted) return;
    await _openChat(session);
  }

  Future<void> _openChat(ChatSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: session.id,
          initialTitle: session.title,
        ),
      ),
    );
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetlerim')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createChat,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henüz sohbet yok. Yeni bir sohbet başlatmak için "+" butonuna bas.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(session.title),
            subtitle: Text(_formatRelativeTime(session.updatedAt)),
            onTap: () => _openChat(session),
          ),
        );
      },
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }
}
