import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/chat_session.dart';
import 'package:ogrenme_asistani/models/streak_data.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/chat_screen.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';
import 'package:ogrenme_asistani/widgets/subject_chip.dart';
import 'package:ogrenme_asistani/widgets/subject_picker.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _repository = ChatSessionRepository();
  final _subjectRepository = SubjectRepository();
  final _streakRepository = StreakRepository();
  List<ChatSession> _sessions = [];
  List<Subject> _subjects = [];
  StreakData? _streak;
  StreamSubscription<List<Subject>>? _subjectsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _watchSubjects();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final streak = await _streakRepository.load(uid);
    if (!mounted) return;
    setState(() => _streak = streak);
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  void _watchSubjects() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _subjectsSubscription = _subjectRepository.watchAll(uid).listen((
      subjects,
    ) {
      if (!mounted) return;
      setState(() => _subjects = subjects);
    });
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
    final result = await pickSubject(context, subjects: _subjects);
    if (!mounted) return;
    final subjectId = (result == null || result == noSubjectPicked)
        ? null
        : result;
    final chatId = _repository.newChatId(uid);
    await _openChat(
      chatId: chatId,
      title: ChatSession.defaultTitle,
      subjectId: subjectId,
    );
  }

  Subject? _subjectFor(String? subjectId) {
    if (subjectId == null) return null;
    for (final subject in _subjects) {
      if (subject.id == subjectId) return subject;
    }
    return null;
  }

  Future<void> _renameChat(ChatSession session) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti yeniden adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty || newTitle == session.title) {
      return;
    }
    await _repository.updateTitle(
      uid,
      session.id,
      newTitle,
      editedByUser: true,
    );
    _loadSessions();
  }

  Future<void> _assignSubject(ChatSession session) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final result = await pickSubject(
      context,
      subjects: _subjects,
      currentSubjectId: session.subjectId,
    );
    if (result == null) return;
    final subjectId = result == noSubjectPicked ? null : result;
    if (subjectId == session.subjectId) return;
    await _repository.updateSubject(uid, session.id, subjectId);
    _loadSessions();
  }

  Future<void> _deleteChat(ChatSession session) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti sil'),
        content: Text(
          '"${session.title}" sohbetini silmek istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteChat(uid, session.id);
    _loadSessions();
  }

  Future<void> _openChat({
    required String chatId,
    required String title,
    String? subjectId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          initialTitle: title,
          initialSubjectId: subjectId,
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
      body: Column(
        children: [
          if (_streak != null) _StudyHintCard(streak: _streak!),
          Expanded(child: _buildBody()),
        ],
      ),
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
        final subject = _subjectFor(session.subjectId);
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(session.title),
            subtitle: Row(
              children: [
                Flexible(
                  child: Text(
                    _formatRelativeTime(session.updatedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subject != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: SubjectChip(subject: subject)),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') _renameChat(session);
                if (value == 'subject') _assignSubject(session);
                if (value == 'delete') _deleteChat(session);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Yeniden Adlandır'),
                ),
                PopupMenuItem(
                  value: 'subject',
                  child: Text('Ders Ata/Değiştir'),
                ),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
            onTap: () => _openChat(
              chatId: session.id,
              title: session.title,
              subjectId: session.subjectId,
            ),
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

class _StudyHintCard extends StatelessWidget {
  const _StudyHintCard({required this.streak});

  final StreakData streak;

  String _buildMessage() {
    final last = streak.lastActiveDate;
    final subjectName = streak.lastSubjectName;
    if (last == null) {
      return 'Bugün yeni bir konu keşfetmeye ne dersin? Keşfet sekmesindeki '
          'hazır derslere göz atabilirsin.';
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(last.year, last.month, last.day);
    final diff = todayDate.difference(lastDate).inDays;

    if (diff <= 0) {
      return '🔥 ${streak.currentStreak} gün üst üste çalışıyorsun, harika gidiyorsun!';
    }
    if (diff == 1) {
      return subjectName != null
          ? 'Dün $subjectName çalıştın, bugün devam etmek ister misin?'
          : 'Dün çalıştın, bugün devam etmek ister misin?';
    }
    return subjectName != null
        ? 'En son $subjectName çalışmıştın. Kaldığın yerden devam etmeye ne dersin?'
        : 'Bugün yeni bir konu keşfetmeye ne dersin? Keşfet sekmesindeki '
              'hazır derslere göz atabilirsin.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _buildMessage(),
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
