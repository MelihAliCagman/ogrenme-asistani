import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/services/theme_repository.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );
  static final ThemeRepository _repository = ThemeRepository();

  static Future<void> initialize() async {
    themeMode.value = await _repository.load();
  }

  static Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = mode;
    await _repository.save(mode);
  }
}
