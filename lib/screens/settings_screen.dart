import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/services/auth_service.dart';
import 'package:ogrenme_asistani/services/chat_font_size.dart';
import 'package:ogrenme_asistani/services/chat_font_size_controller.dart';
import 'package:ogrenme_asistani/services/theme_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _dailyReminderKey = 'daily_reminder_enabled';

  String? _versionLabel;
  bool _dailyReminderEnabled = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadNotificationPreference();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = 'Sürüm ${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dailyReminderEnabled = prefs.getBool(_dailyReminderKey) ?? false;
    });
  }

  Future<void> _setDailyReminderEnabled(bool enabled) async {
    setState(() => _dailyReminderEnabled = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyReminderKey, enabled);
  }

  Future<void> _confirmAndDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabını ve tüm verilerini (sohbetler, kartlar, testler, dersler) '
          'kalıcı olarak silmek üzeresin. Bu işlem GERİ ALINAMAZ.\n\n'
          'Devam etmek istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() => _isDeleting = true);
    try {
      await _deleteUserData(user.uid);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'Bu işlem için tekrar giriş yapman gerekiyor. Lütfen çıkış yapıp '
                'tekrar giriş yaptıktan sonra hesabını silmeyi dene.'
          : 'Hesap silinemedi: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hesap silinemedi: $e')));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _deleteUserData(String uid) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    final chats = await userDoc.collection('chats').get();
    for (final chat in chats.docs) {
      final messages = await chat.reference.collection('messages').get();
      for (final message in messages.docs) {
        await message.reference.delete();
      }
      await chat.reference.delete();
    }

    for (final collectionName in [
      'flashcard_sets',
      'quiz_sets',
      'subjects',
      'chat_messages',
    ]) {
      final snapshot = await userDoc.collection(collectionName).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    await userDoc.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dark_mode_outlined),
                          const SizedBox(width: 16),
                          Text(
                            'Tema',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Açık'),
                              icon: Icon(Icons.light_mode_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Koyu'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('Sistem'),
                              icon: Icon(Icons.brightness_auto_outlined),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (selected) {
                            ThemeController.setThemeMode(selected.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<ChatFontSize>(
            valueListenable: ChatFontSizeController.fontSize,
            builder: (context, size, _) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_size),
                          const SizedBox(width: 16),
                          Text(
                            'Sohbet Yazı Boyutu',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ChatFontSize>(
                          segments: ChatFontSize.values
                              .map(
                                (value) => ButtonSegment(
                                  value: value,
                                  label: Text(value.label),
                                ),
                              )
                              .toList(),
                          selected: {size},
                          onSelectionChanged: (selected) {
                            ChatFontSizeController.setFontSize(
                              selected.first,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Günlük Hatırlatma Bildirimleri'),
              subtitle: const Text(
                'Yakında: düzenli çalışman için hatırlatma bildirimleri',
              ),
              value: _dailyReminderEnabled,
              onChanged: _setDailyReminderEnabled,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hesap',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış Yap'),
              onTap: () => AuthService.signOut(),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Hesabı Sil',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Kalıcı ve geri alınamaz'),
              trailing: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isDeleting ? null : _confirmAndDeleteAccount,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hakkında',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Öğrenme Asistanı'),
              subtitle: Text(_versionLabel ?? 'Sürüm bilgisi yükleniyor...'),
            ),
          ),
        ],
      ),
    );
  }
}
