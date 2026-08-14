import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/chat_session.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/card_set_detail_screen.dart';
import 'package:ogrenme_asistani/screens/chat_screen.dart';
import 'package:ogrenme_asistani/screens/quiz_history_screen.dart';
import 'package:ogrenme_asistani/screens/quiz_set_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subject});

  final Subject subject;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final _chatRepository = ChatSessionRepository();
  final _cardSetRepository = CardSetRepository();
  final _quizSetRepository = QuizSetRepository();
  List<ChatSession> _chats = [];
  List<FlashcardSet> _cardSets = [];
  List<QuizSet> _quizSets = [];
  StreamSubscription<List<ChatSession>>? _chatsSubscription;
  StreamSubscription<List<FlashcardSet>>? _cardSetsSubscription;
  StreamSubscription<List<QuizSet>>? _quizSetsSubscription;
  bool _isLoadingChats = true;
  bool _isLoadingCardSets = true;
  bool _isLoadingQuizSets = true;

  bool get _isLoading =>
      _isLoadingChats || _isLoadingCardSets || _isLoadingQuizSets;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _cardSetsSubscription?.cancel();
    _quizSetsSubscription?.cancel();
    super.dispose();
  }

  void _watch() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoadingChats = false;
        _isLoadingCardSets = false;
        _isLoadingQuizSets = false;
      });
      return;
    }
    _chatsSubscription = _chatRepository.watchAll(uid).listen((chats) {
      if (!mounted) return;
      setState(() {
        _chats = chats.where((c) => c.subjectId == widget.subject.id).toList();
        _isLoadingChats = false;
      });
    });
    _cardSetsSubscription = _cardSetRepository.watchAll().listen((cardSets) {
      if (!mounted) return;
      setState(() {
        _cardSets = cardSets
            .where((s) => s.subjectId == widget.subject.id)
            .toList();
        _isLoadingCardSets = false;
      });
    });
    _quizSetsSubscription = _quizSetRepository.watchAll().listen((quizSets) {
      if (!mounted) return;
      setState(() {
        _quizSets = quizSets
            .where((s) => s.subjectId == widget.subject.id)
            .toList();
        _isLoadingQuizSets = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.subject.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sohbetler'),
              Tab(text: 'Kartlar'),
              Tab(text: 'Testler'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildChatsTab(),
                  _buildCardSetsTab(),
                  _buildQuizSetsTab(),
                ],
              ),
      ),
    );
  }

  Future<void> _openQuizSet(QuizSet set) async {
    if (set.attempts.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuizSetScreen(
            quizSet: set,
            subject: widget.subject,
            returnToSubject: widget.subject,
          ),
        ),
      );
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(set.title),
        content: const Text(
          'Bu testi daha önce çözdün. Ne yapmak istersin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('history'),
            child: const Text('Geçmiş Sonuçları Analiz Et'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('solve'),
            child: const Text('Çöz'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'solve') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuizSetScreen(
            quizSet: set,
            subject: widget.subject,
            returnToSubject: widget.subject,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuizHistoryScreen(
            quizSet: set,
            subject: widget.subject,
            returnToSubject: widget.subject,
          ),
        ),
      );
    }
  }

  Widget _buildChatsTab() {
    if (_chats.isEmpty) {
      return const Center(child: Text('Bu derse bağlı sohbet yok.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _chats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(chat.title),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chat.id,
                    initialTitle: chat.title,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCardSetsTab() {
    if (_cardSets.isEmpty) {
      return const Center(child: Text('Bu derse bağlı kart seti yok.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _cardSets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final set = _cardSets[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.style),
            title: Text('${set.title} - ${set.cards.length} kart'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CardSetDetailScreen(
                    cardSet: set,
                    returnToSubject: widget.subject,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuizSetsTab() {
    if (_quizSets.isEmpty) {
      return const Center(child: Text('Bu derse bağlı test seti yok.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _quizSets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final set = _quizSets[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.quiz),
            title: Text('${set.title} - ${set.questions.length} soru'),
            onTap: () => _openQuizSet(set),
          ),
        );
      },
    );
  }
}
