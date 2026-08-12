import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/quiz_attempt.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

/// A tappable row summarizing one quiz attempt; tapping it opens a sheet
/// with a per-question correct/wrong breakdown for that attempt.
class QuizAttemptTile extends StatelessWidget {
  const QuizAttemptTile({
    super.key,
    required this.attemptNumber,
    required this.attempt,
    required this.questions,
  });

  final int attemptNumber;
  final QuizAttempt attempt;
  final List<QuizQuestion> questions;

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            expand: false,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '$attemptNumber. Deneme — ${attempt.correctCount}/${attempt.totalCount}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _dateLabel(attempt.completedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < questions.length; i++)
                    _AttemptQuestionRow(
                      question: questions[i],
                      wasWrong: attempt.wrongQuestionIndices.contains(i),
                      selectedOptionIndex: attempt.wrongSelections[i],
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.history),
      title: Text(
        '$attemptNumber. deneme: ${attempt.correctCount}/${attempt.totalCount}',
      ),
      trailing: Text(_dateLabel(attempt.completedAt), style: Theme.of(context).textTheme.bodySmall),
      onTap: () => _showDetails(context),
    );
  }
}

class _AttemptQuestionRow extends StatelessWidget {
  const _AttemptQuestionRow({
    required this.question,
    required this.wasWrong,
    required this.selectedOptionIndex,
  });

  final QuizQuestion question;
  final bool wasWrong;

  /// The option the user picked, if [wasWrong] — `null` when correct
  /// (the correct highlight alone is enough in that case).
  final int? selectedOptionIndex;

  @override
  Widget build(BuildContext context) {
    final color = wasWrong ? Theme.of(context).colorScheme.error : Colors.green;
    const optionLabels = ['A', 'B', 'C', 'D'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(wasWrong ? Icons.cancel : Icons.check_circle, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < question.options.length; i++)
            _buildOptionLine(context, optionLabels[i], i),
        ],
      ),
    );
  }

  Widget _buildOptionLine(BuildContext context, String label, int index) {
    final isCorrect = index == question.correctIndex;
    final isUserWrongPick = wasWrong && index == selectedOptionIndex;

    Color? background;
    Color foreground = Theme.of(context).colorScheme.onSurface;
    if (isCorrect) {
      background = Colors.green.withValues(alpha: 0.15);
      foreground = Colors.green.shade800;
    } else if (isUserWrongPick) {
      background = Theme.of(context).colorScheme.errorContainer;
      foreground = Theme.of(context).colorScheme.onErrorContainer;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 26, bottom: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: background != null
              ? Border.all(color: foreground.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Text(
              '$label. ',
              style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Text(question.options[index], style: TextStyle(color: foreground)),
            ),
            if (isCorrect)
              Icon(Icons.check, color: foreground, size: 16)
            else if (isUserWrongPick)
              Icon(Icons.close, color: foreground, size: 16),
          ],
        ),
      ),
    );
  }
}
