import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/screens/quiz_screen.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';
import 'package:ogrenme_asistani/widgets/flashcard_tile.dart';

class CardSetDetailScreen extends StatefulWidget {
  const CardSetDetailScreen({
    super.key,
    required this.cardSet,
    this.onAllCardsReviewed,
  });

  final FlashcardSet cardSet;

  /// Called the first time every card in the set has either been
  /// flipped at least once here, or reviewed via a full "Quiz Modu"
  /// session — whichever happens first. Used by the Ders Yolları path
  /// screen to mark that node's flashcard content as completed; unused
  /// (and inert) everywhere else this screen is opened from.
  final VoidCallback? onAllCardsReviewed;

  @override
  State<CardSetDetailScreen> createState() => _CardSetDetailScreenState();
}

class _CardSetDetailScreenState extends State<CardSetDetailScreen> {
  final Set<int> _flippedIndices = {};
  bool _reviewReported = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      StreakRepository().recordActivityToday(
        uid,
        subjectId: widget.cardSet.subjectId,
      );
    }
  }

  void _reportAllReviewed() {
    if (_reviewReported) return;
    _reviewReported = true;
    widget.onAllCardsReviewed?.call();
  }

  void _onCardFlipped(int index) {
    _flippedIndices.add(index);
    if (_flippedIndices.length == widget.cardSet.cards.length) {
      _reportAllReviewed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cardSet.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      cardSet: widget.cardSet,
                      onFinished: _reportAllReviewed,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.quiz),
              label: const Text('Tekrar Et (Quiz Modu)'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: widget.cardSet.cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return FlashcardTile(
                    card: widget.cardSet.cards[index],
                    onFlip: () => _onCardFlipped(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
