// Generates a light content set for EVERY konu of the YKS dersler so the app
// can be shown with many dersler filled in, not just Biyoloji.
//
// Per konu (one Gemini request, all four kinds together):
//   5 hafıza kartı, 1 test (5 çoktan seçmeli), 1 boşluk doldurma (5 soru),
//   1 doğru/yanlış (5 ifade).
//
// Reads the outline from tool/yks_outline.txt and keeps one file per ders in
// tool/content/<anahtar>.json (same shape the app/seeders use, ALL nodes of
// the ders listed, empty arrays for the konular not generated yet). Resume-
// aware: konular that already have content are skipped, so the tool can be
// run again whenever the daily free quota has reset.
//
// Dersler are processed round-robin (one konu per ders per round), so even
// when the daily quota ends early every ders has its first units filled.
// Biyoloji is skipped (it has the full, larger content set already).
//
// The content comes from the model's own knowledge of the MEB müfredatı —
// it is NOT grounded in a source text and is NOT fact-checked. Review it
// before showing it as study material (see tool/pipeline.dart validate and
// tool/repair_diacritics.dart for the automatic checks).
//
// Free tier assumed. If billing is enabled on the key, pass --budget-usd so
// every call goes through tool/spend_guard.dart.
//
// Usage:
//   dart run tool/generate_lite_content.dart --dry-run
//   dart run tool/generate_lite_content.dart [--limit 100] [--only tyt_fizik]
//                                            [--budget-usd 2]

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'spend_guard.dart';
import 'yks_outline_parser.dart';

const model = 'gemini-flash-lite-latest';
const outlinePath = 'tool/yks_outline.txt';
const contentDir = 'tool/content';

/// Dersler with their own full content set — never touched by this tool.
const skipKeys = {'tyt_biyoloji', 'ayt_biyoloji'};

/// Order in which dersler take turns; anything not listed goes last.
const priority = [
  'tyt_turkce',
  'tyt_matematik',
  'tyt_fizik',
  'tyt_kimya',
  'tyt_tarih',
  'tyt_cografya',
  'tyt_felsefe',
  'tyt_din',
  'tyt_geometri',
  'ayt_matematik',
  'ayt_fizik',
  'ayt_kimya',
  'ayt_edebiyat',
  'ayt_tarih',
  'ayt_cografya',
  'ayt_felsefe',
  'ayt_geometri',
  'ayt_mantik',
  'ayt_psikoloji',
  'ayt_sosyoloji',
  'ayt_din',
  'ydt_ingilizce',
];

const minSecondsBetweenRequests = 5.5; // stays under 12 requests/minute
const maxOutputTokens = 6144;

DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

Future<void> _throttle() async {
  final wait = minSecondsBetweenRequests -
      DateTime.now().difference(_lastRequest).inMilliseconds / 1000;
  if (wait > 0) {
    await Future.delayed(Duration(milliseconds: (wait * 1000).round()));
  }
  _lastRequest = DateTime.now();
}

