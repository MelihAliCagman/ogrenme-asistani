import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

/// Small pill showing a quiz set's question type (e.g. "Çoktan Seçmeli"),
/// styled to match [SubjectChip] so set lists read consistently.
class QuizFormatChip extends StatelessWidget {
  const QuizFormatChip({super.key, required this.format});

  final QuestionType format;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        format.badgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.onTertiaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
