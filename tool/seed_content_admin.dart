// Seeds the generated content files (tool/content/<anahtar>.json, written by
// tool/generate_lite_content.dart) into the public `curriculum_paths`
// collection: the path document plus one unit document per ünite, with the
// konular (and their kartlar/testler) embedded as the app expects.
//
// Every file lists ALL konular of its ders (empty ones just have no
// questions), so seeding is idempotent and the müfredat stays complete.
//
//   curriculum_paths/{key}                -> {title, examType, subject,
//                                             hasContent, unitCount, nodeCount,
//                                             contentNodeCount}
//   curriculum_paths/{key}/units/{unitN}  -> {order, title, nodes: [...]}
//
// Usage:
//   dart run tool/seed_content_admin.dart --dry-run
//   dart run tool/seed_content_admin.dart                 # all files
//   dart run tool/seed_content_admin.dart --only tyt_fizik
//
// Needs tool/service-account.json (gitignored).

import 'dart:convert';
import 'dart:io';

import 'firestore_admin.dart';

const _contentDir = 'tool/content';
const _collection = 'curriculum_paths';

bool _nodeHasContent(Map<String, dynamic> n) =>
    ((n['flashcards'] as List?) ?? []).isNotEmpty ||
    ((n['multipleChoice'] as List?) ?? []).isNotEmpty ||
    ((n['fillBlank'] as List?) ?? []).isNotEmpty ||
    ((n['trueFalse'] as List?) ?? []).isNotEmpty;

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final onlyIndex = args.indexOf('--only');
  final only = onlyIndex == -1 ? null : args[onlyIndex + 1];

  final files = Directory(_contentDir).existsSync()
      ? (Directory(_contentDir).listSync().whereType<File>().where(
          (f) => f.path.endsWith('.json'),
        ).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  final selected = [
    for (final f in files)
      if (only == null || f.uri.pathSegments.last == '$only.json') f,
  ];
  if (selected.isEmpty) {
    stderr.writeln('$_contentDir içinde içerik dosyası yok.');
    exit(1);
  }

  final roots = <String, Map<String, dynamic>>{};
  var totalWithContent = 0, totalNodes = 0;
  for (final f in selected) {
    final root = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    roots[root['subjectKey'] as String] = root;
    final units = (root['units'] as List).cast<Map<String, dynamic>>();
    final nodes = [
      for (final u in units) ...(u['nodes'] as List).cast<Map<String, dynamic>>(),
    ];
    final filled = nodes.where(_nodeHasContent).length;
    totalWithContent += filled;
    totalNodes += nodes.length;
    stdout.writeln(
      '${(root['subjectKey'] as String).padRight(16)} '
      '${(root['title'] as String).padRight(20)} '
      '$filled/${nodes.length} konuda içerik',
    );
  }
  stdout.writeln('\n${roots.length} ders; $totalWithContent/$totalNodes konuda içerik.');
  if (dryRun) {
    stdout.writeln('(--dry-run: Firestore\'a yazılmadı.)');
    return;
  }

  final session = await openAdminSession();
  try {
    for (final root in roots.values) {
      final key = root['subjectKey'] as String;
      final units = (root['units'] as List).cast<Map<String, dynamic>>();
      final nodeCount = units.fold<int>(0, (s, u) => s + (u['nodes'] as List).length);
      final contentNodeCount = units.fold<int>(
        0,
        (s, u) =>
            s + (u['nodes'] as List).cast<Map<String, dynamic>>().where(_nodeHasContent).length,
      );
      final hasContent = contentNodeCount > 0;
      await patchDocument(session, '$_collection/$key', {
        'title': root['title'],
        'examType': root['examType'] ?? 'YKS',
        'subject': root['subject'],
        'hasContent': hasContent,
        'unitCount': units.length,
        'nodeCount': nodeCount,
        'contentNodeCount': contentNodeCount,
      });
      for (final unit in units) {
        await patchDocument(session, '$_collection/$key/units/${unit['id']}', {
          'order': unit['order'],
          'title': unit['title'],
          'nodes': unit['nodes'],
        });
      }
      stdout.writeln('✅ $key: ${units.length} ünite, $nodeCount konu '
          '(${hasContent ? 'içerikli' : 'sadece müfredat'})');
    }
    stdout.writeln('Tamamlandı.');
  } finally {
    session.close();
  }
}
