import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/curriculum_path.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/set_format.dart';
import 'package:ogrenme_asistani/services/flashcard_progress_repository.dart';
import 'package:ogrenme_asistani/services/quiz_progress_repository.dart';

/// Lists the individual parts of one Ders Yolları node's content kind
/// (e.g. the 5 "Test N" multiple-choice parts) — opened from the node's
/// bottom sheet before drilling into any single part's actual
/// questions/cards. Styled like the Setlerim set list (Card + ListTile),
/// plus completion state, last score, and a "Kaldığı Yerden Devam Et"
/// tag when a part has an unfinished attempt saved.
class CurriculumPartsScreen extends StatefulWidget {
  const CurriculumPartsScreen({
    super.key,
    required this.nodeTitle,
    required this.kind,
    this.cardSets,
    this.quizSets,
    required this.isPartCompleted,
    required this.onOpenPart,
  }) : assert(
         (cardSets != null) ^ (quizSets != null),
         'exactly one of cardSets/quizSets must be provided',
       );

  final String nodeTitle;
  final PathContentKind kind;

  /// Populated when [kind] is [PathContentKind.flashcards]; `null` otherwise.
  final List<FlashcardSet>? cardSets;

  /// Populated for every other [kind]; `null` for flashcards.
  final List<QuizSet>? quizSets;

  /// Reads live progress state from the pushing screen — called fresh on
  /// every rebuild so it reflects completions marked while a part screen
  /// was open on top of this one.
  final bool Function(int partIndex) isPartCompleted;

  /// Pushes the real content screen for the part at [partIndex] and
  /// resolves once the user comes back — the parts list re-checks
  /// in-progress state on return.
  final Future<void> Function(int partIndex) onOpenPart;

  @override
  State<CurriculumPartsScreen> createState() => _CurriculumPartsScreenState();
}

class _CurriculumPartsScreenState extends State<CurriculumPartsScreen> {
  Set<int> _inProgressIndices = {};
  bool _isLoadingProgress = true;

  int get _partCount => (widget.cardSets ?? widget.quizSets)!.length;

  @override
  void initState() {
    super.initState();
    _loadInProgressState();
  }

  Future<void> _loadInProgressState() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingProgress = false);
      return;
    }
    final inProgress = <int>{};
    if (widget.cardSets != null) {
      final repo = FlashcardProgressRepository();
      for (var i = 0; i < widget.cardSets!.length; i++) {
        final saved = await repo.load(uid, widget.cardSets![i].id);
        if (saved != null && saved.currentIndex < saved.order.length) {
          inProgress.add(i);
        }
      }
    } else {
      final repo = QuizProgressRepository();
      for (var i = 0; i < widget.quizSets!.length; i++) {
        final saved = await repo.load(uid, widget.quizSets![i].id);
        if (saved != null && saved.currentIndex < saved.order.length) {
          inProgress.add(i);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _inProgressIndices = inProgress;
      _isLoadingProgress = false;
    });
  }

  Future<void> _open(int index) async {
    await widget.onOpenPart(index);
    if (!mounted) return;
    // Re-checks in-progress state and re-renders completion (read live
    // via widget.isPartCompleted) now that the part screen has popped.
    setState(() {});
    _loadInProgressState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.nodeTitle} - ${widget.kind.setFormat.label}'),
      ),
      body: _isLoadingProgress
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _partCount,
              itemBuilder: (context, index) => _buildTile(context, index),
            ),
    );
  }

  Widget _buildTile(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompleted = widget.isPartCompleted(index);
    final isInProgress = _inProgressIndices.contains(index);

    final String title;
    final String countLabel;
    String? scoreLabel;
    if (widget.cardSets != null) {
      final set = widget.cardSets![index];
      title = set.title;
      countLabel = '${set.cards.length} kart';
    } else {
      final set = widget.quizSets![index];
      title = set.title;
      countLabel = '${set.questions.length} soru';
      if (set.attempts.isNotEmpty) {
        final last = set.attempts.last;
        scoreLabel = 'Son deneme: ${last.correctCount}/${last.totalCount}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isCompleted ? Colors.green : colorScheme.outlineVariant,
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(countLabel),
            if (scoreLabel != null) Text(scoreLabel),
            if (isInProgress)
              Text(
                'Kaldığı Yerden Devam Et',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(index),
      ),
    );
  }
}
