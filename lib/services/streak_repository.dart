import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/streak_data.dart';

/// Tracks a simple daily-use streak under `users/{uid}.streak` — how
/// many days in a row the user has interacted with a chat, flashcard
/// set, or quiz. No notifications yet; this just records and shows the
/// data for a later reminder feature.
class StreakRepository {
  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<StreakData> load(String uid) async {
    final snapshot = await _doc(uid).get();
    final raw = snapshot.data()?['streak'] as Map<String, dynamic>?;
    if (raw == null) return StreakData.empty();
    return StreakData.fromJson(raw);
  }

  /// Live updates of the streak, so any screen watching this (e.g. the
  /// "Bugün Ne Çalışayım?" hint or the profile stats) reflects an
  /// interaction that just happened elsewhere without needing to be
  /// reopened.
  Stream<StreakData> watch(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      final raw = snapshot.data()?['streak'] as Map<String, dynamic>?;
      return raw == null ? StreakData.empty() : StreakData.fromJson(raw);
    });
  }

  /// Call whenever the user meaningfully interacts with a chat, card
  /// set, or quiz. The streak counters only change on the first call
  /// each day, but [subjectId]/[subjectName] (the subject that activity
  /// belonged to, if any) are always recorded so the most recent one is
  /// reflected — used by the "Bugün Ne Çalışayım?" hint.
  Future<void> recordActivityToday(
    String uid, {
    String? subjectId,
    String? subjectName,
  }) async {
    final current = await load(uid);
    final today = _dateOnly(DateTime.now());
    final lastActive = current.lastActiveDate == null
        ? null
        : _dateOnly(current.lastActiveDate!);

    var currentStreak = current.currentStreak;
    var longestStreak = current.longestStreak;
    var lastActiveDate = current.lastActiveDate ?? today;

    if (lastActive != today) {
      final isConsecutiveDay =
          lastActive != null && today.difference(lastActive).inDays == 1;
      currentStreak = isConsecutiveDay ? current.currentStreak + 1 : 1;
      longestStreak = currentStreak > current.longestStreak
          ? currentStreak
          : current.longestStreak;
      lastActiveDate = today;
    }

    final updated = StreakData(
      lastActiveDate: lastActiveDate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastSubjectId: subjectId,
      lastSubjectName: subjectName,
    );
    await _doc(uid).set({'streak': updated.toJson()}, SetOptions(merge: true));
  }

  /// The local calendar day (year/month/day), represented in UTC so day
  /// differences are exact 24h multiples even in DST-observing regions —
  /// `DateTime(y, m, d).difference(...)` on a *local* midnight can be off
  /// by an hour on a DST transition day, which would corrupt the
  /// consecutive-day check below.
  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
