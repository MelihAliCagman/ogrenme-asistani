import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/card_set_detail_screen.dart';
import 'package:ogrenme_asistani/screens/quiz_set_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/gemini_service.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';
import 'package:ogrenme_asistani/widgets/subject_chip.dart';
import 'package:ogrenme_asistani/widgets/subject_picker.dart';

enum _GenerationFormat { flashcards, quiz }

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final CardSetRepository _repository = CardSetRepository();
  final QuizSetRepository _quizRepository = QuizSetRepository();
  final SubjectRepository _subjectRepository = SubjectRepository();
  List<FlashcardSet> _cardSets = [];
  List<QuizSet> _quizSets = [];
  List<Subject> _subjects = [];
  StreamSubscription<List<Subject>>? _subjectsSubscription;
  String? _selectedSubjectId;
  _GenerationFormat _format = _GenerationFormat.flashcards;
  int _flashcardCount = 10;
  String _activeFilter = _filterAll;

  static const _filterAll = '__all__';
  static const _filterGeneral = '__general__';
  bool _isLoading = false;
  bool _isLoadingSets = true;
  String? _errorMessage;

  final ScrollController _listScrollController = ScrollController();
  bool _formCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadSets();
    _watchSubjects();
    _listScrollController.addListener(_handleListScroll);
  }

  void _handleListScroll() {
    final offset = _listScrollController.offset;
    if (offset > 24 && !_formCollapsed) {
      setState(() => _formCollapsed = true);
    } else if (offset <= 4 && _formCollapsed) {
      setState(() => _formCollapsed = false);
    }
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

  Subject? _subjectFor(String? subjectId) {
    if (subjectId == null) return null;
    for (final subject in _subjects) {
      if (subject.id == subjectId) return subject;
    }
    return null;
  }

  Future<void> _pickSubjectForNewSet() async {
    final subjectId = await pickSubject(
      context,
      subjects: _subjects,
      currentSubjectId: _selectedSubjectId,
    );
    if (subjectId == null || !mounted) return;
    setState(() {
      _selectedSubjectId = subjectId == noSubjectPicked ? null : subjectId;
    });
  }

  Future<void> _generate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_format == _GenerationFormat.flashcards) {
        final result = await _geminiService.generateFlashcards(
          text,
          cardCount: _flashcardCount,
        );
        final newSet = FlashcardSet(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: result.title,
          createdAt: DateTime.now(),
          cards: result.cards,
          subjectId: _selectedSubjectId,
        );
        if (!mounted) return;
        setState(() {
          _cardSets = [newSet, ..._cardSets];
          _controller.clear();
        });
        await _repository.saveAll(_cardSets);
      } else {
        final result = await _geminiService.generateQuiz(text);
        final newSet = QuizSet(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: result.title,
          createdAt: DateTime.now(),
          questions: result.questions,
          subjectId: _selectedSubjectId,
        );
        if (!mounted) return;
        setState(() {
          _quizSets = [newSet, ..._quizSets];
          _controller.clear();
        });
        await _quizRepository.saveAll(_quizSets);
      }
    } catch (e) {
      debugPrint('[CardsScreen] Oluşturma başarısız: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Oluşturulamadı. Lütfen internet bağlantını kontrol edip tekrar dener misin?';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteSet(FlashcardSet set) async {
    final confirmed = await _confirmDelete(set.title);
    if (confirmed != true) return;

    setState(() {
      _cardSets = _cardSets.where((s) => s.id != set.id).toList();
    });
    await _repository.saveAll(_cardSets);
  }

  Future<void> _deleteQuizSet(QuizSet set) async {
    final confirmed = await _confirmDelete(set.title);
    if (confirmed != true) return;

    setState(() {
      _quizSets = _quizSets.where((s) => s.id != set.id).toList();
    });
    await _quizRepository.saveAll(_quizSets);
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
    setState(() {
      _cardSets = _cardSets
          .map((s) => s.id == set.id ? updatedSet : s)
          .toList();
    });
    await _repository.saveAll(_cardSets);
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
    setState(() {
      _quizSets = _quizSets
          .map((s) => s.id == set.id ? updatedSet : s)
          .toList();
    });
    await _quizRepository.saveAll(_quizSets);
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
    setState(() {
      _cardSets = _cardSets.map((s) => s.id == set.id ? updatedSet : s).toList();
    });
    await _repository.saveAll(_cardSets);
  }

  Future<void> _renameQuizSet(QuizSet set) async {
    final newTitle = await _promptForNewTitle(set.title);
    if (newTitle == null) return;
    final updatedSet = set.withTitle(newTitle);
    setState(() {
      _quizSets = _quizSets.map((s) => s.id == set.id ? updatedSet : s).toList();
    });
    await _quizRepository.saveAll(_quizSets);
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

  List<FlashcardSet> _applyFilter(List<FlashcardSet> sets) {
    if (_activeFilter == _filterAll) return sets;
    if (_activeFilter == _filterGeneral) {
      return sets.where((s) => s.subjectId == null).toList();
    }
    return sets.where((s) => s.subjectId == _activeFilter).toList();
  }

  List<QuizSet> _applyQuizFilter(List<QuizSet> sets) {
    if (_activeFilter == _filterAll) return sets;
    if (_activeFilter == _filterGeneral) {
      return sets.where((s) => s.subjectId == null).toList();
    }
    return sets.where((s) => s.subjectId == _activeFilter).toList();
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

  @override
  void dispose() {
    _controller.dispose();
    _listScrollController.dispose();
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Çalışma Setlerim')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<_GenerationFormat>(
              segments: const [
                ButtonSegment(
                  value: _GenerationFormat.flashcards,
                  label: Text('Hafıza Kartı'),
                  icon: Icon(Icons.style_outlined),
                ),
                ButtonSegment(
                  value: _GenerationFormat.quiz,
                  label: Text('Çoktan Seçmeli Test'),
                  icon: Icon(Icons.quiz_outlined),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (selection) {
                setState(() {
                  _format = selection.first;
                  _formCollapsed = false;
                });
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _formCollapsed
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_format == _GenerationFormat.flashcards) ...[
                          Text(
                            'Kart sayısı',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 5, label: Text('5')),
                                ButtonSegment(value: 10, label: Text('10')),
                                ButtonSegment(value: 15, label: Text('15')),
                                ButtonSegment(value: 20, label: Text('20')),
                              ],
                              selected: {_flashcardCount},
                              onSelectionChanged: (selection) {
                                setState(
                                  () => _flashcardCount = selection.first,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_format == _GenerationFormat.quiz) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tek seferde en fazla 20 soru oluşturabilirsiniz, '
                                  'aynı konudan tekrar tekrar yeni testler '
                                  'oluşturabilirsiniz.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        TextField(
                          controller: _controller,
                          maxLines: 6,
                          minLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Ders notunu veya metni buraya yapıştır...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickSubjectForNewSet,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _subjectFor(_selectedSubjectId)?.name ??
                                      'Ders seç (opsiyonel)',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _generate,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            _isLoading
                                ? 'Oluşturuluyor...'
                                : _format == _GenerationFormat.flashcards
                                ? 'Kart Oluştur'
                                : 'Test Oluştur',
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterChips(),
                  Expanded(child: _buildSetList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    if (_subjects.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Tümü', _filterAll),
            const SizedBox(width: 8),
            _filterChip('Genel', _filterGeneral),
            for (final subject in _subjects) ...[
              const SizedBox(width: 8),
              _filterChip(subject.name, subject.id, color: subject.color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, {Color? color}) {
    final isSelected = _activeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _activeFilter = value),
      avatar: color == null
          ? null
          : CircleAvatar(backgroundColor: color, radius: 6),
      selectedColor: color?.withValues(alpha: 0.25),
    );
  }

  Widget _buildSetList() {
    if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_format == _GenerationFormat.flashcards) {
      final sortedCardSets = _applyFilter(List.of(_cardSets))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (sortedCardSets.isEmpty) {
        return Center(
          child: Text(
            _activeFilter == _filterAll
                ? 'Henüz kart seti yok. Bir metin yapıştırıp "Kart Oluştur"a bas.'
                : 'Bu filtreye uyan kart seti yok.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }
      return ListView(
        controller: _listScrollController,
        padding: const EdgeInsets.only(bottom: 16),
        children: [for (final set in sortedCardSets) _buildCardSetTile(set)],
      );
    }

    final sortedQuizSets = _applyQuizFilter(List.of(_quizSets))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (sortedQuizSets.isEmpty) {
      return Center(
        child: Text(
          _activeFilter == _filterAll
              ? 'Henüz test seti yok. Bir metin yapıştırıp "Test Oluştur"a bas.'
              : 'Bu filtreye uyan test seti yok.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView(
      controller: _listScrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [for (final set in sortedQuizSets) _buildQuizSetTile(set)],
    );
  }

  Widget _buildCardSetTile(FlashcardSet set) {
    final subject = _subjectFor(set.subjectId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.style),
        title: Text('${set.title} - ${set.cards.length} kart'),
        subtitle: subject == null ? null : SubjectChip(subject: subject),
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
    final subject = _subjectFor(set.subjectId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.quiz),
        title: Text('${set.title} - ${set.questions.length} soru'),
        subtitle: subject == null ? null : SubjectChip(subject: subject),
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
                  QuizSetScreen(quizSet: set, subject: subject),
            ),
          );
        },
      ),
    );
  }
}
