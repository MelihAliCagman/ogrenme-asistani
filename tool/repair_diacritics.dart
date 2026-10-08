// Repair tool: restores Turkish characters in generated content that Gemini
// returned ASCII-folded ("hucre", "gore", "olusur", "zari"...), editing
// tool/curriculum_path_output.json in place.
//
// Detection is data-driven: a word with no Turkish letter is suspicious when
// the same content contains a Turkish-lettered variant of it at least twice
// as often (so "hucre" is flagged because "hücre" is everywhere, while a
// genuine word like "su" is not, because "şu" is rarer).
//
// Safe by construction: the model is only asked to put the Turkish letters
// back, and a string is accepted only if folding it back to ASCII gives
// exactly the original AND it did not lose any Turkish letter — so wording,
// order and meaning cannot change. Strings that fail stay untouched and are
// listed for manual review.
//
// Sends only our own curriculum text (no source-book content). Works on the
// free tier; no spend meter needed.
//
// Run:
//   dart run tool/repair_diacritics.dart --dry-run   # list what would change
//   dart run tool/repair_diacritics.dart             # repair (writes the JSON)

import 'dart:convert';
import 'dart:io';

const model = 'gemini-flash-lite-latest';
const defaultPath = 'tool/curriculum_path_output.json';
const batchSize = 20;

const _turkish = 'çğıöşüÇĞİÖŞÜâîûÂÎÛ';
const _foldMap = {
  'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
  'Ç': 'C', 'Ğ': 'G', 'İ': 'I', 'Ö': 'O', 'Ş': 'S', 'Ü': 'U',
  'â': 'a', 'î': 'i', 'û': 'u', 'Â': 'A', 'Î': 'I', 'Û': 'U',
};

/// A reference to one string inside the JSON tree: `container[key]`.
class _Ref {
  _Ref(this.container, this.key, this.where);
  final Object container; // Map<String, dynamic> or List
  final Object key; // String or int
  final String where;

  String get value => (container is Map
      ? (container as Map)[key]
      : (container as List)[key as int]) as String;

  set value(String v) {
    if (container is Map) {
      (container as Map)[key] = v;
    } else {
      (container as List)[key as int] = v;
    }
  }
}

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  // Files to repair: every non-flag argument (all of them are scanned as ONE
  // corpus, so a folded word is recognised by the correct spelling used in
  // any other file), or the curriculum output by default.
  final paths = args.where((a) => !a.startsWith('--')).toList();
  if (paths.isEmpty) paths.add(defaultPath);

  final roots = <String, Map<String, dynamic>>{
    for (final path in paths)
      path: jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  };

  final refs = <_Ref>[
    for (final e in roots.entries) ..._collectRefs(e.value, e.key),
  ];
  final suspicious = _findSuspicious(refs);

  final byNode = <String, int>{};
  for (final r in suspicious) {
    byNode[r.where] = (byNode[r.where] ?? 0) + 1;
  }
  stdout.writeln(
    '${paths.length} dosya, ${refs.length} metinden ${suspicious.length} '
    'tanesi şüpheli (${byNode.length} düğüm).',
  );
  if (dryRun) {
    byNode.forEach((k, v) => stdout.writeln('  $k: $v metin'));
    if (suspicious.length <= 40) {
      for (final r in suspicious) {
        stdout.writeln('    [${r.where}] ${r.value}');
      }
    }
    return;
  }
  if (suspicious.isEmpty) return;

  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }
  final client = HttpClient();
  var fixed = 0, unchanged = 0;
  final unresolved = <_Ref>[];

  void saveAll() {
    for (final e in roots.entries) {
      File(e.key).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(e.value),
      );
    }
  }

  for (var start = 0; start < suspicious.length; start += batchSize) {
    var pending = suspicious.skip(start).take(batchSize).toList();
    stdout.writeln(
      'Grup ${start ~/ batchSize + 1}/${(suspicious.length / batchSize).ceil()} '
      '(${pending.length} metin)...',
    );
    for (var attempt = 1; attempt <= 3 && pending.isNotEmpty; attempt++) {
      try {
        final result = await _restore(client, apiKey, pending.map((r) => r.value).toList());
        final stillPending = <_Ref>[];
        for (var i = 0; i < pending.length; i++) {
          final original = pending[i].value;
          final candidate = i < result.length ? result[i] : '';
          if (!_isFaithful(original, candidate)) {
            stillPending.add(pending[i]);
          } else if (candidate == original) {
            unchanged++;
          } else {
            pending[i].value = candidate;
            fixed++;
          }
        }
        pending = stillPending;
      } catch (e) {
        stderr.writeln('  hata: $e (deneme $attempt/3)');
        await Future.delayed(Duration(seconds: 10 * attempt));
      }
      await Future.delayed(const Duration(seconds: 5));
    }
    unresolved.addAll(pending);
    saveAll();
  }
  client.close();

  stdout.writeln(
    'Bitti: $fixed metin onarıldı, $unchanged zaten doğruydu, '
    '${unresolved.length} metin onarılamadı.',
  );
  for (final r in unresolved) {
    stdout.writeln('  elle bakılmalı [${r.where}]: ${r.value}');
  }
}

