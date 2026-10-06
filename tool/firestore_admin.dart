// Shared Firestore admin helpers for the seeding tools: a service-account
// authenticated client (Admin-equivalent access, so it ignores the security
// rules) plus a tiny JSON -> Firestore REST value encoder.
//
// Needs tool/service-account.json (gitignored — never commit it).

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

const _keyPath = 'tool/service-account.json';

class AdminSession {
  AdminSession(this.client, this.projectId);

  final AuthClient client;
  final String projectId;

  String get documentsUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  void close() => client.close();
}

Future<AdminSession> openAdminSession() async {
  final keyFile = File(_keyPath);
  if (!keyFile.existsSync()) {
    stderr.writeln('Servis hesabı anahtarı bulunamadı: $_keyPath');
    exit(1);
  }
  final credentialsJson = keyFile.readAsStringSync();
  final projectId =
      (jsonDecode(credentialsJson) as Map<String, dynamic>)['project_id']
          as String;
  final client = await clientViaServiceAccount(
    ServiceAccountCredentials.fromJson(credentialsJson),
    ['https://www.googleapis.com/auth/datastore'],
  );
  return AdminSession(client, projectId);
}

/// Creates or replaces the fields of one document (PATCH without an update
/// mask replaces the whole document body, other subcollections stay).
Future<void> patchDocument(
  AdminSession session,
  String path,
  Map<String, dynamic> fields,
) async {
  final response = await session.client.patch(
    Uri.parse('${session.documentsUrl}/$path'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': toFirestoreFields(fields)}),
  );
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode} $path\n${response.body}');
  }
}

Map<String, dynamic> toFirestoreFields(Map<String, dynamic> map) => {
  for (final e in map.entries) e.key: toFirestoreValue(e.value),
};

Map<String, dynamic> toFirestoreValue(dynamic v) {
  if (v == null) return {'nullValue': null};
  if (v is String) return {'stringValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': v.toString()};
  if (v is double) return {'doubleValue': v};
  if (v is List) {
    return {
      'arrayValue': {'values': v.map(toFirestoreValue).toList()},
    };
  }
  if (v is Map) {
    return {
      'mapValue': {'fields': toFirestoreFields(Map<String, dynamic>.from(v))},
    };
  }
  throw ArgumentError('Desteklenmeyen Firestore değer türü: ${v.runtimeType}');
}
