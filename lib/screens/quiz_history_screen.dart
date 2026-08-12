import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/quiz_set_screen.dart';
import 'package:ogrenme_asistani/widgets/quiz_attempt_tile.dart';

/// Shows past attempts for a quiz set without starting a new attempt —
/// reached when the user picks "Geçmiş Sonuçları Analiz Et" instead of
/// "Çöz".
class QuizHistoryScreen extends StatelessWidget {
  const QuizHistoryScreen({
    super.key,
    required this.quizSet,
    this.subject,
    this.returnToSubject,
  });

  final QuizSet quizSet;
  final Subject? subject;
  final Subject? returnToSubject;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${quizSet.title} - Geçmiş')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Geçmiş Denemeler',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < quizSet.attempts.length; i++)
            QuizAttemptTile(
              attemptNumber: i + 1,
              attempt: quizSet.attempts[i],
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
                returnToSubject: returnToSubject,
              ),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Çöz'),
      ),
    );
  }
}
