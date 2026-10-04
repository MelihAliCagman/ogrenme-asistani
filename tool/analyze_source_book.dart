// Pilot tool: turns the OCR text of a source question-bank book
// (kaynaklar/ocr/p*.txt, produced locally with Tesseract) into two abstract
// artifacts, WITHOUT ever asking the model to reproduce the book:
//
//   1. konu_bilgileri  — the facts/topics the questions are built on,
//                        restated in the model's own words (facts are not
//                        protected by copyright, wording is).
//   2. soru_kaliplari  — a catalog of question PATTERNS (e.g. "I-II-III
//                        proposition ranking", "graph interpretation"),
//                        described abstractly with no verbatim question text.
//
// Later content generation reads only these two artifacts, never the book.
//
// Output goes to kaynaklar/analiz/ (gitignored, stays local) so it can be
// reviewed before anything derived from the book is used.
//
// Safety:
//   * Every call is metered by tool/spend_guard.dart and refused once the
//     --budget-usd limit would be exceeded; re-run with a larger budget to
//     resume (finished chunks are cached on disk).
//   * Book text is only sent with --paid-tier-confirmed, because on the free
//     tier Google may use submitted data to improve its products.
//
// Run:
//   dart run tool/analyze_source_book.dart --dry-run
//   dart run tool/analyze_source_book.dart --budget-usd 2 --paid-tier-confirmed

import 'dart:convert';
import 'dart:io';

import 'spend_guard.dart';

const model = 'gemini-flash-lite-latest';
const maxOutputTokens = 8192;
const outDir = 'kaynaklar/analiz';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final paidConfirmed = args.contains('--paid-tier-confirmed');
  final budgetUsd = double.tryParse(_argValue(args, '--budget-usd') ?? '');
  final pagesDir = _argValue(args, '--pages-dir') ?? 'kaynaklar/ocr';
  final chunkPages = int.tryParse(_argValue(args, '--chunk-pages') ?? '') ?? 30;

  final pages = _loadPages(pagesDir);
  if (pages.isEmpty) {
    stderr.writeln('$pagesDir içinde p<N>.txt bulunamadı. Önce OCR çalıştır.');
    exit(1);
  }
  final chunks = _chunk(pages, chunkPages);
  final estInput = chunks
      .map((c) => SpendGuard.estimateTokens(_chunkPrompt(c.text)))
      .fold<int>(0, (a, b) => a + b);
  final estOutput = chunks.length * 3500 + 6000; // chunk answers + merge
  final estCost = SpendGuard.estimateCost(model, estInput, estOutput);

  stdout.writeln(
    '${pages.length} sayfa, ${chunks.length} parça (parça başı '
    '$chunkPages sayfa).',
  );
  stdout.writeln(
    'Tahmini: ~$estInput giriş + ~$estOutput çıkış token ≈ '
    '\$${estCost.toStringAsFixed(3)}.',
  );
  if (dryRun) {
    stdout.writeln('(--dry-run: istek gönderilmedi.)');
    return;
  }

  if (budgetUsd == null) {
    stderr.writeln('--budget-usd zorunlu (örn. --budget-usd 2).');
    exit(1);
  }
  if (!paidConfirmed) {
    stderr.writeln(
      'Kitap metni Gemini\'ye gönderilecek. Ücretsiz katmanda Google veriyi '
      'ürün geliştirmede kullanabilir. AI Studio\'da faturalandırma '
      'açıkken --paid-tier-confirmed ekleyerek tekrar çalıştır.',
    );
    exit(1);
  }

  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }

  Directory(outDir).createSync(recursive: true);
  final guard = SpendGuard(budgetUsd: budgetUsd, model: model);
  stdout.writeln('Başlangıç: ${guard.summary()}');
  final client = HttpClient();

  try {
    final chunkResults = <Map<String, dynamic>>[];
    for (var i = 0; i < chunks.length; i++) {
      final cachePath = '$outDir/parca_${i + 1}.json';
      final cache = File(cachePath);
      if (cache.existsSync()) {
        stdout.writeln('Parça ${i + 1}/${chunks.length}: önbellekte, atlanıyor.');
        chunkResults.add(
          jsonDecode(cache.readAsStringSync()) as Map<String, dynamic>,
        );
        continue;
      }
      stdout.writeln(
        'Parça ${i + 1}/${chunks.length} (sayfa ${chunks[i].first}-'
        '${chunks[i].last}) analiz ediliyor...',
      );
      final result = await _callJson(
        client,
        apiKey,
        guard,
        prompt: _chunkPrompt(chunks[i].text),
        schema: _chunkSchema,
      );
      cache.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(result),
      );
      chunkResults.add(result);
      stdout.writeln('  ${guard.summary()}');
    }

    stdout.writeln('Soru kalıpları birleştiriliyor...');
    final allPatterns = chunkResults
        .expand((r) => (r['soru_kaliplari'] as List? ?? []))
        .toList();
    final merged = await _callJson(
      client,
      apiKey,
      guard,
      prompt: _mergePrompt(jsonEncode(allPatterns)),
      schema: _mergeSchema,
    );

    final allTopics = chunkResults
        .expand((r) => (r['konu_bilgileri'] as List? ?? []))
        .toList();
    File('$outDir/konu_bilgileri.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(allTopics),
    );
    File('$outDir/soru_kaliplari.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(merged['soru_kaliplari']),
    );
    stdout.writeln('Bitti. Çıktılar: $outDir/');
    stdout.writeln(guard.summary());
  } on BudgetExceeded catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(guard.summary());
    exit(2);
  } finally {
    client.close();
  }
}

// ---------------------------------------------------------------------------
// Prompts & schemas
// ---------------------------------------------------------------------------

