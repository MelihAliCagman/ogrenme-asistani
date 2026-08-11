import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/screens/avatar_selection_screen.dart';
import 'package:ogrenme_asistani/services/auth_service.dart';
import 'package:ogrenme_asistani/services/chat_font_size.dart';
import 'package:ogrenme_asistani/services/chat_font_size_controller.dart';
import 'package:ogrenme_asistani/services/theme_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = 'Sürüm ${info.version} (${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = AuthService.currentUser;
    final accountLabel = user == null
        ? null
        : (user.isAnonymous ? 'Misafir kullanıcı' : (user.email ?? user.displayName ?? 'Hesap'));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.school,
                    size: 40,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Öğrenme Asistanı',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _versionLabel ?? 'Sürüm bilgisi yükleniyor...',
                  style: Theme.of(context).textTheme.bodySmall,
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
          const SizedBox(height: 32),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Koyu Tema'),
                  subtitle: const Text('Açık ve koyu tema arasında geçiş yap'),
                  value: mode == ThemeMode.dark,
                  onChanged: (isDark) {
                    ThemeController.setDarkMode(isDark);
                  },
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
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Asistanı Özelleştir'),
              subtitle: const Text('Asistanının adını ve karakterini değiştir'),
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
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış Yap'),
              onTap: () => AuthService.signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
