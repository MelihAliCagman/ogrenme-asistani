import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/services/theme_repository.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );
  static final ThemeRepository _repository = ThemeRepository();

  static Future<void> initialize() async {
    themeMode.value = await _repository.load();
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _repository.save(mode);
  }
}