/// Dersler whose answers come from calculation: their content gets a second,
/// independent "solve it yourself" pass and mismatching items are dropped.
const calculationSubjects = {'Matematik', 'Geometri', 'Fizik', 'Kimya'};

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final limit = int.tryParse(_argValue(args, '--limit') ?? '');
  final only = _argValue(args, '--only');
  final budgetUsd = double.tryParse(_argValue(args, '--budget-usd') ?? '');

  final outline = parseOutline(File(outlinePath).readAsStringSync())
      .where((p) => !skipKeys.contains(p.key))
      .where((p) => only == null || p.key == only)
      .toList()
    ..sort((a, b) => _rank(a.key).compareTo(_rank(b.key)));

  Directory(contentDir).createSync(recursive: true);
  final files = {for (final p in outline) p.key: _loadOrCreate(p)};

  // Round-robin queue of pending konular.
  final pending = {
    for (final p in outline) p.key: _pendingTopics(p, files[p.key]!),
  };
  final queue = <({OutlinePath path, _Ref ref})>[];
  var added = true;
  for (var round = 0; added; round++) {
    added = false;
    for (final p in outline) {
      final list = pending[p.key]!;
      if (round < list.length) {
        queue.add((path: p, ref: list[round]));
        added = true;
      }
    }
  }

  final total = queue.length;
  stdout.writeln(
    '${outline.length} ders, ${outline.fold<int>(0, (s, p) => s + p.nodeCount)} '
    'konu; içeriği olmayan: $total.',
  );
  if (dryRun) {
    stdout.writeln('Tahmini istek sayısı: $total (konu başına 1). Ücretsiz günlük '
        'kota ~500 istek.');
    return;
  }
  if (total == 0) return;

  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }
  final guard = budgetUsd == null
      ? null
      : SpendGuard(budgetUsd: budgetUsd, model: model);
  if (guard == null) {
    stdout.writeln('Ücretsiz katman varsayılıyor (--budget-usd verilmedi).');
  }

  final client = HttpClient();
  var done = 0, skipped = 0, consecutiveQuotaErrors = 0;

  try {
    for (final item in queue) {
      if (limit != null && done + skipped >= limit) break;
      final ref = item.ref;
      final label = '${item.path.title} › ${ref.unitTitle} › ${ref.topic}';

      Map<String, dynamic>? content;
      for (var attempt = 1; attempt <= 3 && content == null; attempt++) {
        try {
          final prompt = _prompt(item.path, ref);
          guard?.assertCanSpend(
            inputTokens: SpendGuard.estimateTokens(prompt),
            maxOutputTokens: maxOutputTokens,
          );
          await _throttle();
          final raw = await _call(client, apiKey, prompt, guard);
          consecutiveQuotaErrors = 0;
          final problems = <String>[];
          content = _validateAndBuild(raw, item.path.subject, ref, problems);
          if (content != null &&
              calculationSubjects.contains(item.path.subject)) {
            await _throttle();
            content = await _verify(client, apiKey, content, guard, problems);
          }
          if (content == null) {
            stderr.writeln('  ! $label: geçersiz yanıt (${problems.first}) '
                '[deneme $attempt/3]');
          }
        } on BudgetExceeded catch (e) {
          stderr.writeln(e.message);
          exit(2);
        } on _QuotaException {
          consecutiveQuotaErrors++;
          if (consecutiveQuotaErrors >= 3) {
            stdout.writeln(
              '\nGünlük kota doldu gibi görünüyor. $done konu üretildi. '
              'Kota sıfırlanınca (genelde gece yarısı UTC) aynı komutu '
              'çalıştırıp devam et.',
            );
            return;
          }
          stderr.writeln('  ... hız/kota sınırı, 65 sn bekleniyor '
              '($consecutiveQuotaErrors/3)');
          await Future.delayed(const Duration(seconds: 65));
          attempt--; // a rate-limit wait does not use up an attempt
        } catch (e) {
          stderr.writeln('  ! $label: $e [deneme $attempt/3]');
          await Future.delayed(Duration(seconds: 5 * attempt));
        }
      }

      if (content == null) {
        skipped++;
        continue;
      }
      final node = files[item.path.key]!.nodeAt(ref.unitIndex, ref.nodeIndex);
      node.addAll(content);
      files[item.path.key]!.save();
      done++;
      stdout.writeln('[$done/$total] ✔ $label');
    }
  } finally {
    client.close();
  }
  stdout.writeln('\nBitti: $done konu üretildi, $skipped atlandı.');
  if (guard != null) stdout.writeln(guard.summary());
}

// ---------------------------------------------------------------------------
// Content files
// ---------------------------------------------------------------------------

class _Ref {
  _Ref(this.unitIndex, this.nodeIndex, this.unitTitle, this.topic);
  final int unitIndex;
  final int nodeIndex;
  final String unitTitle;
  final String topic;
}

