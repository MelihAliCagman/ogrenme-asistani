import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/widgets/flip_card.dart';
import 'package:ogrenme_asistani/widgets/labeled_info_card.dart';

class FlashcardTile extends StatelessWidget {
  const FlashcardTile({super.key, required this.card, this.onFlip});

  final Flashcard card;

  /// See [FlipCard.onFlip].
  final VoidCallback? onFlip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FlipCard(
      onFlip: onFlip,
      front: LabeledInfoCard(
        label: 'SORU',
        text: card.question,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
        minHeight: 120,
      ),
      back: LabeledInfoCard(
        label: 'CEVAP',
        text: card.answer,
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        minHeight: 120,
      ),
    );
  }
}