List<_Ref> _collectRefs(Map<String, dynamic> root, String file) {
  final refs = <_Ref>[];
  for (final unit in (root['units'] as List).cast<Map<String, dynamic>>()) {
    for (final node
        in ((unit['nodes'] as List?) ?? []).cast<Map<String, dynamic>>()) {
      final stem = file.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
      final where = '$stem ${unit['id']}/${node['id']}';
      for (final part in (node['flashcards'] as List? ?? []).cast<Map<String, dynamic>>()) {
        for (final card in (part['cards'] as List).cast<Map<String, dynamic>>()) {
          refs.add(_Ref(card, 'question', where));
          refs.add(_Ref(card, 'answer', where));
        }
      }
      for (final kind in ['multipleChoice', 'fillBlank', 'trueFalse']) {
        for (final part in (node[kind] as List? ?? []).cast<Map<String, dynamic>>()) {
          for (final q in (part['questions'] as List).cast<Map<String, dynamic>>()) {
            refs.add(_Ref(q, 'question', where));
            if (q['explanation'] is String) refs.add(_Ref(q, 'explanation', where));
            // True/false options are the fixed "Doğru"/"Yanlış" labels.
            if (kind != 'trueFalse') {
              final options = q['options'] as List;
              for (var i = 0; i < options.length; i++) {
                if (options[i] is String) refs.add(_Ref(options, i, where));
              }
            }
          }
        }
      }
    }
  }
  return refs;
}

final _wordRe = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşüâîûÂÎÛ]+');

bool _hasTurkish(String s) => s.split('').any(_turkish.contains);

List<_Ref> _findSuspicious(List<_Ref> refs) {
  final counts = <String, int>{};
  for (final r in refs) {
    for (final m in _wordRe.allMatches(r.value)) {
      final w = m.group(0)!.toLowerCase();
      counts[w] = (counts[w] ?? 0) + 1;
    }
  }
  // folded form -> highest count among its Turkish-lettered variants.
  final bestVariant = <String, int>{};
  counts.forEach((w, c) {
    if (!_hasTurkish(w)) return;
    final folded = _fold(w);
    if (c > (bestVariant[folded] ?? 0)) bestVariant[folded] = c;
  });

  bool suspicious(String s) {
    for (final m in _wordRe.allMatches(s)) {
      final w = m.group(0)!.toLowerCase();
      if (w.length < 4 || _hasTurkish(w)) continue;
      final variant = bestVariant[w];
      if (variant != null && variant >= 2 * (counts[w] ?? 0)) return true;
    }
    return false;
  }

  return refs.where((r) => suspicious(r.value)).toList();
}

String _fold(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_foldMap[ch] ?? ch);
  }
  return b.toString();
}

int _turkishCount(String s) => s.split('').where(_turkish.contains).length;

bool _isFaithful(String original, String candidate) {
  if (candidate.isEmpty || candidate.contains('�')) return false;
  if (_fold(candidate) != _fold(original)) return false;
  return _turkishCount(candidate) >= _turkishCount(original);
}

Future<List<String>> _restore(
  HttpClient client,
  String apiKey,
  List<String> texts,
) async {
  final prompt =
      'Aşağıdaki biyoloji metinlerinde bazı Türkçe karakterler ASCII\'ye '
      'çevrilmiş (örn. "hucre", "gore", "olusur", "zari", "alem"). Her metni '
      'AYNI SIRAYLA, SADECE eksik Türkçe karakterleri (ç, ğ, ı, ö, ş, ü, Ç, '
      'Ğ, İ, Ö, Ş, Ü) doğru yerlere koyarak yeniden yaz; biyoloji terimi '
      'olan "âlem" gibi sözcüklerde şapkayı da koy. Kelimeleri, anlamı, '
      'noktalama ve sırayı DEĞİŞTİRME, hiçbir şey ekleme veya çıkarma, '
      'yazım hatası düzeltme. Zaten doğru olan metni olduğu gibi döndür. '
      'Tam olarak ${texts.length} metin döndür.\n\n${jsonEncode(texts)}';
  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': prompt},
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseSchema': {
        'type': 'ARRAY',
        'minItems': texts.length,
        'maxItems': texts.length,
        'items': {'type': 'STRING'},
      },
    },
  });
  final request = await client.postUrl(
    Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    ),
  );
  request.headers.set('Content-Type', 'application/json');
  request.headers.set('x-goog-api-key', apiKey);
  request.add(utf8.encode(body));
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }
  final data = jsonDecode(text) as Map<String, dynamic>;
  final parts = data['candidates'][0]['content']['parts'] as List;
  final out = parts.map((p) => p['text']).whereType<String>().join();
  return (jsonDecode(out) as List).cast<String>();
}

String? _readEnvKey(String key) {
  final file = File('.env');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('$key=')) {
      return trimmed.substring(key.length + 1).trim();
    }
  }
  return null;
}
