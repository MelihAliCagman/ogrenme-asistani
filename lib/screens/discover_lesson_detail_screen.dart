import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/sample_lesson.dart';
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
      final newCardSet = FlashcardSet(
        id: 'sample-${DateTime.now().microsecondsSinceEpoch}-cards',
        title: widget.lesson.title,
        createdAt: DateTime.now(),
        cards: widget.lesson.flashcards,
        subjectId: subject.id,
      );
      await cardSetRepository.saveAll([newCardSet, ...cardSets]);

      final quizSetRepository = QuizSetRepository();
      final quizSets = await quizSetRepository.loadAll();
      final newQuizSet = QuizSet(
        id: 'sample-${DateTime.now().microsecondsSinceEpoch}-quiz',
        title: widget.lesson.title,
        createdAt: DateTime.now(),
        questions: widget.lesson.quizQuestions,
        subjectId: subject.id,
      );
      await quizSetRepository.saveAll([newQuizSet, ...quizSets]);

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
    final colorScheme = Theme.of(context).colorScheme;
    final lesson = widget.lesson;

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
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
                  ? 'Eklendi ✓'
                  : _isAdding
                  ? 'Ekleniyor...'
                  : 'Kendi Derslerime Ekle',
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
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
          const SizedBox(height: 24),
          Text(
            'Hafıza Kartları (${lesson.flashcards.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final card in lesson.flashcards)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FlashcardTile(card: card),
            ),
          const SizedBox(height: 12),
          Text(
            'Test Soruları (${lesson.quizQuestions.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final question in lesson.quizQuestions)
            _QuizPreviewCard(question: question),
        ],
      ),
    );
  }
}

class _QuizPreviewCard extends StatelessWidget {
  const _QuizPreviewCard({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const optionLabels = ['A', 'B', 'C', 'D'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              question.question,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${optionLabels[i]}. ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: i == question.correctIndex
                            ? Colors.green.shade700
                            : colorScheme.onSurface,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        question.options[i],
                        style: TextStyle(
                          color: i == question.correctIndex
                              ? Colors.green.shade700
                              : colorScheme.onSurface,
                          fontWeight: i == question.correctIndex
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (i == question.correctIndex)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 16,
                      ),
                  ],
                ),
              ),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                question.explanation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
