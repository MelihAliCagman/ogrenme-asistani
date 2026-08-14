import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/set_format.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/create_set_screen.dart';
import 'package:ogrenme_asistani/screens/subject_sets_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final CardSetRepository _repository = CardSetRepository();
  final QuizSetRepository _quizRepository = QuizSetRepository();
  final SubjectRepository _subjectRepository = SubjectRepository();
  List<FlashcardSet> _cardSets = [];
  List<QuizSet> _quizSets = [];
  List<Subject> _subjects = [];
  StreamSubscription<List<Subject>>? _subjectsSubscription;
  bool _isLoadingSets = true;

  @override
  void initState() {
    super.initState();
    _loadSets();
    _watchSubjects();
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

  Future<void> _loadSets() async {
    final results = await Future.wait([
      _repository.loadAll(),
      _quizRepository.loadAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _cardSets = results[0] as List<FlashcardSet>;
      _quizSets = results[1] as List<QuizSet>;
      _isLoadingSets = false;
    });
  }

  Future<void> _openCreateScreen(SetFormat format) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateSetScreen(format: format),
      ),
    );
    if (created == true) _loadSets();
  }

  Future<void> _openSubject(Subject? subject) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubjectSetsScreen(subject: subject),
      ),
    );
    _loadSets();
  }

  (int, int) _countsFor(String? subjectId) {
    final cardCount = _cardSets.where((s) => s.subjectId == subjectId).length;
    final quizCount = _quizSets.where((s) => s.subjectId == subjectId).length;
    return (cardCount, quizCount);
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Çalışma Setlerim')),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openCreateScreen(SetFormat.flashcards),
                icon: const Icon(Icons.style_outlined),
                label: const Text('Kart Oluştur'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openCreateScreen(SetFormat.multipleChoice),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Test Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasGeneral =
        _cardSets.any((s) => s.subjectId == null) ||
        _quizSets.any((s) => s.subjectId == null);

    if (_subjects.isEmpty && !hasGeneral) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henüz set yok. Aşağıdaki butonlarla ilk kart veya test setini '
            'oluştur.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        for (final subject in _subjects) _buildSubjectTile(subject),
        if (hasGeneral) _buildGeneralTile(),
      ],
    );
  }

  String _countsLabel(int cardCount, int quizCount) {
    if (cardCount == 0 && quizCount == 0) return 'Henüz set yok';
    final parts = <String>[
      if (cardCount > 0) '$cardCount kart seti',
      if (quizCount > 0) '$quizCount test seti',
    ];
    return parts.join(' · ');
  }

  Widget _buildSubjectTile(Subject subject) {
    final (cardCount, quizCount) = _countsFor(subject.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: subject.color,
          child: Icon(Subject.icon, color: Colors.white),
        ),
        title: Text(subject.name),
        subtitle: Text(_countsLabel(cardCount, quizCount)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openSubject(subject),
      ),
    );
  }

  Widget _buildGeneralTile() {
    final (cardCount, quizCount) = _countsFor(null);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.inbox_outlined)),
        title: const Text('Genel'),
        subtitle: Text(_countsLabel(cardCount, quizCount)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openSubject(null),
      ),
    );
  }
}
