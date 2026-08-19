import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/quiz_set_screen.dart';
import 'package:ogrenme_asistani/widgets/quiz_attempt_tile.dart';

/// Shows past attempts for a quiz set without starting a new attempt —
/// reached when the user picks "Geçmiş Sonuçları Analiz Et" instead of
/// "Çöz".
class QuizHistoryScreen extends StatelessWidget {
  const QuizHistoryScreen({super.key, required this.quizSet, this.subject});

  final QuizSet quizSet;
  final Subject? subject;

  int get _bestPercent {
    if (quizSet.attempts.isEmpty) return 0;
    return quizSet.attempts
        .map((a) => a.totalCount == 0 ? 0 : (a.correctCount / a.totalCount * 100).round())
        .reduce((a, b) => a > b ? a : b);
  }

  double get _averagePercent {
    if (quizSet.attempts.isEmpty) return 0;
    final percents = quizSet.attempts.map(
      (a) => a.totalCount == 0 ? 0 : a.correctCount / a.totalCount * 100,
    );
    return percents.reduce((a, b) => a + b) / quizSet.attempts.length;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final attempts = quizSet.attempts;

    return Scaffold(
      appBar: AppBar(title: Text(quizSet.title)),
      body: attempts.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _buildSummaryCard(context, colorScheme),
                const SizedBox(height: 24),
                Text(
                  'Geçmiş Denemeler',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < attempts.length; i++)
                  QuizAttemptTile(
                    attemptNumber: i + 1,
                    attempt: attempts[i],
                    questions: quizSet.questions,
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizSetScreen(
                quizSet: quizSet,
                subject: subject,
              ),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Çöz'),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              icon: Icons.emoji_events_outlined,
              label: 'En İyi Skor',
              value: '%$_bestPercent',
              foreground: colorScheme.onPrimaryContainer,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.trending_up,
              label: 'Ortalama',
              value: '%${_averagePercent.round()}',
              foreground: colorScheme.onPrimaryContainer,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.repeat,
              label: 'Deneme',
              value: '${quizSet.attempts.length}',
              foreground: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz bir deneme geçmişi yok.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: foreground),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: foreground.withValues(alpha: 0.85), fontSize: 11),
        ),
      ],
    );
  }
}