class _ContentFile {
  _ContentFile(this.path, this.root);
  final String path;
  final Map<String, dynamic> root;

  Map<String, dynamic> nodeAt(int unit, int node) {
    final units = (root['units'] as List).cast<Map<String, dynamic>>();
    return (units[unit]['nodes'] as List)[node] as Map<String, dynamic>;
  }

  void save() => File(path).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(root),
  );
}

_ContentFile _loadOrCreate(OutlinePath p) {
  final file = File('$contentDir/${p.key}.json');
  if (file.existsSync()) {
    return _ContentFile(
      file.path,
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }
  final root = <String, dynamic>{
    'subjectKey': p.key,
    'title': p.title,
    'examType': 'YKS',
    'subject': p.subject,
    'units': [
      for (var u = 0; u < p.units.length; u++)
        {
          'id': 'unit${u + 1}',
          'order': u + 1,
          'title': p.units[u].title,
          'nodes': [
            for (var n = 0; n < p.units[u].topics.length; n++)
              {
                'id': 'node${n + 1}',
                'order': n + 1,
                'title': p.units[u].topics[n],
                'estimatedMinutes': 15,
              },
          ],
        },
    ],
  };
  // Round-trip through JSON so every nested map has the plain
  // Map<String, dynamic> runtime type (map literals infer narrower types).
  final created = _ContentFile(
    file.path,
    jsonDecode(jsonEncode(root)) as Map<String, dynamic>,
  );
  created.save();
  return created;
}

List<_Ref> _pendingTopics(OutlinePath p, _ContentFile f) {
  final refs = <_Ref>[];
  for (var u = 0; u < p.units.length; u++) {
    for (var n = 0; n < p.units[u].topics.length; n++) {
      final node = f.nodeAt(u, n);
      final hasContent = ((node['flashcards'] as List?) ?? []).isNotEmpty;
      if (!hasContent) refs.add(_Ref(u, n, p.units[u].title, p.units[u].topics[n]));
    }
  }
  return refs;
}

int _rank(String key) {
  final i = priority.indexOf(key);
  return i == -1 ? priority.length : i;
}

// ---------------------------------------------------------------------------
// Prompt, schema, call
// ---------------------------------------------------------------------------

String _levelFor(String stage) {
  switch (stage) {
    case 'TYT':
      return 'TYT (Temel Yeterlilik Testi, 9-10. sınıf müfredatı düzeyi)';
    case 'AYT':
      return 'AYT (Alan Yeterlilik Testi, 11-12. sınıf müfredatı düzeyi)';
    default:
      return 'YDT (Yabancı Dil Testi)';
  }
}

String _prompt(OutlinePath path, _Ref ref) {
  final isEnglish = path.subject == 'İngilizce';
  return 'Sen YKS\'ye hazırlanan öğrenciler için içerik hazırlayan deneyimli '
      'bir öğretmensin.\n'
      'Sınav: ${_levelFor(path.stage)}\n'
      'Ders: ${path.subject}\n'
      'Ünite: ${ref.unitTitle}\n'
      'Konu: ${ref.topic}\n\n'
      'MEB\'in 2026 YKS müfredatına uygun şu içeriği üret: TAM 5 hafıza kartı '
      '(soru-cevap), TAM 5 çoktan seçmeli soru (4 şıklı), TAM 5 boşluk '
      'doldurma sorusu ve TAM 5 doğru/yanlış ifadesi.\n\n'
      'KURALLAR:\n'
      '- Yalnızca kesin ve doğru bildiğin bilgilere dayan; emin olmadığın '
      'bilgiyi, eser/yazar/tarih/formül ayrıntısını kullanma.\n'
      '- Hesap gerektiren sorularda sonucu adım adım doğrula; sayılar basit '
      'olsun. Soru metni eksiksiz ve tek anlamlı olsun (örn. "rakam", '
      '"pozitif tam sayı" gibi koşulları açıkça yaz). Açıklamada çözüm '
      'adımlarını göster ve sonucu tek seferde, kendini düzeltmeden yaz; '
      'bir hata fark edersen soruyu baştan yaz.\n'
      '- Çoktan seçmelide tek doğru cevap olsun; yanlış şıklar makul '
      'çeldiriciler olsun; "hepsi", "hiçbiri" gibi şıklar kullanma.\n'
      '- Boşluk doldurmada boşluğu "____" ile göster; cevap tek kelime ya da '
      'kısa bir ifade olsun.\n'
      '- Doğru/yanlış ifadelerinin hem doğru hem yanlış olanları bulunsun.\n'
      '- Sorular birbirini tekrar etmesin, konunun farklı yönlerini yoklasın; '
      'kartlar kısa ve net olsun.\n'
      '- Her çoktan seçmeli, boşluk doldurma ve doğru/yanlış için 1-2 '
      'cümlelik açıklama yaz.\n'
      '${isEnglish ? '- Bu bir İngilizce dersi: soruları, şıkları ve kartları İngilizce yaz (YDT biçimi); açıklamaları Türkçe yaz.\n' : '- Türkçe karakterleri (ç, ğ, ı, ö, ş, ü, İ) eksiksiz kullan; asla ASCII\'ye çevirme.\n'}';
}

