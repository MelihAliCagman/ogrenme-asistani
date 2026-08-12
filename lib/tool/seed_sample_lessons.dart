// Admin tool: writes tool/sample_lessons_output.json into the public
// `sample_lessons` Firestore collection. Already run once (content is
// live); keep this around to re-seed after regenerating/editing the
// content in the future.
//
// To run again:
//   1. Copy tool/sample_lessons_output.json to assets/seed/sample_lessons.json
//      and add that path under `flutter: assets:` in pubspec.yaml (both are
//      gitignored/removed after use — see git history for the exact diff).
//   2. In Firebase Console → Firestore → Rules, temporarily change the
//      sample_lessons write rule to `allow write: if request.auth != null;`
//      and publish.
//   3. flutter run -t lib/tool/seed_sample_lessons.dart -d <device-id>
//   4. Revert the write rule to `allow write: if false;` and publish again.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ogrenme_asistani/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _SeedApp());
}

class _SeedApp extends StatefulWidget {
  const _SeedApp();

  @override
  State<_SeedApp> createState() => _SeedAppState();
}

class _SeedAppState extends State<_SeedApp> {
  String _status = 'Başlatılıyor...';

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    try {
      setState(() => _status = 'Giriş yapılıyor...');
      debugPrint('[SEED] Giriş yapılıyor...');
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      debugPrint('[SEED] uid=${FirebaseAuth.instance.currentUser?.uid}');

      setState(() => _status = 'JSON okunuyor...');
      final raw = await rootBundle.loadString(
        'assets/seed/sample_lessons.json',
      );
      final lessons = jsonDecode(raw) as List;
      debugPrint('[SEED] ${lessons.length} ders okundu.');

      final collection = FirebaseFirestore.instance.collection(
        'sample_lessons',
      );

      for (var i = 0; i < lessons.length; i++) {
        final lesson = lessons[i] as Map<String, dynamic>;
        setState(() => _status = 'Yazılıyor: ${lesson['title']}...');
        debugPrint('[SEED] Yazılıyor: ${lesson['title']}');
        await collection.doc('lesson-${i + 1}').set(lesson);
        debugPrint('[SEED] Yazıldı: ${lesson['title']}');
      }

      setState(() => _status = '✅ Tamamlandı! ${lessons.length} ders yazıldı.');
      debugPrint('[SEED] TAMAMLANDI: ${lessons.length} ders yazıldı.');
    } catch (e) {
      setState(() => _status = '❌ Hata: $e');
      debugPrint('[SEED] HATA: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_status, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
