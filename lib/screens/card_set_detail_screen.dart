import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/screens/quiz_screen.dart';
import 'package:ogrenme_asistani/widgets/flashcard_tile.dart';

class CardSetDetailScreen extends StatelessWidget {
  const CardSetDetailScreen({super.key, required this.cardSet});

  final FlashcardSet cardSet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(cardSet.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(cardSet: cardSet),
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
                itemCount: cardSet.cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return FlashcardTile(card: cardSet.cards[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
