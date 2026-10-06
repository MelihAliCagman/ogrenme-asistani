// Seeds the YKS curriculum OUTLINE (ders > ünite > konu, no questions yet)
// from tool/yks_outline.txt into the public `curriculum_paths` collection,
// so every TYT / AYT / YDT ders shows up in the app's Müfredat tab with its
// units and topics marked "Yakında" until real content is authored.
//
// Writes, per ders (same shape the app already reads):
//   curriculum_paths/{key}                -> {title, examType, subject,
//                                             hasContent: false,
//                                             unitCount, nodeCount}
//   curriculum_paths/{key}/units/{unitN}  -> {order, title, nodes: [...]}
//
// Nodes carry no flashcards/quizzes, so the app treats them as "coming
// soon". Paths that already have real content (tyt_biyoloji) are not in the
// outline file and are never touched.
//
// Usage:
//   dart run tool/seed_yks_outline_admin.dart --dry-run   # only print counts
//   dart run tool/seed_yks_outline_admin.dart             # write to Firestore
//
// Needs tool/service-account.json (gitignored), like the other admin seeders.

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

const _keyPath = 'tool/service-account.json';
const _outlinePath = 'tool/yks_outline.txt';
const _collection = 'curriculum_paths';

class _Path {
  _Path(this.key, this.subject);
  final String key;
  final String subject;
  final List<({String title, List<String> topics})> units = [];

  String get stage => key.split('_').first.toUpperCase();
  String get title => '$stage $subject';
  int get nodeCount => units.fold(0, (sum, u) => sum + u.topics.length);
}

List<_Path> _parseOutline(String text) {
  final paths = <_Path>[];
  String? pendingUnit;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') && !line.startsWith('# ')) {
      continue;
    }
    if (line.startsWith('@')) {
      final parts = line.substring(1).split('|');
      paths.add(_Path(parts[0].trim(), parts[1].trim()));
      pendingUnit = null;
    } else if (line.startsWith('# ')) {
      // Header comments at the top of the file also start with "# " but
      // appear before the first "@" path, so they are skipped here.
      if (paths.isEmpty) continue;
      pendingUnit = line.substring(2).trim();
    } else if (pendingUnit != null && paths.isNotEmpty) {
      final topics = line
          .split('|')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      paths.last.units.add((title: pendingUnit, topics: topics));
      pendingUnit = null;
    }
  }
  return paths;
}

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final paths = _parseOutline(File(_outlinePath).readAsStringSync());

  var totalUnits = 0, totalNodes = 0;
  for (final p in paths) {
    totalUnits += p.units.length;
    totalNodes += p.nodeCount;
    stdout.writeln(
      '${p.key.padRight(18)} ${p.title.padRight(22)} '
      '${p.units.length.toString().padLeft(2)} ünite, '
      '${p.nodeCount.toString().padLeft(3)} konu',
    );
  }
  stdout.writeln(
    '\n${paths.length} ders yolu, $totalUnits ünite, $totalNodes konu.',
  );
  if (dryRun) {
    stdout.writeln('(--dry-run: Firestore\'a yazılmadı.)');
    return;
  }

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

  try {
    final base =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$_collection';
    for (final p in paths) {
      await _patch(client, '$base/${p.key}', {
        'title': p.title,
        'examType': 'YKS',
        'subject': p.subject,
        'hasContent': false,
        'unitCount': p.units.length,
        'nodeCount': p.nodeCount,
      });
      for (var u = 0; u < p.units.length; u++) {
        final unit = p.units[u];
        await _patch(client, '$base/${p.key}/units/unit${u + 1}', {
          'order': u + 1,
          'title': unit.title,
          'nodes': [
            for (var n = 0; n < unit.topics.length; n++)
              {
                'id': 'node${n + 1}',
                'order': n + 1,
                'title': unit.topics[n],
                'estimatedMinutes': 15,
              },
          ],
        });
      }
      stdout.writeln('✅ ${p.key}: ${p.units.length} ünite, ${p.nodeCount} konu');
    }
    stdout.writeln('Tamamlandı.');
  } finally {
    client.close();
  }
}

Future<void> _patch(
  AuthClient client,
  String url,
  Map<String, dynamic> fields,
) async {
  final response = await client.patch(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fields': _toFields(fields)}),
  );
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode} $url\n${response.body}');
  }
}

Map<String, dynamic> _toFields(Map<String, dynamic> map) => {
  for (final e in map.entries) e.key: _toValue(e.value),
};

Map<String, dynamic> _toValue(dynamic v) {
  if (v == null) return {'nullValue': null};
  if (v is String) return {'stringValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': v.toString()};
  if (v is List) {
    return {
      'arrayValue': {'values': v.map(_toValue).toList()},
    };
  }
  if (v is Map) {
    return {
      'mapValue': {'fields': _toFields(Map<String, dynamic>.from(v))},
    };
  }
  throw ArgumentError('Desteklenmeyen tür: ${v.runtimeType}');
}
