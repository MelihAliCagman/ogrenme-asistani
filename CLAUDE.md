# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This is a Flutter project (`ogrenme_asistani`) currently at the default `flutter create` scaffold — `lib/main.dart` is still the stock counter-app template, and `test/widget_test.dart` is the stock counter widget test. There is no custom architecture yet; when features are added, update this file with the actual structure (state management approach, navigation, folder layout, etc.).

- Dart SDK constraint: `^3.12.2` (see `pubspec.yaml`)
- Platforms scaffolded: android, ios, linux, macos, windows, web
- Lints: `package:flutter_lints/flutter.yaml` via `analysis_options.yaml` (no custom rule overrides yet)

## Commands

```
flutter pub get                 # install dependencies
flutter run                     # run the app (pick a connected device/emulator)
flutter run -d windows          # run on a specific platform
flutter analyze                 # static analysis / lint
flutter test                    # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter build windows           # build for a specific platform (apk, ios, web, windows, etc.)
```

There is no CI config or custom build tooling in this repo yet — the above are plain Flutter CLI commands.
