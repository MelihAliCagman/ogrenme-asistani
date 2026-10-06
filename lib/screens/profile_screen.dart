import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/profile_stats.dart';
import 'package:ogrenme_asistani/models/streak_data.dart';
import 'package:ogrenme_asistani/models/user_profile.dart';
import 'package:ogrenme_asistani/screens/achievements_screen.dart';
import 'package:ogrenme_asistani/screens/avatar_selection_screen.dart';
import 'package:ogrenme_asistani/screens/exam_goals_screen.dart';
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _ProfileHeader(
                  profile: profile,
                  accountLabel: accountLabel,
                  streak: _stats?.currentStreak ?? 0,
                  onEditAvatar: _editAvatar,
                  onEditName: _editName,
                ),
                const SizedBox(height: 16),
                _StatsGrid(stats: _stats),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.emoji_events_rounded,
                        color: const Color(0xFFFFB300),
                        title: 'Rozetlerim',
                        subtitle: 'Kazandığın başarımlar',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  AchievementsScreen(stats: _stats),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 64),
                      _MenuTile(
                        icon: Icons.flag_rounded,
                        color: const Color(0xFF66BB6A),
                        title: 'Hedeflerim',
                        subtitle: 'Sınav hedeflerini ve tarihlerini yönet',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ExamGoalsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 64),
                      _MenuTile(
                        icon: Icons.cake_rounded,
                        color: const Color(0xFFEC407A),
                        title: 'Yaş',
                        subtitle: profile?.age != null
                            ? '${profile!.age}'
                            : 'Belirtilmedi (opsiyonel)',
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: _editAge,
                      ),
                      const Divider(height: 1, indent: 64),
                      _MenuTile(
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFF7C4DFF),
                        title: 'Asistanı Özelleştir',
                        subtitle: 'Asistanının adını ve karakterini değiştir',
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
                      const Divider(height: 1, indent: 64),
                      _MenuTile(
                        icon: Icons.settings_rounded,
                        color: const Color(0xFF78909C),
                        title: 'Ayarlar',
                        subtitle: 'Tema, yazı boyutu, hesap',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Gradient identity card: avatar, name, account and the current streak.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.accountLabel,
    required this.streak,
    required this.onEditAvatar,
    required this.onEditName,
  });

  final UserProfile? profile;
  final String? accountLabel;
  final int streak;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
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
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onEditAvatar,
            customBorder: const CircleBorder(),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: profile?.avatarColor ?? Colors.white24,
                  child: Icon(
                    profile?.avatarIcon ?? Icons.person,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onEditName,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile?.name ?? 'Kullanıcı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
                if (accountLabel != null)
                  Text(
                    accountLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    streak > 0
                        ? '🔥 $streak gün seri'
                        : '🔥 Bugün bir seri başlat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
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
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF29B6F6),
        label: 'Toplam Sohbet',
        value: '${stats?.totalChats ?? 0}',
      ),
      (
        icon: Icons.style_rounded,
        color: const Color(0xFFFFA726),
        label: 'Toplam Set',
        value: '${stats?.totalSets ?? 0}',
      ),
      (
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFF66BB6A),
        label: 'Ort. Test Başarısı',
        value: averageScore == null ? '—' : '%${averageScore.round()}',
      ),
      (
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF7043),
        label: 'En Uzun Seri',
        value: '${stats?.longestStreak ?? 0} gün',
      ),
    ];

    return GridView(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 84,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final tile in tiles)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tile.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tile.icon, color: tile.color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tile.value,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          tile.label,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
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
