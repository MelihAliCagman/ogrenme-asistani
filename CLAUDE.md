# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

`ogrenme_asistani` is a Turkish-language, AI-assisted study app (Flutter, mainly Android) aimed at exam prep (YKS/TYT). Users chat with Gemini, generate flashcards and three kinds of quizzes from pasted text/PDFs, organize them into subjects ("Dersler"), and work through Duolingo-style "Ders Yolları" (curriculum paths). Auth and all user data live in Firebase (Authentication + Cloud Firestore); Gemini is called directly over HTTP. `README.md` has the user-facing feature list.

### App flow

`main.dart` loads `.env`, initializes Firebase, `ThemeController` and `ChatFontSizeController`, then runs the app inside a `ValueListenableBuilder<ThemeMode>` (theme changes rebuild `MaterialApp` without a restart). `SplashScreen` → `AuthGate` (`StreamBuilder` on auth state):

- signed out → `LoginScreen` (Google sign-in or guest)
- signed in but no assistant profile yet → `AvatarSelectionScreen`
- otherwise → `MainScreen`: `NavigationBar` + `IndexedStack` with 5 tabs (each keeps its state): **Ana Sayfa** (`HomeScreen`), **Sohbet** (`ChatWelcomeScreen`), **Setlerim** (`CardsScreen`), **Dersler** (`SubjectsScreen`), **Profil** (`ProfileScreen`).

### Structure

- `lib/screens/`
  - Chat: `chat_welcome_screen` (entry, session list via `chat_list_screen`), `chat_screen` (streamed Gemini replies, markdown rendering, photo questions via `image_picker`/`image_cropper`).
  - Sets: `cards_screen` (Setlerim list), `create_set_screen` (text/PDF → AI generation or manual cards; format + count + difficulty), `card_set_detail_screen` (flip cards, swipe bildim/bilemedim), `quiz_set_screen` + `quiz_screen` (multiple choice / fill-blank / true-false runs), `quiz_history_screen`, `sample_quiz_screen`.
  - Subjects: `subjects_screen`, `subject_detail_screen`, `subject_sets_screen` (per-subject chat/card/quiz tabs).
  - Ders Yolları: `path_exam_subjects_screen` (exam type → subject) → `path_subjects_screen` → `path_variants_screen` → `path_detail_screen` (unit accordion + zigzag node map with 4-slice progress ring) → `curriculum_parts_screen` (the parts of one content kind).
  - Keşfet: `discover_screen`, `discover_lesson_detail_screen` (public sample lessons, copy to own subjects).
  - Other: `home_screen` (exam countdown, streak, shortcuts), `exam_goals_screen`, `achievements_screen`, `profile_screen`, `settings_screen`, `avatar_selection_screen`, `login_screen`, `auth_gate`, `splash_screen`.
- `lib/models/` — plain data classes with `fromJson`/`toJson`: chat (`ChatMessage`, `ChatSession`), sets (`Flashcard`, `FlashcardSet`, `QuizQuestion` with `QuestionType`, `QuizSet`, `QuizAttempt`, `SetFormat`, `*InProgress`), `Subject`, `SampleLesson`, curriculum (`CurriculumPath` → `CurriculumUnit` → `CurriculumNode` → `Curriculum*Part`, `PathProgress`/`NodeProgress`), profile/gamification (`UserProfile`, `AssistantProfile`, `ProfileStats`, `StreakData`, `ExamGoal`).
- `lib/services/`
  - `gemini_service.dart` — all Gemini HTTP calls (`generativelanguage.googleapis.com`), auth via the `x-goog-api-key` header (not `?key=`). Chat uses `streamGenerateContent?alt=sse` with the full history; `generateFlashcards`/`generateQuiz`/`generateFillBlankQuestions`/`generateTrueFalseQuestions`/`generateChatTitle` force JSON via `generationConfig.responseSchema` and accept an optional inline file (PDF) via `inlineData`. Model defaults to `gemini-flash-lite-latest`; `gemini-2.0-flash-lite`/`gemini-2.5-flash-lite` are deprecated/retired — check `GET /v1beta/models` with the current key before changing the default.
  - `*_repository.dart` — Firestore persistence per feature, mostly under `users/{uid}/...` (chats + messages, flashcard_sets, quiz_sets, subjects, exam_goals, flashcard_progress, quiz_progress, path_progress, plus `streak`/`userProfile` fields on the user doc). `firestore_list_storage.dart` is the generic "list as one doc per item with an `order` field" helper; `json_list_storage.dart` is the old `SharedPreferences` equivalent, kept for guest/local data and migration.
  - `local_to_cloud_migration.dart` — runs a one-time SharedPreferences → Firestore copy per (uid, key).
  - `auth_service.dart`, `theme_*`, `chat_font_size*` — auth wrapper and the persisted theme / chat font size controllers.
  - Public read-only collections (never written from the client): `sample_lessons` (`SampleLessonRepository`) and `curriculum_paths` (`CurriculumPathRepository`, units in a `units` subcollection with `nodes` embedded as an array).