String _chunkPrompt(String text) =>
    'Aşağıda bir TYT Biyoloji soru bankasından OCR ile okunmuş sayfalar var '
    '(OCR hataları, bozuk tablolar ve karışmış sütunlar olabilir). '
    'İki şey çıkar:\n'
    '1) konu_bilgileri: Sayfalarda ele alınan konuları ve her konu için '
    'soruların dayandığı doğru biyolojik olguları KENDİ CÜMLELERİNLE yaz.\n'
    '2) soru_kaliplari: Sayfalardaki soruların SORU KALIPLARINI soyut '
    'biçimde tanımla (ad, ölçtüğü beceri, açıklama, soyut şablon, 1-5 zorluk). '
    'Şablon, konudan bağımsız bir yapı olmalı (örn. "Üç öncül verilir, '
    'hangilerinin doğru olduğu sorulur").\n\n'
    'KESİN KURALLAR: Kitaptan hiçbir soruyu, cümleyi, şıkkı, tablo '
    'satırını veya sayısal değeri birebir aktarma; soru metni yazma, yalnızca '
    'olguyu ve kalıbı anlat. OCR hatalarını düzeltebilirsin ama emin '
    'olmadığın bir olguyu ekleme. Türkçe karakterleri doğru kullan.\n\n'
    'SAYFALAR:\n$text';

String _mergePrompt(String patternsJson) =>
    'Aşağıda bir kitabın parçalarından ayrı ayrı çıkarılmış soru kalıpları '
    '(JSON) var. Aynı veya çok benzer olanları birleştirip tekrarsız, '
    'tutarlı bir kalıp kataloğu oluştur. Her kalıp için kaç parçada '
    'göründüğünü yaklaşık "sayi" olarak ver. Soru metni üretme, yalnızca '
    'soyut kalıpları yaz.\n\n$patternsJson';

const _patternSchema = {
  'type': 'OBJECT',
  'properties': {
    'ad': {'type': 'STRING'},
    'beceri': {'type': 'STRING'},
    'aciklama': {'type': 'STRING'},
    'soyut_sablon': {'type': 'STRING'},
    'zorluk': {'type': 'INTEGER'},
  },
  'required': ['ad', 'beceri', 'aciklama', 'soyut_sablon', 'zorluk'],
};

const _chunkSchema = {
  'type': 'OBJECT',
  'properties': {
    'konu_bilgileri': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'konu': {'type': 'STRING'},
          'olgular': {
            'type': 'ARRAY',
            'items': {'type': 'STRING'},
          },
        },
        'required': ['konu', 'olgular'],
      },
    },
    'soru_kaliplari': {'type': 'ARRAY', 'items': _patternSchema},
  },
  'required': ['konu_bilgileri', 'soru_kaliplari'],
};

final _mergeSchema = {
  'type': 'OBJECT',
  'properties': {
    'soru_kaliplari': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          ...(_patternSchema['properties'] as Map<String, dynamic>),
          'sayi': {'type': 'INTEGER'},
        },
        'required': ['ad', 'beceri', 'aciklama', 'soyut_sablon', 'zorluk'],
      },
    },
  },
  'required': ['soru_kaliplari'],
};

// ---------------------------------------------------------------------------
// Gemini call (metered)
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>> _callJson(
  HttpClient client,
  String apiKey,
  SpendGuard guard, {
  required String prompt,
  required Map<String, dynamic> schema,
}) async {
  guard.assertCanSpend(
    inputTokens: SpendGuard.estimateTokens(prompt),
    maxOutputTokens: maxOutputTokens,
  );
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
  );
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
      'responseSchema': schema,
      'maxOutputTokens': maxOutputTokens,
    },
  });

  for (var attempt = 1; attempt <= 4; attempt++) {
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('x-goog-api-key', apiKey);
    request.add(utf8.encode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();

    if (response.statusCode == 429 || response.statusCode >= 500) {
      stderr.writeln('  HTTP ${response.statusCode}, yeniden denenecek ($attempt/4)');
      await Future.delayed(Duration(seconds: 10 * attempt));
      continue;
    }
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $text');
    }
    final data = jsonDecode(text) as Map<String, dynamic>;
    guard.record(data['usageMetadata'] as Map<String, dynamic>?);
    final parts = data['candidates'][0]['content']['parts'] as List;
    final out = parts.map((p) => p['text']).whereType<String>().join();
    await Future.delayed(const Duration(seconds: 5)); // stay under 15 RPM
    return jsonDecode(out) as Map<String, dynamic>;
  }
  throw Exception('İstek 4 denemede de başarısız oldu.');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _Chunk {
  _Chunk(this.first, this.last, this.text);
  final int first;
  final int last;
  final String text;
}

Map<int, String> _loadPages(String dir) {
  final result = <int, String>{};
  final d = Directory(dir);
  if (!d.existsSync()) return result;
  final re = RegExp(r'p(\d+)\.txt$');
  for (final f in d.listSync().whereType<File>()) {
    final m = re.firstMatch(f.path.replaceAll('\\', '/'));
    if (m == null) continue;
    result[int.parse(m.group(1)!)] = f.readAsStringSync();
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

List<_Chunk> _chunk(Map<int, String> pages, int perChunk) {
  final numbers = pages.keys.toList();
  final chunks = <_Chunk>[];
  for (var i = 0; i < numbers.length; i += perChunk) {
    final slice = numbers.skip(i).take(perChunk).toList();
    final text = slice.map((n) => '--- SAYFA $n ---\n${pages[n]}').join('\n');
    chunks.add(_Chunk(slice.first, slice.last, text));
  }
  return chunks;
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
