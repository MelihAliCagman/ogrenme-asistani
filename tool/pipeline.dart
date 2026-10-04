// Content pipeline helper (offline, never calls the Gemini API).
//
//   dart run tool/pipeline.dart status     # manifest vs generated content
//   dart run tool/pipeline.dart validate   # automatic quality checks
//
// `status` compares tool/curriculum_manifest.json (what should exist) with
// tool/curriculum_path_output.json (what has been generated) and lists the
// nodes still missing parts.
//
// `validate` runs cheap, deterministic checks over every generated item:
// structure, broken/ASCII-folded Turkish, near-duplicates inside a node,
// and answer-position / answer-length bias in multiple choice. It reports
// problems; it does not modify any file. A model-based fact check (second
// model reviewing each item) is a later, paid stage.

import 'dart:convert';
import 'dart:io';

const manifestPath = 'tool/curriculum_manifest.json';
const outputPath = 'tool/curriculum_path_output.json';

const partTargets = {
  'flashcards': 5,
  'multipleChoice': 5,
  'fillBlank': 2,
  'trueFalse': 2,
};

void main(List<String> args) {
  final command = args.isEmpty ? 'status' : args.first;
  switch (command) {
    case 'status':
      _status();
    case 'validate':
      _validate();
    default:
      stderr.writeln('Kullanım: dart run tool/pipeline.dart [status|validate]');
      exit(64);
  }
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

// ---------------------------------------------------------------------------
// status
// ---------------------------------------------------------------------------

void _status() {
  final manifest = _readJson(manifestPath);
  final output = _readJson(outputPath);
  final outUnits = {
    for (final u in (output['units'] as List).cast<Map<String, dynamic>>())
      u['id'] as String: u,
  };

  var done = 0, partial = 0, pending = 0;
  for (final path in (manifest['paths'] as List).cast<Map<String, dynamic>>()) {
    stdout.writeln('== ${path['title']} ==');
    for (final unit in (path['units'] as List).cast<Map<String, dynamic>>()) {
      final nodes = (unit['nodes'] as List).cast<Map<String, dynamic>>();
      if (nodes.isEmpty) {
        stdout.writeln('  ${unit['id']} ${unit['title']}: düğüm tanımı yok (planlanmadı)');
        pending++;
        continue;
      }
      final outNodes = {
        for (final n in ((outUnits[unit['id']]?['nodes'] as List?) ?? [])
            .cast<Map<String, dynamic>>())
          n['id'] as String: n,
      };
      for (final node in nodes) {
        final out = outNodes[node['id']];
        final missing = <String>[];
        for (final e in partTargets.entries) {
          final have = ((out?[e.key] as List?) ?? []).length;
          if (have < e.value) missing.add('${e.key} $have/${e.value}');
        }
        if (missing.isEmpty) {
          done++;
        } else if (out == null) {
          pending++;
          stdout.writeln('  ${unit['id']}/${node['id']} ${node['title']}: üretilmedi');
        } else {
          partial++;
          stdout.writeln('  ${unit['id']}/${node['id']} ${node['title']}: eksik ${missing.join(', ')}');
        }
      }
    }
  }
  stdout.writeln('\nTamam: $done düğüm, eksik: $partial, üretilmemiş/planlanmamış: $pending');
}

// ---------------------------------------------------------------------------
// validate
// ---------------------------------------------------------------------------

class _Item {
  _Item(this.kind, this.part, this.index, this.question, this.answer);
  final String kind;
  final int part;
  final int index;
  final String question;
  final String answer;
  String get label => '$kind parça ${part + 1} #${index + 1}';
}

void _validate() {
  final output = _readJson(outputPath);
  var problems = 0;
  var checkedItems = 0;
  var badNodes = 0;

  for (final unit in (output['units'] as List).cast<Map<String, dynamic>>()) {
    for (final node in ((unit['nodes'] as List?) ?? []).cast<Map<String, dynamic>>()) {
      final where = '${unit['id']}/${node['id']} ${node['title']}';
      final nodeProblems = <String>[];
      final items = <_Item>[];

      void add(String m) => nodeProblems.add(m);

      // Flashcards.
      final cardParts = (node['flashcards'] as List? ?? []).cast<Map<String, dynamic>>();
      for (var p = 0; p < cardParts.length; p++) {
        final cards = (cardParts[p]['cards'] as List? ?? []).cast<Map<String, dynamic>>();
        if (cards.length != 10) add('flashcards parça ${p + 1}: ${cards.length}/10 kart');
        for (var i = 0; i < cards.length; i++) {
          final q = (cards[i]['question'] as String? ?? '').trim();
          final a = (cards[i]['answer'] as String? ?? '').trim();
          checkedItems++;
          if (q.isEmpty || a.isEmpty) add('flashcards parça ${p + 1} #${i + 1}: boş alan');
          _textChecks(q, 'soru', 'flashcards parça ${p + 1} #${i + 1}', add);
          _textChecks(a, 'cevap', 'flashcards parça ${p + 1} #${i + 1}', add);
          items.add(_Item('flashcards', p, i, q, a));
        }
      }

      // Quiz-shaped kinds.
      var mcCorrectLongest = 0, mcTotal = 0;
      final positions = <int, int>{};
      for (final kind in ['multipleChoice', 'fillBlank', 'trueFalse']) {
        final parts = (node[kind] as List? ?? []).cast<Map<String, dynamic>>();
        for (var p = 0; p < parts.length; p++) {
          final qs = (parts[p]['questions'] as List? ?? []).cast<Map<String, dynamic>>();
          if (qs.length != 10) add('$kind parça ${p + 1}: ${qs.length}/10 soru');
          for (var i = 0; i < qs.length; i++) {
            final q = qs[i];
            final label = '$kind parça ${p + 1} #${i + 1}';
            final text = (q['question'] as String? ?? '').trim();
            final options = ((q['options'] as List?) ?? []).cast<String>();
            final correct = (q['correctIndex'] as num?)?.toInt() ?? -1;
            final explanation = (q['explanation'] as String? ?? '').trim();
            checkedItems++;
            _textChecks(text, 'soru', label, add);
            if (explanation.isEmpty) add('$label: açıklama yok');
            if (correct < 0 || correct >= options.length) {
              add('$label: correctIndex ($correct) geçersiz');
              continue;
            }
            final answer = options[correct];
            for (final o in options) {
              _textChecks(o, 'şık', label, add);
            }
            switch (kind) {
              case 'multipleChoice':
                if (options.length != 4) add('$label: ${options.length} şık var');
                if (options.toSet().length != options.length) add('$label: tekrar eden şık');
                mcTotal++;
                positions[correct] = (positions[correct] ?? 0) + 1;
                final longest = options.reduce((a, b) => a.length >= b.length ? a : b);
                if (longest == answer && _uniqueLongest(options)) mcCorrectLongest++;
                if (text.contains(answer) && answer.length > 6) {
                  add('$label: doğru cevap soru metninde aynen geçiyor (ipucu olabilir)');
                }
              case 'fillBlank':
                if (!text.contains('____')) add('$label: boşluk işareti (____) yok');
                if (options.length != 1) add('$label: tek cevap beklenir');
              case 'trueFalse':
                if (options.length != 2) add('$label: Doğru/Yanlış için 2 seçenek beklenir');
            }
            items.add(_Item(kind, p, i, text, answer));
          }
        }
      }

      // Answer-position and length bias (multiple choice).
      if (mcTotal >= 20) {
        for (var pos = 0; pos < 4; pos++) {
          final share = (positions[pos] ?? 0) / mcTotal;
          if (share > 0.40) {
            add('çoktan seçmeli: doğru cevap %${(share * 100).round()} oranla '
                '${'ABCD'[pos]} şıkkında (dengesiz)');
          }
        }
        final longestShare = mcCorrectLongest / mcTotal;
        if (longestShare > 0.45) {
          add('çoktan seçmeli: doğru cevap %${(longestShare * 100).round()} '
              'oranla en uzun şık (ipucu olabilir)');
        }
      }

      // Near-duplicate questions inside the node, across all kinds.
      for (var a = 0; a < items.length; a++) {
        for (var b = a + 1; b < items.length; b++) {
          if (_similarity(items[a].question, items[b].question) >= 0.75) {
            add('yakın tekrar: ${items[a].label} ~ ${items[b].label}');
          }
        }
      }

      if (nodeProblems.isNotEmpty) {
        badNodes++;
        problems += nodeProblems.length;
        stdout.writeln('\n[$where] ${nodeProblems.length} sorun');
        for (final p in nodeProblems.take(15)) {
          stdout.writeln('  - $p');
        }
        if (nodeProblems.length > 15) {
          stdout.writeln('  ... ve ${nodeProblems.length - 15} sorun daha');
        }
      }
    }
  }
  stdout.writeln('\nKontrol edilen öğe: $checkedItems, sorunlu düğüm: $badNodes, toplam sorun: $problems');
}

/// Flags broken encoding and Turkish text that looks ASCII-folded.
void _textChecks(String text, String what, String label, void Function(String) add) {
  if (text.contains('�')) add('$label: bozuk karakter (�) — $what');
  // ASCII-folded Turkish is hard to detect generically; flag only a few
  // common stems, like the ones the earlier diacritic-loss incident hit.
  const foldedStems = ['ureme', 'hucre', 'bolunme', 'cekirdek'];
  final lower = text.toLowerCase();
  for (final s in foldedStems) {
    if (lower.contains(s)) {
      add('$label: ASCII\'ye çevrilmiş Türkçe olabilir ("$s") — $what');
      break;
    }
  }
}

bool _uniqueLongest(List<String> options) {
  final maxLen = options.map((o) => o.length).reduce((a, b) => a > b ? a : b);
  return options.where((o) => o.length == maxLen).length == 1;
}

/// Jaccard word-overlap, same notion of similarity the generators use.
double _similarity(String a, String b) {
  Set<String> words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .toSet();
  final wa = words(a), wb = words(b);
  if (wa.isEmpty || wb.isEmpty) return 0;
  return wa.intersection(wb).length / wa.union(wb).length;
}