Map<String, dynamic> get _schema => {
  'type': 'OBJECT',
  'properties': {
    'cards': {
      'type': 'ARRAY',
      'minItems': 5,
      'maxItems': 5,
      'items': {
        'type': 'OBJECT',
        'properties': {
          'question': {'type': 'STRING'},
          'answer': {'type': 'STRING'},
        },
        'required': ['question', 'answer'],
      },
    },
    'multipleChoice': {
      'type': 'ARRAY',
      'minItems': 5,
      'maxItems': 5,
      'items': {
        'type': 'OBJECT',
        'properties': {
          'question': {'type': 'STRING'},
          'options': {
            'type': 'ARRAY',
            'minItems': 4,
            'maxItems': 4,
            'items': {'type': 'STRING'},
          },
          'correctIndex': {'type': 'INTEGER'},
          'explanation': {'type': 'STRING'},
        },
        'required': ['question', 'options', 'correctIndex', 'explanation'],
      },
    },
    'fillBlank': {
      'type': 'ARRAY',
      'minItems': 5,
      'maxItems': 5,
      'items': {
        'type': 'OBJECT',
        'properties': {
          'question': {'type': 'STRING'},
          'answer': {'type': 'STRING'},
          'explanation': {'type': 'STRING'},
        },
        'required': ['question', 'answer', 'explanation'],
      },
    },
    'trueFalse': {
      'type': 'ARRAY',
      'minItems': 5,
      'maxItems': 5,
      'items': {
        'type': 'OBJECT',
        'properties': {
          'statement': {'type': 'STRING'},
          'isTrue': {'type': 'BOOLEAN'},
          'explanation': {'type': 'STRING'},
        },
        'required': ['statement', 'isTrue', 'explanation'],
      },
    },
  },
  'required': ['cards', 'multipleChoice', 'fillBlank', 'trueFalse'],
};

class _QuotaException implements Exception {}

Future<Map<String, dynamic>> _call(
  HttpClient client,
  String apiKey,
  String prompt,
  SpendGuard? guard,
) async {
  final request = await client.postUrl(
    Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    ),
  );
  request.headers.set('Content-Type', 'application/json');
  request.headers.set('x-goog-api-key', apiKey);
  request.add(
    utf8.encode(
      jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': _schema,
          'temperature': 0.4,
          'maxOutputTokens': maxOutputTokens,
        },
      }),
    ),
  );
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode == 429) throw _QuotaException();
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }
  final data = jsonDecode(text) as Map<String, dynamic>;
  guard?.record(data['usageMetadata'] as Map<String, dynamic>?);
  final parts = data['candidates'][0]['content']['parts'] as List;
  final out = parts.map((p) => p['text']).whereType<String>().join();
  return jsonDecode(out) as Map<String, dynamic>;
}

