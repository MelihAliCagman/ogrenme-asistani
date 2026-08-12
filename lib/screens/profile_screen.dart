import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/profile_stats.dart';
import 'package:ogrenme_asistani/models/streak_data.dart';
import 'package:ogrenme_asistani/models/user_profile.dart';
import 'package:ogrenme_asistani/screens/avatar_selection_screen.dart';
import 'package:ogrenme_asistani/screens/settings_screen.dart';
import 'package:ogrenme_asistani/services/auth_service.dart';
import 'package:ogrenme_asistani/services/profile_stats_repository.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';
import 'package:ogrenme_asistani/services/user_profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = UserProfileRepository();
  final _statsRepository = ProfileStatsRepository();
  final _streakRepository = StreakRepository();
  UserProfile? _profile;
  ProfileStats? _stats;
  StreamSubscription<StreakData>? _streakSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
    _watchStreak();
  }

  @override
  void dispose() {
    _streakSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    final stats = await _statsRepository.load(uid);
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  /// Keeps just the streak numbers fresh in real time (the rest of
  /// [_stats] only needs to be as fresh as the last full [_loadStats]).
  void _watchStreak() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    _streakSubscription = _streakRepository.watch(uid).listen((streak) {
      if (!mounted) return;
      final current = _stats;
      if (current == null) return;
      setState(() {
        _stats = ProfileStats(
          totalChats: current.totalChats,
          totalCardSets: current.totalCardSets,
          totalQuizSets: current.totalQuizSets,
          totalCards: current.totalCards,
          totalQuizAttempts: current.totalQuizAttempts,
          averageQuizScorePercent: current.averageQuizScorePercent,
          currentStreak: streak.currentStreak,
          longestStreak: streak.longestStreak,
        );
      });
    });
  }

  Future<void> _loadProfile() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    final loaded = await _repository.load(uid);
    if (!mounted) return;
    setState(() {
      _profile = loaded ?? _defaultProfile();
      _isLoading = false;
    });
  }

  UserProfile _defaultProfile() {
    final user = AuthService.currentUser;
    return UserProfile(
      name: user?.displayName ?? 'Kullanıcı',
      avatarIconCodePoint: UserProfile.defaultIcons.first.codePoint,
      avatarColor: UserProfile.defaultColors.first,
    );
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    setState(() => _profile = profile);
    await _repository.save(uid, profile);
  }

  Future<void> _editAvatar() async {
    final profile = _profile;
    if (profile == null) return;
    final result = await showModalBottomSheet<UserProfile>(
      context: context,
      showDragHandle: true,
      builder: (context) => _AvatarPickerSheet(profile: profile),
    );
    if (result == null) return;
    await _saveProfile(result);
  }

  Future<void> _editName() async {
    final profile = _profile;
    if (profile == null) return;
    final controller = TextEditingController(text: profile.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İsmini düzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == profile.name) return;
    await _saveProfile(profile.copyWith(name: newName));
  }

  Future<void> _editAge() async {
    final profile = _profile;
    if (profile == null) return;
    final controller = TextEditingController(
      text: profile.age?.toString() ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yaşını düzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Opsiyonel',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Temizle'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result.isEmpty) {
      await _saveProfile(profile.copyWith(clearAge: true));
      return;
    }
    final age = int.tryParse(result);
    if (age == null) return;
    await _saveProfile(profile.copyWith(age: age));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final accountLabel = user == null
        ? null
        : (user.isAnonymous
              ? 'Misafir kullanıcı'
              : (user.email ?? user.displayName ?? 'Hesap'));
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _editAvatar,
                        customBorder: const CircleBorder(),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: profile?.avatarColor,
                              child: Icon(
                                profile?.avatarIcon ?? Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                child: const Icon(Icons.edit, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _editName,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profile?.name ?? 'Kullanıcı',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit, size: 16),
                            ],
                          ),
                        ),
                      ),
                      if (accountLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          accountLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _StreakBadge(stats: _stats),
                const SizedBox(height: 16),
                _StatsGrid(stats: _stats),
                const SizedBox(height: 24),
                Text(
                  'Rozetler',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _AchievementsGrid(stats: _stats),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cake_outlined),
                    title: const Text('Yaş'),
                    subtitle: Text(
                      profile?.age != null
                          ? '${profile!.age}'
                          : 'Belirtilmedi (opsiyonel)',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _editAge,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: const Text('Asistanı Özelleştir'),
                    subtitle: const Text(
                      'Asistanının adını ve karakterini değiştir',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AvatarSelectionScreen(
                            onSaved: (_) => Navigator.of(context).pop(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Ayarlar'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.stats});

  final ProfileStats? stats;

  @override
  Widget build(BuildContext context) {
    final current = stats?.currentStreak ?? 0;
    final longest = stats?.longestStreak ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current > 0
                        ? '$current gün üst üste çalışıyorsun'
                        : 'Bugün çalışarak bir seri başlat!',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (longest > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'En uzun serin: $longest gün',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ProfileStats? stats;

  @override
  Widget build(BuildContext context) {
    final averageScore = stats?.averageQuizScorePercent;
    final tiles = [
      (
        icon: Icons.chat_bubble_outline,
        label: 'Toplam Sohbet',
        value: '${stats?.totalChats ?? 0}',
      ),
      (
        icon: Icons.style_outlined,
        label: 'Toplam Set',
        value: '${stats?.totalSets ?? 0}',
      ),
      (
        icon: Icons.emoji_events_outlined,
        label: 'Ort. Test Başarısı',
        value: averageScore == null ? '—' : '%${averageScore.round()}',
      ),
      (
        icon: Icons.local_fire_department_outlined,
        label: 'En Uzun Seri',
        value: '${stats?.longestStreak ?? 0} gün',
      ),
    ];

    return GridView(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 76,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final tile in tiles)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    tile.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tile.value,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tile.label,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

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

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.stats});

  final ProfileStats? stats;

  @override
  Widget build(BuildContext context) {
    final currentStats = stats;
    return GridView(
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
            unlocked: currentStats != null && achievement.isUnlocked(currentStats),
          ),
      ],
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

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({required this.profile});

  final UserProfile profile;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late IconData _selectedIcon = widget.profile.avatarIcon;
  late Color _selectedColor = widget.profile.avatarColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avatar Seç', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: UserProfile.defaultIcons.map((icon) {
                final isSelected = icon.codePoint == _selectedIcon.codePoint;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: isSelected
                        ? _selectedColor
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Renk Seç', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: UserProfile.defaultColors.map((color) {
                final isSelected = color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    widget.profile.copyWith(
                      avatarIconCodePoint: _selectedIcon.codePoint,
                      avatarColor: _selectedColor,
                    ),
                  );
                },
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
