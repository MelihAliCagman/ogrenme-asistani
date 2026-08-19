// Permanent admin seeding tool: writes tool/curriculum_path_output.json
// into the public `curriculum_paths` Firestore collection using a
// Firebase service account (Admin-equivalent access), so it works
// regardless of what the Firestore security rules say — same pattern as
// tool/seed_sample_lessons_admin.dart.
//
// Writes:
//   curriculum_paths/{subjectKey}                      -> {title}
//   curriculum_paths/{subjectKey}/units/{unitId}        -> {order, title, nodes}
//
// `nodes` is an embedded array field on the unit document (not a further
// subcollection level) — keeps a full path read down to "1 doc + N unit
// docs" instead of fanning out into a 3rd collection level.
//
// One-time setup (skip if tool/service-account.json already exists from
// the sample_lessons seeding):
//   1. Firebase Console -> Project Settings -> Service Accounts ->
//      "Generate new private key". Save as tool/service-account.json
//      (gitignored — never commit it).
//   2. dart pub get
//
// Usage:
//   dart run tool/seed_curriculum_path_admin.dart
//
// Also remember to add the public-read rule for `curriculum_paths` in
// Firebase Console -> Firestore -> Rules (same shape as `sample_lessons`):
//   match /curriculum_paths/{document=**} {
//     allow read: if true;
//     allow write: if false;
//   }
//
// Pure Dart (no Flutter engine needed) — safe to run headlessly.

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

const _keyPath = 'tool/service-account.json';
const _contentPath = 'tool/curriculum_path_output.json';
const _collection = 'curriculum_paths';

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
    stderr.writeln(
      'İçerik dosyası bulunamadı: $_contentPath\n'
      'Önce: dart run tool/generate_curriculum_path.dart',
    );
    exit(1);
  }

  final credentialsJson = keyFile.readAsStringSync();
  final projectId = (jsonDecode(credentialsJson) as Map<String, dynamic>)['project_id'] as String;
  final credentials = ServiceAccountCredentials.fromJson(credentialsJson);

  final client = await clientViaServiceAccount(credentials, [
    'https://www.googleapis.com/auth/datastore',
  ]);

  try {
    final content = jsonDecode(contentFile.readAsStringSync()) as Map<String, dynamic>;
    final subjectKey = content['subjectKey'] as String;
    final units = content['units'] as List;

    stderr.writeln('"$subjectKey" ders yolu $projectId projesine yazılıyor...');

    final pathUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$_collection/$subjectKey',
    );
    final pathBody = jsonEncode({
      'fields': _toFirestoreFields({'title': content['title']}),
    });
    final pathResponse = await client.patch(
      pathUri,
      headers: {'Content-Type': 'application/json'},
      body: pathBody,
    );
    if (pathResponse.statusCode != 200) {
      stderr.writeln(
        '❌ $subjectKey (ana doküman): HTTP ${pathResponse.statusCode} ${pathResponse.body}',
      );
      exit(1);
    }
    stderr.writeln('✅ Yazıldı: $subjectKey (ana doküman)');

    for (final rawUnit in units) {
      final unit = rawUnit as Map<String, dynamic>;
      final unitId = unit['id'] as String;
      final unitUri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$_collection/$subjectKey/units/$unitId',
      );
      final unitBody = jsonEncode({
        'fields': _toFirestoreFields({
          'order': unit['order'],
          'title': unit['title'],
          'nodes': unit['nodes'],
        }),
      });
      final unitResponse = await client.patch(
        unitUri,
        headers: {'Content-Type': 'application/json'},
        body: unitBody,
      );
      if (unitResponse.statusCode != 200) {
        stderr.writeln(
          '❌ $unitId (${unit['title']}): HTTP ${unitResponse.statusCode} ${unitResponse.body}',
        );
        continue;
      }
      final nodeCount = (unit['nodes'] as List).length;
      stderr.writeln('✅ Yazıldı: $unitId (${unit['title']}) - $nodeCount node');
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