// ---------------------------------------------------------------------------
// Validation + shaping into the app's content format
// ---------------------------------------------------------------------------

/// Phrases a model writes when it notices its own mistake mid-answer; such
/// a question/explanation is unreliable.
final _selfCorrecting = RegExp(
  r'düzeltelim|düzeltme yap|hata yap|yanlış yazd|pardon|tekrar hesapla|şöyle düzelt|wait,|actually,|let me re',
  caseSensitive: false,
);

final _turkishLetters = RegExp('[çğıöşüÇĞİÖŞÜâîû]');

/// A long text with none of the Turkish-specific letters is almost certainly
/// ASCII-folded ("hucre", "gore"...).
bool _folded(String s, bool english) =>
    !english && s.length >= 30 && !_turkishLetters.hasMatch(s);

/// Returns the node fields (flashcards / multipleChoice / fillBlank /
/// trueFalse) or null, filling [problems] with why it was rejected.
Map<String, dynamic>? _validateAndBuild(
  Map<String, dynamic> raw,
  String subject,
  _Ref ref,
  List<String> problems,
) {
  final english = subject == 'İngilizce';
  String s(dynamic v) => (v as String? ?? '').trim();
  bool bad(String t) =>
      t.isEmpty ||
      t.contains('�') ||
      _folded(t, english);
  // Only explanations are screened for self-corrections.
  bool badExpl(String t) => bad(t) || _selfCorrecting.hasMatch(t);

  List<Map<String, dynamic>> list(String key) =>
      ((raw[key] as List?) ?? []).whereType<Map<String, dynamic>>().toList();

  final cards = list('cards');
  final mcs = list('multipleChoice');
  final fbs = list('fillBlank');
  final tfs = list('trueFalse');
  if (cards.length < 5 || mcs.length < 5 || fbs.length < 5 || tfs.length < 5) {
    problems.add('beş öğeden az');
    return null;
  }

  final texts = <String>[];
  final cardOut = <Map<String, dynamic>>[];
  for (final c in cards.take(5)) {
    final q = s(c['question']), a = s(c['answer']);
    if (bad(q) || bad(a)) {
      problems.add('kart metni bozuk');
      return null;
    }
    cardOut.add({'question': q, 'answer': a});
    texts.add(q);
  }

  final random = Random(ref.topic.hashCode ^ ref.unitTitle.hashCode);
  final mcOut = <Map<String, dynamic>>[];
  for (final m in mcs.take(5)) {
    final q = s(m['question']);
    final options = ((m['options'] as List?) ?? []).map((o) => s(o)).toList();
    final correct = (m['correctIndex'] as num?)?.toInt() ?? -1;
    final expl = s(m['explanation']);
    if (bad(q) || badExpl(expl) || options.length != 4 || options.any(bad)) {
      problems.add('test sorusu bozuk');
      return null;
    }
    if (options.toSet().length != 4 || correct < 0 || correct > 3) {
      problems.add('şıklar tekrar ediyor ya da cevap dizini geçersiz');
      return null;
    }
    // Spread the correct answer over A-D, unless the options refer to each
    // other ("I ve II", "hepsi"...), where reordering would change meaning.
    final refersToOthers = options.any(
      (o) => RegExp(r'hepsi|hiçbiri|yukarıdaki|\bI\b|\bII\b|\bIII\b|all of|none of',
              caseSensitive: false)
          .hasMatch(o),
    );
    var finalOptions = options;
    var finalCorrect = correct;
    if (!refersToOthers) {
      final order = [0, 1, 2, 3]..shuffle(random);
      finalOptions = [for (final i in order) options[i]];
      finalCorrect = order.indexOf(correct);
    }
    mcOut.add({
      'question': q,
      'options': finalOptions,
      'correctIndex': finalCorrect,
      'explanation': expl,
      'type': 'multipleChoice',
    });
    texts.add(q);
  }

  final fbOut = <Map<String, dynamic>>[];
  for (final f in fbs.take(5)) {
    final q = s(f['question']), a = s(f['answer']), expl = s(f['explanation']);
    if (bad(q) || bad(a) || badExpl(expl) || !q.contains('____') || a.length > 40) {
      problems.add('boşluk doldurma bozuk');
      return null;
    }
    fbOut.add({
      'question': q,
      'options': [a],
      'correctIndex': 0,
      'explanation': expl,
      'type': 'fillBlank',
    });
    texts.add(q);
  }

  final tfOut = <Map<String, dynamic>>[];
  var trueCount = 0;
  for (final t in tfs.take(5)) {
    final q = s(t['statement']), expl = s(t['explanation']);
    final isTrue = t['isTrue'];
    if (bad(q) || badExpl(expl) || isTrue is! bool) {
      problems.add('doğru/yanlış bozuk');
      return null;
    }
    if (isTrue) trueCount++;
    tfOut.add({
      'question': q,
      'options': ['Doğru', 'Yanlış'],
      'correctIndex': isTrue ? 0 : 1,
      'explanation': expl,
      'type': 'trueFalse',
    });
    texts.add(q);
  }
  if (trueCount == 0 || trueCount == 5) {
    problems.add('doğru/yanlış dengesiz (hepsi aynı)');
    return null;
  }

  for (var i = 0; i < texts.length; i++) {
    for (var j = i + 1; j < texts.length; j++) {
      if (_similarity(texts[i], texts[j]) >= 0.7) {
        problems.add('birbirine çok benzeyen sorular');
        return null;
      }
    }
  }

  return {
    'flashcards': [
      {'title': 'Kart Seti 1', 'cards': cardOut},
    ],
    'multipleChoice': [
      {'title': 'Test 1', 'questions': mcOut},
    ],
    'fillBlank': [
      {'title': 'Boşluk Doldurma 1', 'questions': fbOut},
    ],
    'trueFalse': [
      {'title': 'Doğru/Yanlış 1', 'questions': tfOut},
    ],
  };
}

