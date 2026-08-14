import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/quiz_attempt.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

/// A tappable card summarizing one quiz attempt; tapping it opens a sheet
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

  int get _percent => attempt.totalCount == 0
      ? 0
      : (attempt.correctCount / attempt.totalCount * 100).round();

  Color _scoreColor(BuildContext context) {
    if (_percent >= 80) return Colors.green.shade600;
    if (_percent >= 50) return Colors.orange.shade700;
    return Theme.of(context).colorScheme.error;
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            expand: false,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _DetailHeader(
                    attemptNumber: attemptNumber,
                    attempt: attempt,
                    percent: _percent,
                    scoreColor: _scoreColor(context),
                    dateLabel: _dateLabel(attempt.completedAt),
                  ),
                  const SizedBox(height: 20),
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
    final colorScheme = Theme.of(context).colorScheme;
    final scoreColor = _scoreColor(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _ScoreBadge(percent: _percent, color: scoreColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$attemptNumber. Deneme',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attempt.correctCount}/${attempt.totalCount} doğru · ${_dateLabel(attempt.completedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '%$percent',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.attemptNumber,
    required this.attempt,
    required this.percent,
    required this.scoreColor,
    required this.dateLabel,
  });

  final int attemptNumber;
  final QuizAttempt attempt;
  final int percent;
  final Color scoreColor;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wrongCount = attempt.wrongQuestionIndices.length;
    final correctCount = attempt.correctCount;

    return Row(
      children: [
        _ScoreBadge(percent: percent, color: scoreColor),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$attemptNumber. Deneme',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatChip(
                    icon: Icons.check_circle,
                    label: '$correctCount doğru',
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.cancel,
                    label: '$wrongCount yanlış',
                    color: colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final accent = wasWrong ? colorScheme.error : Colors.green.shade600;
    const optionLabels = ['A', 'B', 'C', 'D'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                wasWrong ? Icons.cancel : Icons.check_circle,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildOptionLine(context, optionLabels[i], i),
            ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
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
            child: Text(
              question.options[index],
              style: TextStyle(color: foreground),
            ),
          ),
          if (isCorrect)
            Icon(Icons.check, color: foreground, size: 16)
          else if (isUserWrongPick)
            Icon(Icons.close, color: foreground, size: 16),
        ],
      ),
    );
  }
}
