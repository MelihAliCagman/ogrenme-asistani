import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/widgets/flip_card.dart';

class FlashcardTile extends StatelessWidget {
  const FlashcardTile({super.key, required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildFace({
      required String label,
      required String text,
      required Color background,
      required Color foreground,
    }) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: foreground, fontSize: 16)),
          ],
        ),
      );
    }

    return FlipCard(
      front: buildFace(
        label: 'SORU',
        text: card.question,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
      back: buildFace(
        label: 'CEVAP',
        text: card.answer,
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
    );
  }
}
