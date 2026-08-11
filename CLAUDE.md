# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

`ogrenme_asistani` is a Flutter app with three tabs (Sohbet, Kartlarım, Profil) behind a splash screen. It talks to the Gemini API for chat replies and flashcard generation, and persists chat history, flashcard sets, and the theme preference locally.

### Structure

- `lib/main.dart` — loads `.env`, initializes `ThemeController`, then runs the app inside a `ValueListenableBuilder<ThemeMode>` so theme changes rebuild `MaterialApp` without a restart.
- `lib/screens/`
  - `splash_screen.dart` — brief splash, then replaces itself with `MainScreen`.
  - `main_screen.dart` — bottom `NavigationBar` with `IndexedStack` (Sohbet / Kartlarım / Profil), so each tab keeps its state when switching.
  - `chat_screen.dart` — chat bubbles (user right, AI left), backed by `ChatRepository`; sends messages via `GeminiService.sendMessage`.
  - `cards_screen.dart` — paste text → `GeminiService.generateFlashcards` → saved as a `FlashcardSet` via `CardSetRepository`; lists existing sets, delete with confirmation.
  - `card_set_detail_screen.dart` — flippable flashcards for one set (`FlashcardTile`) plus entry point into `QuizScreen`.
  - `quiz_screen.dart` — shuffled question/reveal-answer/Bildim-Bilemedim quiz flow with a summary screen.
  - `profile_screen.dart` — app name/version (`package_info_plus`) and the dark-mode `Switch` bound to `ThemeController`.
- `lib/models/` — plain data classes with `fromJson`/`toJson`: `ChatMessage`, `Flashcard`, `FlashcardSet`.
- `lib/services/`
  - `gemini_service.dart` — all Gemini HTTP calls (`generativelanguage.googleapis.com`), auth via the `x-goog-api-key` header (not the `?key=` query param), JSON responses forced with `generationConfig.responseSchema`. Model defaults to `gemini-flash-lite-latest`; `gemini-2.0-flash-lite`/`gemini-2.5-flash-lite` are deprecated/retired — check `GET /v1beta/models` with the current key before changing the default.
  - `json_list_storage.dart` — generic `SharedPreferences`-backed JSON list persistence, shared by `ChatRepository` and `CardSetRepository`.
  - `theme_repository.dart` / `theme_controller.dart` — persisted light/dark `ThemeMode`, exposed as a `ValueNotifier` the whole app listens to.
- `lib/widgets/` — `flip_card.dart` (3D flip via `Transform`/`Matrix4`), `flashcard_tile.dart`, `labeled_info_card.dart` (shared question/answer box styling used by both flashcards and the quiz screen).

### Environment

- Gemini API key lives in `.env` as `GEMINI_API_KEY` (gitignored; `.env.example` documents the shape). Loaded via `flutter_dotenv` in `main()` before `runApp`.
- `.env` is declared as a Flutter asset in `pubspec.yaml` so `flutter_dotenv` can read it on every platform, including web.

### Known environment issue

`flutter doctor` may report Visual Studio missing the "Desktop development with C++" workload — this blocks `flutter run -d windows` / `flutter build windows` specifically. Android, web, and other targets are unaffected.

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
