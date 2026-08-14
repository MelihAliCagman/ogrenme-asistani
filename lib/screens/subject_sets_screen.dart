import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/card_set_detail_screen.dart';
import 'package:ogrenme_asistani/screens/quiz_set_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';
import 'package:ogrenme_asistani/widgets/subject_picker.dart';

/// A flashcard or quiz set, wrapped so both kinds can be listed together
/// regardless of their underlying type.
class _SetItem {
  _SetItem.card(this.cardSet)
    : quizSet = null,
      createdAt = cardSet!.createdAt,
      title = cardSet.title;

  _SetItem.quiz(this.quizSet)
    : cardSet = null,
      createdAt = quizSet!.createdAt,
      title = quizSet.title;

  final FlashcardSet? cardSet;
  final QuizSet? quizSet;
  final DateTime createdAt;
  final String title;

  bool get isCard => cardSet != null;
}

/// Shows the flashcard and quiz sets belonging to a single subject (or
/// the subject-less "Genel" group when [subject] is `null`), opened by
/// tapping a subject in the Setlerim list.
class SubjectSetsScreen extends StatefulWidget {
  const SubjectSetsScreen({super.key, this.subject});

  final Subject? subject;

  @override
  State<SubjectSetsScreen> createState() => _SubjectSetsScreenState();
}

class _SubjectSetsScreenState extends State<SubjectSetsScreen> {
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

  Future<void> _loadSets() async {
    final results = await Future.wait([
      _repository.loadAll(),
      _quizRepository.loadAll(),
    ]);
    if (!mounted) return;
    setState(() {
      _cardSets = (results[0] as List<FlashcardSet>)
          .where((s) => s.subjectId == widget.subject?.id)
          .toList();
      _quizSets = (results[1] as List<QuizSet>)
          .where((s) => s.subjectId == widget.subject?.id)
          .toList();
      _isLoadingSets = false;
    });
  }

  Future<void> _deleteSet(FlashcardSet set) async {
    final confirmed = await _confirmDelete(set.title);
    if (confirmed != true) return;
    final all = await _repository.loadAll();
    await _repository.saveAll(all.where((s) => s.id != set.id).toList());
    _loadSets();
  }

  Future<void> _deleteQuizSet(QuizSet set) async {
    final confirmed = await _confirmDelete(set.title);
    if (confirmed != true) return;
    final all = await _quizRepository.loadAll();
    await _quizRepository.saveAll(all.where((s) => s.id != set.id).toList());
    _loadSets();
  }

  Future<void> _assignSubjectToCardSet(FlashcardSet set) async {
    final result = await pickSubject(
      context,
      subjects: _subjects,
      currentSubjectId: set.subjectId,
    );
    if (result == null) return;
    final subjectId = result == noSubjectPicked ? null : result;
    if (subjectId == set.subjectId) return;
    final updatedSet = FlashcardSet(
      id: set.id,
      title: set.title,
      createdAt: set.createdAt,
      cards: set.cards,
      subjectId: subjectId,
    );
    final all = await _repository.loadAll();
    await _repository.saveAll(
      all.map((s) => s.id == set.id ? updatedSet : s).toList(),
    );
    _loadSets();
  }

  Future<void> _assignSubjectToQuizSet(QuizSet set) async {
    final result = await pickSubject(
      context,
      subjects: _subjects,
      currentSubjectId: set.subjectId,
    );
    if (result == null) return;
    final subjectId = result == noSubjectPicked ? null : result;
    if (subjectId == set.subjectId) return;
    final updatedSet = set.withSubjectId(subjectId);
    final all = await _quizRepository.loadAll();
    await _quizRepository.saveAll(
      all.map((s) => s.id == set.id ? updatedSet : s).toList(),
    );
    _loadSets();
  }

  Future<void> _renameCardSet(FlashcardSet set) async {
    final newTitle = await _promptForNewTitle(set.title);
    if (newTitle == null) return;
    final updatedSet = FlashcardSet(
      id: set.id,
      title: newTitle,
      createdAt: set.createdAt,
      cards: set.cards,
      subjectId: set.subjectId,
    );
    final all = await _repository.loadAll();
    await _repository.saveAll(
      all.map((s) => s.id == set.id ? updatedSet : s).toList(),
    );
    _loadSets();
  }

  Future<void> _renameQuizSet(QuizSet set) async {
    final newTitle = await _promptForNewTitle(set.title);
    if (newTitle == null) return;
    final updatedSet = set.withTitle(newTitle);
    final all = await _quizRepository.loadAll();
    await _quizRepository.saveAll(
      all.map((s) => s.id == set.id ? updatedSet : s).toList(),
    );
    _loadSets();
  }

  Future<String?> _promptForNewTitle(String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeniden adlandır'),
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
    if (newTitle == null || newTitle.isEmpty || newTitle == currentTitle) {
      return null;
    }
    return newTitle;
  }

  Future<bool?> _confirmDelete(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seti sil'),
        content: Text('"$title" setini silmek istediğine emin misin?'),
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
  }

  List<_SetItem> get _items {
    final items = [
      for (final set in _cardSets) _SetItem.card(set),
      for (final set in _quizSets) _SetItem.quiz(set),
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    return Scaffold(
      appBar: AppBar(title: Text(subject?.name ?? 'Genel')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _items;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Bu derste henüz set yok. Setlerim ekranındaki butonlarla '
            'yeni bir kart veya test seti oluşturabilirsin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final item in items) _buildTile(item)],
    );
  }

  Widget _buildTile(_SetItem item) {
    return item.isCard
        ? _buildCardSetTile(item.cardSet!)
        : _buildQuizSetTile(item.quizSet!);
  }

  Widget _buildCardSetTile(FlashcardSet set) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.style),
        title: Text('${set.title} - ${set.cards.length} kart'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') _renameCardSet(set);
            if (value == 'subject') _assignSubjectToCardSet(set);
            if (value == 'delete') _deleteSet(set);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('Yeniden Adlandır')),
            PopupMenuItem(value: 'subject', child: Text('Ders Ata/Değiştir')),
            PopupMenuItem(value: 'delete', child: Text('Sil')),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CardSetDetailScreen(cardSet: set),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuizSetTile(QuizSet set) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.quiz),
        title: Text('${set.title} - ${set.questions.length} soru'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') _renameQuizSet(set);
            if (value == 'subject') _assignSubjectToQuizSet(set);
            if (value == 'delete') _deleteQuizSet(set);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('Yeniden Adlandır')),
            PopupMenuItem(value: 'subject', child: Text('Ders Ata/Değiştir')),
            PopupMenuItem(value: 'delete', child: Text('Sil')),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  QuizSetScreen(quizSet: set, subject: widget.subject),
            ),
          );
        },
      ),
    );
  }
}
