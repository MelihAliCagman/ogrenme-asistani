import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/sample_lesson.dart';
import 'package:ogrenme_asistani/screens/sample_quiz_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';
import 'package:ogrenme_asistani/widgets/flashcard_tile.dart';

class DiscoverLessonDetailScreen extends StatefulWidget {
  const DiscoverLessonDetailScreen({super.key, required this.lesson});

  final SampleLesson lesson;

  @override
  State<DiscoverLessonDetailScreen> createState() =>
      _DiscoverLessonDetailScreenState();
}

class _DiscoverLessonDetailScreenState
    extends State<DiscoverLessonDetailScreen> {
  bool _isAdding = false;
  bool _added = false;
  String? _errorMessage;
  SampleDifficulty _difficulty = SampleDifficulty.medium;

  /// Adds all three difficulty levels (each its own flashcard set + quiz
  /// set) under one new subject, so the user gets the full range.
  Future<void> _addToMyLessons() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    try {
      final subject = await SubjectRepository().createSubject(
        uid,
        name: widget.lesson.title,
        color: widget.lesson.color,
      );

      final cardSetRepository = CardSetRepository();
      final cardSets = await cardSetRepository.loadAll();
      final newCardSets = [
        for (final entry in widget.lesson.levels.entries)
          FlashcardSet(
            id: 'sample-${DateTime.now().microsecondsSinceEpoch}-${entry.key.key}-cards',
            title: '${widget.lesson.title} (${entry.key.label})',
            createdAt: DateTime.now(),
            cards: entry.value.flashcards,
            subjectId: subject.id,
          ),
      ];
      await cardSetRepository.saveAll([...newCardSets, ...cardSets]);

      final quizSetRepository = QuizSetRepository();
      final quizSets = await quizSetRepository.loadAll();
      final newQuizSets = [
        for (final entry in widget.lesson.levels.entries)
          QuizSet(
            id: 'sample-${DateTime.now().microsecondsSinceEpoch}-${entry.key.key}-quiz',
            title: '${widget.lesson.title} (${entry.key.label})',
            createdAt: DateTime.now(),
            questions: entry.value.quizQuestions,
            subjectId: subject.id,
          ),
      ];
      await quizSetRepository.saveAll([...newQuizSets, ...quizSets]);

      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _added = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _errorMessage = 'Eklenemedi. Lütfen tekrar dener misin?';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lesson.title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ders Notu'),
              Tab(text: 'Kartlar'),
              Tab(text: 'Test'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilledButton.icon(
                onPressed: _isAdding || _added ? null : _addToMyLessons,
                icon: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_added ? Icons.check : Icons.add),
                label: Text(
                  _added
                      ? 'Eklendi ✓ (3 seviye)'
                      : _isAdding
                      ? 'Ekleniyor...'
                      : 'Kendi Derslerime Ekle (3 seviye)',
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSummaryTab(context),
                  _buildLevelAwareTab(context, isTest: false),
                  _buildLevelAwareTab(context, isTest: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(BuildContext context) {
    final lesson = widget.lesson;
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lesson.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: lesson.color.withValues(alpha: 0.4)),
          ),
          child: SelectableText(
            lesson.summaryText,
            style: TextStyle(color: colorScheme.onSurface, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<SampleDifficulty>(
          segments: SampleDifficulty.values
              .map(
                (d) => ButtonSegment(value: d, label: Text(d.label)),
              )
              .toList(),
          selected: {_difficulty},
          onSelectionChanged: (selection) {
            setState(() => _difficulty = selection.first);
          },
        ),
      ),
    );
  }

  Widget _buildLevelAwareTab(BuildContext context, {required bool isTest}) {
    final content = widget.lesson.levels[_difficulty];
    return Column(
      children: [
        _buildDifficultySelector(),
        Expanded(
          child: isTest
              ? _buildTestContent(context, content?.quizQuestions ?? [])
              : _buildCardsContent(content?.flashcards ?? []),
        ),
      ],
    );
  }

  Widget _buildCardsContent(List<Flashcard> cards) {
    if (cards.isEmpty) {
      return const Center(child: Text('Bu seviyede henüz kart yok.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => FlashcardTile(card: cards[index]),
    );
  }

  Widget _buildTestContent(BuildContext context, List<QuizQuestion> questions) {
    if (questions.isEmpty) {
      return const Center(child: Text('Bu seviyede henüz test yok.'));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '${questions.length} soruluk (${_difficulty.label}) çoktan seçmeli test',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SampleQuizScreen(
                      title: '${widget.lesson.title} (${_difficulty.label})',
                      questions: questions,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Teste Başla'),
            ),
          ],
        ),
      ),
    );
  }
}
