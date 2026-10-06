import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/config/subject_style.dart';
import 'package:ogrenme_asistani/models/assistant_profile.dart';
import 'package:ogrenme_asistani/models/chat_session.dart';
import 'package:ogrenme_asistani/models/exam_goal.dart';
import 'package:ogrenme_asistani/models/streak_data.dart';
import 'package:ogrenme_asistani/screens/chat_screen.dart';
import 'package:ogrenme_asistani/screens/exam_goals_screen.dart';
import 'package:ogrenme_asistani/screens/path_detail_screen.dart';
import 'package:ogrenme_asistani/services/assistant_profile_repository.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/curriculum_path_repository.dart';
import 'package:ogrenme_asistani/services/exam_goal_repository.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';

/// Tab indexes of [MainScreen] that the home screen can jump to.
class HomeTabs {
  const HomeTabs._();
  static const curriculum = 1;
  static const chat = 2;
  static const sets = 3;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSelectTab});

  /// Switches the bottom navigation to another tab.
  final ValueChanged<int> onSelectTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _assistantProfileRepository = AssistantProfileRepository();
  final _streakRepository = StreakRepository();
  final _chatSessionRepository = ChatSessionRepository();
  final _examGoalRepository = ExamGoalRepository();
  final _pathRepository = CurriculumPathRepository();

  AssistantProfile? _assistantProfile;
  StreakData? _streak;
  List<ChatSession> _sessions = [];
  List<ExamGoal> _goals = [];
  List<CurriculumPathSummary> _tytPaths = [];
  StreamSubscription<StreakData>? _streakSubscription;
  StreamSubscription<List<ExamGoal>>? _goalsSubscription;

  @override
  void initState() {
    super.initState();
    _loadAssistantProfile();
    _loadSessions();
    _loadPaths();
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
  /// are none — the countdown card then invites the user to add one.
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

  Future<void> _loadPaths() async {
    try {
      final paths = await _pathRepository.loadAvailablePaths();
      if (!mounted) return;
      const order = [
        'Türkçe',
        'Matematik',
        'Geometri',
        'Fizik',
        'Kimya',
        'Biyoloji',
        'Tarih',
        'Coğrafya',
        'Felsefe',
        'Din Kültürü',
      ];
      final tyt = paths.where((p) => p.stage == 'TYT').toList()
        ..sort((a, b) {
          if (a.hasContent != b.hasContent) return a.hasContent ? -1 : 1;
          return order.indexOf(a.subject).compareTo(order.indexOf(b.subject));
        });
      setState(() => _tytPaths = tyt);
    } catch (_) {
      // The strip simply stays hidden when the müfredat can't be loaded.
    }
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

  void _openGoals() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ExamGoalsScreen()),
    );
  }

  void _openPath(CurriculumPathSummary path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PathDetailScreen(subjectKey: path.subjectKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _GreetingCard(
              assistantProfile: _assistantProfile,
              onChat: _continueChat,
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _GoalCard(
                      goal: _nextUpcomingGoal,
                      onTap: _openGoals,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _StreakCard(streak: _streak)),
                ],
              ),
            ),
            if (_tytPaths.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'TYT Dersleri',
                actionLabel: 'Tümü',
                onAction: () => widget.onSelectTab(HomeTabs.curriculum),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tytPaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => _SubjectChip(
                    path: _tytPaths[index],
                    onTap: () => _openPath(_tytPaths[index]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionHeader(title: 'Hızlı Erişim'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _QuickTile(
                  icon: Icons.route_rounded,
                  title: 'Müfredat',
                  subtitle: 'TYT · AYT · YDT',
                  color: const Color(0xFF7C4DFF),
                  onTap: () => widget.onSelectTab(HomeTabs.curriculum),
                ),
                _QuickTile(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Sohbet',
                  subtitle: 'Soru sor, konu anlat',
                  color: const Color(0xFF29B6F6),
                  onTap: _continueChat,
                ),
                _QuickTile(
                  icon: Icons.style_rounded,
                  title: 'Setlerim',
                  subtitle: 'Kart ve testlerin',
                  color: const Color(0xFFFFA726),
                  onTap: () => widget.onSelectTab(HomeTabs.sets),
                ),
                _QuickTile(
                  icon: Icons.flag_rounded,
                  title: 'Hedeflerim',
                  subtitle: 'Sınav takvimin',
                  color: const Color(0xFF66BB6A),
                  onTap: _openGoals,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _TipCard(colorScheme: colorScheme),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.assistantProfile, required this.onChat});

  final AssistantProfile? assistantProfile;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final name = assistantProfile?.name ?? 'Mira';
    final emoji = assistantProfile?.emoji ?? '👩‍🏫';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C4DFF), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merhaba! Ben $name 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'YKS yolculuğunda yanındayım.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onChat,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4F46E5),
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('Bugün ne öğrenmek istersin?'),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final ExamGoal? goal;
  final VoidCallback onTap;

  int _daysLeft(ExamGoal g) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final target = DateTime(g.date.year, g.date.month, g.date.day);
    return target.difference(todayDate).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = goal;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_rounded, color: scheme.primary),
              const SizedBox(height: 8),
              if (g == null) ...[
                Text(
                  'Hedef belirle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Sınav tarihini ekle, geri sayımı takip et.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Text(
                  _daysLeft(g) == 0 ? 'Bugün!' : '${_daysLeft(g)} gün',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  _daysLeft(g) == 0 ? g.name : '${g.name}\'e kaldı',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final StreakData? streak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = streak?.currentStreak ?? 0;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              days > 0 ? '$days gün' : 'Seri başlat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.orangeAccent,
              ),
            ),
            Text(
              days > 0
                  ? 'üst üste çalışıyorsun'
                  : 'Bugün çalışarak başla!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.path, required this.onTap});

  final CurriculumPathSummary path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = subjectStyleFor(path.subject);
    return SizedBox(
      width: 92,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: style.color.withValues(alpha: 0.16),
              border: Border.all(color: style.color.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(style.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    path.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.colorScheme});

  final ColorScheme colorScheme;

  static const _tips = [
    'Konuyu bitirir bitirmez 10 soru çöz; öğrendiğin şey kalıcı olur.',
    'Yanlış yaptığın soruyu not et, haftada bir tekrar bak.',
    'Uzun çalışma yerine 25 dakika çalış, 5 dakika dinlen.',
    'Her gün aynı saatte çalışmak, motivasyona ihtiyacını azaltır.',
    'Bir konuyu başkasına anlatabiliyorsan gerçekten öğrenmişsindir.',
    'Deneme sınavını gerçek sınav saatinde ve sessiz bir ortamda çöz.',
    'Zayıf olduğun konuya, sevdiğin konudan önce başla.',
    'Uyku, ezberin en iyi arkadaşı: sınav öncesi geceyi çalışarak geçirme.',
    'Formülleri ezberlemek yerine nereden geldiğini anlamaya çalış.',
    'Küçük hedefler koy: bugün iki konu, bu hafta bir deneme.',
  ];

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    final tip = _tips[day % _tips.length];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günün tavsiyesi',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(tip, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