- `lib/widgets/` — `flip_card`, `flashcard_tile`, `labeled_info_card`, `quiz_attempt_tile`, `quiz_format_chip`, `manual_badge`, `subject_chip`, `subject_picker`, `image_source_picker`.
- `lib/config/dev_flags.dart` — `kDevUnlockAllNodes` (currently `true`): shows every Ders Yolu node as unlocked for content QA. **Flip to `false` before release** (TODO in the file).
- `lib/tool/seed_sample_lessons.dart` — legacy in-app seeder, superseded by the admin tools below.

### Ders Yolları data model

A path (`curriculum_paths/{subjectKey}`, with `title`, `examType`, `subject`, `hasContent`) has units; each unit has ordered nodes (konu). A node carries four content kinds, each split into small parts: 5×10 "Kart Seti", 5×10 "Test", 2×10 "Doğru/Yanlış", 2×10 "Boşluk Doldurma". A kind counts as complete only when all its parts are done; a node is complete when every kind it has content for is complete, and that unlocks the next node. Node ids are prefixed with the unit id (`unit6_node1`) because raw ids repeat across units. On first open a part is materialized into the user's own `CardSetRepository`/`QuizSetRepository` under a deterministic id (`path_{subjectKey}_{nodeId}_{kind}_{part}`) and re-synced to the current curriculum content on later opens, so the existing flip-card/quiz screens are reused unchanged.

### Content tooling (`tool/`, plain Dart, run with `dart run tool/<file>.dart`)

Pattern: generate with Gemini → review `tool/curriculum_path_output.json` → seed to Firestore.

