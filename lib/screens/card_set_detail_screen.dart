import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/quiz_screen.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';
import 'package:ogrenme_asistani/widgets/flashcard_tile.dart';

class CardSetDetailScreen extends StatefulWidget {
  const CardSetDetailScreen({
    super.key,
    required this.cardSet,
    this.returnToSubject,
  });

  final FlashcardSet cardSet;

  /// Set only when this screen was opened from that subject's detail
  /// screen, so the quiz mode's back button can return there instead of
  /// popping all the way to Kartlarım.
  final Subject? returnToSubject;

  @override
  State<CardSetDetailScreen> createState() => _CardSetDetailScreenState();
}

class _CardSetDetailScreenState extends State<CardSetDetailScreen> {
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
                      returnToSubject: widget.returnToSubject,
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
                  return FlashcardTile(card: widget.cardSet.cards[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
