import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/assistant_profile.dart';
import 'package:ogrenme_asistani/models/chat_session.dart';
import 'package:ogrenme_asistani/models/exam_goal.dart';
import 'package:ogrenme_asistani/models/streak_data.dart';
import 'package:ogrenme_asistani/screens/chat_screen.dart';
import 'package:ogrenme_asistani/screens/path_subjects_screen.dart';
import 'package:ogrenme_asistani/screens/subjects_screen.dart';
import 'package:ogrenme_asistani/services/assistant_profile_repository.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/exam_goal_repository.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _assistantProfileRepository = AssistantProfileRepository();
  final _streakRepository = StreakRepository();
  final _chatSessionRepository = ChatSessionRepository();
  final _examGoalRepository = ExamGoalRepository();

  AssistantProfile? _assistantProfile;
  StreakData? _streak;
  List<ChatSession> _sessions = [];
  List<ExamGoal> _goals = [];
  StreamSubscription<StreakData>? _streakSubscription;
  StreamSubscription<List<ExamGoal>>? _goalsSubscription;

  @override
  void initState() {
    super.initState();
    _loadAssistantProfile();
    _loadSessions();
    _watchStreak();
    _watchGoals();
  }

  @override
  void dispose() {
    _streakSubscription?.cancel();
    _goalsSubscription?.cancel();
    super.dispose();
  }

  void _watchGoals() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _goalsSubscription = _examGoalRepository.watchAll(uid).listen((goals) {
      if (!mounted) return;
      setState(() => _goals = goals);
    });
  }

  /// The soonest upcoming goal (today or later), or `null` when there
  /// are none — the countdown card stays hidden in that case rather
  /// than showing a confusing empty/past state.
  ExamGoal? get _nextUpcomingGoal {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming =
        _goals.where((g) {
          final date = DateTime(g.date.year, g.date.month, g.date.day);
          return !date.isBefore(todayDate);
        }).toList()..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> _loadAssistantProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await _assistantProfileRepository.load(uid);
    if (!mounted) return;
    setState(() => _assistantProfile = profile);
  }

  Future<void> _loadSessions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final sessions = await _chatSessionRepository.loadAll(uid);
    if (!mounted) return;
    setState(() => _sessions = sessions);
  }

  void _watchStreak() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _streakSubscription = _streakRepository.watch(uid).listen((streak) {
      if (!mounted) return;
      setState(() => _streak = streak);
    });
  }

  Future<void> _continueChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final chatId = _sessions.isNotEmpty
        ? _sessions.first.id
        : _chatSessionRepository.newChatId(uid);
    final title = _sessions.isNotEmpty
        ? _sessions.first.title
        : ChatSession.defaultTitle;
    final subjectId = _sessions.isNotEmpty ? _sessions.first.subjectId : null;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          initialTitle: title,
          initialSubjectId: subjectId,
        ),
      ),
    );
    _loadSessions();
  }

  void _openSubjects() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubjectsScreen(initialTab: 0),
      ),
    );
  }

  void _openDiscover() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubjectsScreen(initialTab: 1),
      ),
    );
  }

  void _openPaths() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PathSubjectsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GreetingCard(assistantProfile: _assistantProfile),
          const SizedBox(height: 16),
          if (_nextUpcomingGoal != null) ...[
            _GoalCountdownCard(goal: _nextUpcomingGoal!),
            const SizedBox(height: 16),
          ],
          if (_streak != null) _StreakStatusCard(streak: _streak!),
          if (_streak != null) const SizedBox(height: 20),
          Text(
            'Hızlı Erişim',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickAccessTile(
                  icon: Icons.chat_bubble_outline,
                  label: 'Sohbet',
                  onTap: _continueChat,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAccessTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Derslerim',
                  onTap: _openSubjects,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAccessTile(
                  icon: Icons.explore_outlined,
                  label: 'Keşfet',
                  onTap: _openDiscover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAccessTile(
                  icon: Icons.route_outlined,
                  label: 'Ders Yolları',
                  onTap: _openPaths,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.assistantProfile});

  final AssistantProfile? assistantProfile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = assistantProfile?.name ?? 'Mira';
    final emoji = assistantProfile?.emoji ?? '👩‍🏫';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.surface,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba! Ben $name 👋',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugün ne öğrenmek istersin?',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCountdownCard extends StatelessWidget {
  const _GoalCountdownCard({required this.goal});

  final ExamGoal goal;

  int get _daysLeft {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final targetDate = DateTime(goal.date.year, goal.date.month, goal.date.day);
    return targetDate.difference(todayDate).inDays;
  }

  String get _countdownLabel {
    final days = _daysLeft;
    if (days == 0) return '${goal.name} bugün!';
    return '${goal.name}\'e $days gün kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _countdownLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugün de çalışmaya devam et!',
                  style: TextStyle(color: colorScheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Merges the streak count and the "what to study next" hint into one
/// card — both are motivational/status info, so showing them separately
/// just added vertical clutter.
class _StreakStatusCard extends StatelessWidget {
  const _StreakStatusCard({required this.streak});

  final StreakData streak;

  String _buildHint() {
    final last = streak.lastActiveDate;
    final subjectName = streak.lastSubjectName;
    if (last == null) {
      return 'Bugün yeni bir konu keşfetmeye ne dersin?';
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(last.year, last.month, last.day);
    final diff = todayDate.difference(lastDate).inDays;

    if (diff <= 0) {
      return subjectName != null
          ? 'Bugün $subjectName ile harika gidiyorsun, böyle devam!'
          : 'Bugün çalıştığın için harika gidiyorsun, böyle devam!';
    }
    if (diff == 1) {
      return subjectName != null
          ? 'Dün $subjectName çalıştın, bugün devam etmek ister misin?'
          : 'Dün çalıştın, bugün devam etmek ister misin?';
    }
    return subjectName != null
        ? 'En son $subjectName çalışmıştın. Kaldığın yerden devam et!'
        : 'Bugün yeni bir konu keşfetmeye ne dersin?';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final streakLabel = streak.currentStreak > 0
        ? '${streak.currentStreak} gün üst üste çalışıyorsun'
        : 'Bugün çalışarak bir seri başlat!';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(streakLabel, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    _buildHint(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact quick-access tile: icon on top, short label below, no
/// subtitle — three of these sit side by side instead of stacking as
/// full-width rows.
class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
