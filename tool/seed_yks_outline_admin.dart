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
// WARNING: this REPLACES the unit documents, including any questions that
// were seeded for them. Dersler that already have content must be re-seeded
// with tool/seed_content_admin.dart instead; pass --only to limit the paths.
//
// Usage:
//   dart run tool/seed_yks_outline_admin.dart --dry-run          # only counts
//   dart run tool/seed_yks_outline_admin.dart                    # all dersler
//   dart run tool/seed_yks_outline_admin.dart --only tyt_turkce  # one ders
//
// Needs tool/service-account.json (gitignored), like the other admin seeders.

import 'dart:io';

import 'firestore_admin.dart';
import 'yks_outline_parser.dart';

const _outlinePath = 'tool/yks_outline.txt';
const _collection = 'curriculum_paths';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final onlyIndex = args.indexOf('--only');
  final only = onlyIndex == -1 ? null : args[onlyIndex + 1];
  final force = args.contains('--force');
  final paths = parseOutline(File(_outlinePath).readAsStringSync())
      .where((p) => only == null || p.key == only)
      .where((p) {
        // A ders with generated content must be seeded with
        // tool/seed_content_admin.dart; writing only its outline here would
        // wipe the questions already in Firestore.
        final hasContentFile = File('tool/content/${p.key}.json').existsSync();
        if (hasContentFile && !force) {
          stdout.writeln('↷ ${p.key}: içerik dosyası var, atlandı (--force ile zorla).');
        }
        return !hasContentFile || force;
      })
      .toList();

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

  final session = await openAdminSession();
  try {
    for (final p in paths) {
      await patchDocument(session, '$_collection/${p.key}', {
        'title': p.title,
        'examType': 'YKS',
        'subject': p.subject,
        'hasContent': false,
        'unitCount': p.units.length,
        'nodeCount': p.nodeCount,
      });
      for (var u = 0; u < p.units.length; u++) {
        final unit = p.units[u];
        await patchDocument(session, '$_collection/${p.key}/units/unit${u + 1}', {
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
    session.close();
  }
}
