// Permanent admin seeding tool: writes tool/sample_lessons_output.json
// into the public `sample_lessons` Firestore collection using a Firebase
// service account (Admin-equivalent access), so it works regardless of
// what the Firestore security rules say — no more toggling
// `allow write` on and off in the console.
//
// One-time setup:
//   1. Firebase Console → Project Settings → Service Accounts →
//      "Generate new private key". Save the downloaded file as
//      tool/service-account.json (this exact path is gitignored — never
//      commit it).
//   2. dart pub get
//
// Usage:
//   dart run tool/seed_sample_lessons_admin.dart
//
// Pure Dart (no Flutter engine needed) — safe to run headlessly.

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

const _keyPath = 'tool/service-account.json';
const _contentPath = 'tool/sample_lessons_output.json';
const _collection = 'sample_lessons';

Future<void> main() async {
  final keyFile = File(_keyPath);
  if (!keyFile.existsSync()) {
    stderr.writeln(
      'Servis hesabı anahtarı bulunamadı: $_keyPath\n'
      'Firebase Console → Project Settings → Service Accounts → '
      '"Generate new private key" ile indirip bu yola kaydet.',
    );
    exit(1);
  }
  final contentFile = File(_contentPath);
  if (!contentFile.existsSync()) {
    stderr.writeln('İçerik dosyası bulunamadı: $_contentPath');
    exit(1);
  }

  final credentialsJson = keyFile.readAsStringSync();
  final projectId = (jsonDecode(credentialsJson) as Map<String, dynamic>)['project_id'] as String;
  final credentials = ServiceAccountCredentials.fromJson(credentialsJson);

  final client = await clientViaServiceAccount(credentials, [
    'https://www.googleapis.com/auth/datastore',
  ]);

  try {
    final lessons = jsonDecode(contentFile.readAsStringSync()) as List;
    stderr.writeln('${lessons.length} ders $projectId projesine yazılıyor...');

    for (var i = 0; i < lessons.length; i++) {
      final lesson = lessons[i] as Map<String, dynamic>;
      final docId = 'lesson-${i + 1}';
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$_collection/$docId',
      );
      final body = jsonEncode({'fields': _toFirestoreFields(lesson)});
      final response = await client.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode != 200) {
        stderr.writeln(
          '❌ ${lesson['title']}: HTTP ${response.statusCode} ${response.body}',
        );
        continue;
      }
      stderr.writeln('✅ Yazıldı: ${lesson['title']}');
    }
    stderr.writeln('Tamamlandı.');
  } finally {
    client.close();
  }
}

Map<String, dynamic> _toFirestoreFields(Map<String, dynamic> map) {
  return {for (final entry in map.entries) entry.key: _toFirestoreValue(entry.value)};
}

Map<String, dynamic> _toFirestoreValue(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is List) {
    return {
      'arrayValue': {
        'values': value.map(_toFirestoreValue).toList(),
      },
    };
  }
  if (value is Map) {
    return {
      'mapValue': {'fields': _toFirestoreFields(Map<String, dynamic>.from(value))},
    };
  }
  throw ArgumentError('Desteklenmeyen Firestore değer türü: ${value.runtimeType}');
}
