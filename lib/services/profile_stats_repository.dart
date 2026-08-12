import 'package:ogrenme_asistani/models/chat_session.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/profile_stats.dart';
import 'package:ogrenme_asistani/models/quiz_attempt.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/streak_data.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';

/// Aggregates counts and averages from across the app's repositories
/// for display on the profile screen and for achievement checks.
class ProfileStatsRepository {
  final _chatRepository = ChatSessionRepository();
  final _cardSetRepository = CardSetRepository();
  final _quizSetRepository = QuizSetRepository();
  final _streakRepository = StreakRepository();

  Future<ProfileStats> load(String uid) async {
    final chatsFuture = _chatRepository.loadAll(uid);
    final cardSetsFuture = _cardSetRepository.loadAll();
    final quizSetsFuture = _quizSetRepository.loadAll();
    final streakFuture = _streakRepository.load(uid);

    final List<ChatSession> chats = await chatsFuture;
    final List<FlashcardSet> cardSets = await cardSetsFuture;
    final List<QuizSet> quizSets = await quizSetsFuture;
    final StreakData streak = await streakFuture;

    final totalCards = cardSets.fold<int>(
      0,
      (sum, set) => sum + set.cards.length,
    );

    final List<QuizAttempt> allAttempts = quizSets
        .expand((set) => set.attempts)
        .toList();
    double? averageScore;
    if (allAttempts.isNotEmpty) {
      final totalPercent = allAttempts.fold<double>(
        0,
        (sum, attempt) =>
            sum +
            (attempt.totalCount == 0
                ? 0
                : attempt.correctCount / attempt.totalCount * 100),
      );
      averageScore = totalPercent / allAttempts.length;
    }

    return ProfileStats(
      totalChats: chats.length,
      totalCardSets: cardSets.length,
      totalQuizSets: quizSets.length,
      totalCards: totalCards,
      totalQuizAttempts: allAttempts.length,
      averageQuizScorePercent: averageScore,
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
    );
  }
}
