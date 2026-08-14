import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/profile_stats.dart';

class _Achievement {
  const _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool Function(ProfileStats stats) isUnlocked;
}

final List<_Achievement> _achievements = [
  _Achievement(
    title: 'İlk Adım',
    description: 'İlk sohbetini başlattın',
    icon: Icons.chat_bubble_outline,
    isUnlocked: (stats) => stats.totalChats >= 1,
  ),
  _Achievement(
    title: 'İlk Testini Çözdün',
    description: 'İlk çoktan seçmeli testini tamamladın',
    icon: Icons.quiz_outlined,
    isUnlocked: (stats) => stats.totalQuizAttempts >= 1,
  ),
  _Achievement(
    title: '7 Gün Üst Üste Çalıştın',
    description: 'En az 7 gün üst üste uygulamayla etkileşime girdin',
    icon: Icons.local_fire_department_outlined,
    isUnlocked: (stats) => stats.longestStreak >= 7,
  ),
  _Achievement(
    title: '50 Kart Öğrendin',
    description: 'Toplamda 50 veya daha fazla hafıza kartı oluşturdun',
    icon: Icons.style_outlined,
    isUnlocked: (stats) => stats.totalCards >= 50,
  ),
  _Achievement(
    title: 'Test Ustası',
    description: 'En az 3 testte ortalama %80 ve üzeri başarı elde ettin',
    icon: Icons.emoji_events_outlined,
    isUnlocked: (stats) =>
        stats.totalQuizAttempts >= 3 &&
        (stats.averageQuizScorePercent ?? 0) >= 80,
  ),
];

/// Full-screen view of all achievements ("Rozetlerim"), reached from a
/// tappable row on the Profil screen.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.stats});

  final ProfileStats? stats;

  @override
  Widget build(BuildContext context) {
    final currentStats = stats;
    final unlockedCount = currentStats == null
        ? 0
        : _achievements.where((a) => a.isUnlocked(currentStats)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Rozetlerim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$unlockedCount / ${_achievements.length} rozet kazanıldı',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          GridView(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 88,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final achievement in _achievements)
                _AchievementTile(
                  achievement: achievement,
                  unlocked:
                      currentStats != null && achievement.isUnlocked(currentStats),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final _Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = unlocked
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Opacity(
      opacity: unlocked ? 1 : 0.5,
      child: Card(
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(achievement.description)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  unlocked ? achievement.icon : Icons.lock_outline,
                  color: unlocked ? colorScheme.primary : foreground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    achievement.title,
                    style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