- `generate_curriculum_path.dart`, `generate_unit{2..6}_content.dart` — Gemini content generators per unit (resume-aware: they skip nodes whose parts are already complete). Read `GEMINI_API_KEY` straight from `.env`.
- `seed_curriculum_path_admin.dart` / `seed_sample_lessons_admin.dart` — write the JSON outputs to Firestore using `tool/service-account.json` (gitignored; Firebase Console → Service Accounts → generate key).
- `migrate_curriculum_parts.dart`, `regenerate_fillblank.dart`, `fix_broken_cards.dart` — one-off repair/reshape tools (Turkish diacritic loss, part splitting).
- `spend_guard.dart` — shared Gemini spend meter (`tool/spend_ledger.json`, gitignored); every paid-API tool must go through it and take `--budget-usd`.
- `curriculum_manifest.json` — what content should exist (path → unit → node, with each node's scope text). `pipeline.dart status` compares it with `curriculum_path_output.json`; `pipeline.dart validate` runs offline quality checks (structure, broken/ASCII-folded Turkish, near-duplicates, MC answer-position/length bias) and edits nothing.
- `analyze_source_book.dart` — turns OCR text of a source book (`kaynaklar/ocr/`, local only, gitignored, **never commit book PDFs/text**) into an abstract topic/facts list and a question-pattern catalog in `kaynaklar/analiz/`. Refuses to send book text without `--paid-tier-confirmed` (free tier data may be used by Google for training). Never pass book text into content-generation prompts, only the abstract outputs.
- `yks_outline.txt` — the YKS müfredat (23 ders paths: TYT/AYT/YDT > ünite > konu). Fizik/Kimya/AYT Biyoloji/Tarih/Din/Felsefe unit names come from MEB's "ÖSYM 2026 TYT/AYT/YDT kazanım ve açıklamalar" document; the rest is hand-compiled — re-check against the current document each exam year. Parsed by `yks_outline_parser.dart`.
- `seed_yks_outline_admin.dart` — seeds the outline only (all konular "Yakında"). Skips dersler that have a `tool/content/<key>.json` file (use `--force` to override) because it would wipe their questions.
- `generate_lite_content.dart` — one Gemini request per konu → 5 kart + 1 test + 1 boşluk doldurma + 1 doğru/yanlış (5 each), written to `tool/content/<key>.json` (all konular of the ders listed). Round-robin across dersler, resume-aware, stops cleanly when the free daily quota ends. Matematik/Geometri/Fizik/Kimya get an independent second "solve it yourself" pass; items whose answer differs are dropped. Content is NOT grounded in a source text or fact-checked — review before presenting as study material.
- Daily generation: Windows scheduled task `OgrenmeAsistani-GunlukIcerik` (installed by `scripts/install_daily_task.ps1`, removed with `-Remove`) runs `scripts/daily_generate.ps1` every day at 11:15 (the free Gemini daily quota resets at midnight Pacific time = 10:00 TR in summer, 11:00 TR in winter) and, if the PC was off, as soon as it is on again. It only generates into `tool/content/` (log: `tool/logs/`, gitignored); seeding and pushing stay manual after reviewing the new content.
- `seed_content_admin.dart` — seeds every `tool/content/*.json` (path doc incl. `contentNodeCount` + unit docs). `firestore_admin.dart` holds the shared service-account client/REST helpers.
- `generate_unit_content.dart <unitId>` — generic replacement for the per-unit generators; reads the unit's konular + scope text from `curriculum_manifest.json` (TYT Biyoloji only).
- `repair_diacritics.dart` — restores dropped Turkish letters in `curriculum_path_output.json` (accepts a fix only if folding it back to ASCII gives the original text).
- Content status: TYT Biyoloji Ünite 1–6 have full content and are seeded; Ünite 7–9 outline-only (scope texts for generation are in the manifest). Every other ders has the outline seeded; light content is generated/seeded progressively (see `tool/content/`).

### Environment

- Gemini API key lives in `.env` as `GEMINI_API_KEY` (gitignored). Loaded via `flutter_dotenv` in `main()`; `.env` is also declared as a Flutter asset in `pubspec.yaml` so it can be read on every platform.
- Firebase config: `lib/firebase_options.dart`, `firebase.json`, `android/app/google-services.json`.
- `tool/service-account.json` is a secret (gitignored) — never commit or print it.
- Branding assets in `assets/branding/` (logo generated by `scripts/generate_logo.py`); native splash configured via `flutter_native_splash` in `pubspec.yaml`.

### Known environment issue

`flutter doctor` may report Visual Studio missing the "Desktop development with C++" workload — this blocks `flutter run -d windows` / `flutter build windows` specifically. Android and web are unaffected.

- Dart SDK constraint: `^3.12.2` (see `pubspec.yaml`)
- Platforms scaffolded: android, ios, linux, macos, windows, web (Android is the primary target)
- Lints: `package:flutter_lints/flutter.yaml` via `analysis_options.yaml` (no custom rule overrides)
- Tests: `test/curriculum_progress_test.dart` (pure-Dart unit tests for the Ders Yolu progress/model logic). Widget tests that boot the whole app need Firebase mocks; the old `widget_test.dart` was removed because it failed without them.

## Commands

```
flutter pub get                 # install dependencies
flutter run                     # run the app (pick a connected device/emulator)
flutter analyze                 # static analysis / lint (should be clean)
flutter test                    # run all tests
flutter build apk               # build for a specific platform

dart run tool/generate_unit6_content.dart   # example: generate Ders Yolu content with Gemini
dart run tool/seed_curriculum_path_admin.dart   # push tool/curriculum_path_output.json to Firestore
```

There is no CI config in this repo.