/// Independent second pass: the model solves the questions again WITHOUT
/// seeing our answers; every item whose independent answer differs is
/// dropped. Returns null (with a reason in [problems]) when too few items
/// survive.
Future<Map<String, dynamic>?> _verify(
  HttpClient client,
  String apiKey,
  Map<String, dynamic> content,
  SpendGuard? guard,
  List<String> problems,
) async {
  final mcs = ((content['multipleChoice'] as List).first['questions'] as List)
      .cast<Map<String, dynamic>>();
  final fbs = ((content['fillBlank'] as List).first['questions'] as List)
      .cast<Map<String, dynamic>>();
  final tfs = ((content['trueFalse'] as List).first['questions'] as List)
      .cast<Map<String, dynamic>>();

  final b = StringBuffer(
    'Aşağıdaki YKS sorularını BAĞIMSIZ olarak çöz. Her soru için kendi '
    'bulduğun doğru cevabı ver. Çok dikkatli hesapla ve her sonucu '
    'kontrol et.\n\nÇOKTAN SEÇMELİ (doğru şıkkın 0 tabanlı indeksi, '
    'A=0, B=1, C=2, D=3):\n',
  );
  for (var i = 0; i < mcs.length; i++) {
    final o = (mcs[i]['options'] as List).cast<String>();
    b.writeln('${i + 1}) ${mcs[i]['question']}  A) ${o[0]}  B) ${o[1]}  C) ${o[2]}  D) ${o[3]}');
  }
  b.writeln('\nDOĞRU/YANLIŞ (ifade doğru mu?):');
  for (var i = 0; i < tfs.length; i++) {
    b.writeln('${i + 1}) ${tfs[i]['question']}');
  }
  b.writeln('\nBOŞLUK DOLDURMA (boşluğa gelen kısa cevap):');
  for (var i = 0; i < fbs.length; i++) {
    b.writeln('${i + 1}) ${fbs[i]['question']}');
  }
  final prompt = b.toString();

  guard?.assertCanSpend(
    inputTokens: SpendGuard.estimateTokens(prompt),
    maxOutputTokens: 2048,
  );
  final request = await client.postUrl(
    Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    ),
  );
  request.headers.set('Content-Type', 'application/json');
  request.headers.set('x-goog-api-key', apiKey);
  request.add(
    utf8.encode(
      jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0,
          'maxOutputTokens': 2048,
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'mc': {
                'type': 'ARRAY',
                'items': {'type': 'INTEGER'},
              },
              'tf': {
                'type': 'ARRAY',
                'items': {'type': 'BOOLEAN'},
              },
              'fb': {
                'type': 'ARRAY',
                'items': {'type': 'STRING'},
              },
            },
            'required': ['mc', 'tf', 'fb'],
          },
        },
      }),
    ),
  );
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode == 429) throw _QuotaException();
  if (response.statusCode != 200) {
    throw Exception('doğrulama HTTP ${response.statusCode}');
  }
  final data = jsonDecode(text) as Map<String, dynamic>;
  guard?.record(data['usageMetadata'] as Map<String, dynamic>?);
  final parts = data['candidates'][0]['content']['parts'] as List;
  final answers = jsonDecode(
    parts.map((p) => p['text']).whereType<String>().join(),
  ) as Map<String, dynamic>;
  final mcAns = (answers['mc'] as List).map((e) => (e as num).toInt()).toList();
  final tfAns = (answers['tf'] as List).cast<bool>();
  final fbAns = (answers['fb'] as List).cast<String>();
  if (mcAns.length != mcs.length ||
      tfAns.length != tfs.length ||
      fbAns.length != fbs.length) {
    problems.add('doğrulama yanıtı eksik');
    return null;
  }

  String norm(String t) =>
      t.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  final keptMc = <Map<String, dynamic>>[
    for (var i = 0; i < mcs.length; i++)
      if (mcAns[i] == mcs[i]['correctIndex']) mcs[i],
  ];
  final keptTf = <Map<String, dynamic>>[
    for (var i = 0; i < tfs.length; i++)
      if ((tfs[i]['correctIndex'] == 0) == tfAns[i]) tfs[i],
  ];
  final keptFb = <Map<String, dynamic>>[
    for (var i = 0; i < fbs.length; i++)
      if (_sameAnswer(norm((fbs[i]['options'] as List).first as String), norm(fbAns[i])))
        fbs[i],
  ];
  if (keptMc.length < 3 || keptTf.length < 3 || keptFb.length < 3) {
    problems.add(
      'bağımsız çözümle uyuşmadı (ÇS ${keptMc.length}/5, DY ${keptTf.length}/5, BD ${keptFb.length}/5)',
    );
    return null;
  }
  final dropped = (mcs.length - keptMc.length) +
      (tfs.length - keptTf.length) +
      (fbs.length - keptFb.length);
  if (dropped > 0) stdout.writeln('    (doğrulamada $dropped soru elendi)');
  return {
    'flashcards': content['flashcards'],
    'multipleChoice': [
      {'title': 'Test 1', 'questions': keptMc},
    ],
    'fillBlank': [
      {'title': 'Boşluk Doldurma 1', 'questions': keptFb},
    ],
    'trueFalse': [
      {'title': 'Doğru/Yanlış 1', 'questions': keptTf},
    ],
  };
}

bool _sameAnswer(String mine, String theirs) =>
    mine == theirs ||
    (mine.length >= 3 && theirs.contains(mine)) ||
    (theirs.length >= 3 && mine.contains(theirs));

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

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return null;
  return args[i + 1];
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
