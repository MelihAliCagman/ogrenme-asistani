// Generates the content of one TYT Biyoloji unit for the "Ders Yolu" feature
// via Gemini and merges it into tool/curriculum_path_output.json.
//
// Unlike the older per-unit generators (generate_unit2..6_content.dart) this
// one is generic: the unit title and every node's title / scope text come from
// tool/curriculum_manifest.json, so a new unit only needs its nodes written
// into the manifest.
//
// Writes content ALREADY split into the part structure (5x10 Test, 5x10 Kart
// Seti, 2x10 Doğru/Yanlış, 2x10 Boşluk Doldurma) as it generates each batch,
// and is resume-aware: nodes that are already complete are skipped.
//
// Items that look ASCII-folded (Turkish letters dropped) are rejected so the
// batch retry logic replaces them; run tool/repair_diacritics.dart and
// `dart run tool/pipeline.dart validate` afterwards anyway.
//
// Plain Dart (no Flutter engine needed). Reads GEMINI_API_KEY from .env.
//
// Run: dart run tool/generate_unit_content.dart unit7

import 'dart:convert';
import 'dart:io';

import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

const model = 'gemini-flash-lite-latest';
const outputPath = 'tool/curriculum_path_output.json';

const batchSize = 10;

const maxRetryBatchesPerType = 6;
const similarityThreshold = 0.6;

const manifestPath = 'tool/curriculum_manifest.json';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Kullanım: dart run tool/generate_unit_content.dart <unitId>  (örn. unit7)');
    exit(64);
  }
  final unitId = args.first;
  final manifest = jsonDecode(File(manifestPath).readAsStringSync()) as Map<String, dynamic>;
  final manifestPathEntry = (manifest['paths'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['subjectKey'] == 'tyt_biyoloji');
  final manifestUnit = (manifestPathEntry['units'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere(
        (u) => u['id'] == unitId,
        orElse: () => throw ArgumentError('$unitId manifestte yok.'),
      );
  final unitTitle = manifestUnit['title'] as String;
  final nodes = [
    for (final n in (manifestUnit['nodes'] as List).cast<Map<String, dynamic>>())
      (
        id: n['id'] as String,
        title: n['title'] as String,
        estimatedMinutes: (n['estimatedMinutes'] as num?)?.toInt() ?? 15,
        scope: (n['scope'] as String?) ?? '',
      ),
  ];
  if (nodes.isEmpty) {
    stderr.writeln('$unitId için manifestte düğüm tanımı yok.');
    exit(1);
  }
  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }

  final outFile = File(outputPath);
  if (!outFile.existsSync()) {
    stderr.writeln('$outputPath bulunamadı.');
    exit(1);
  }
  final root = jsonDecode(outFile.readAsStringSync()) as Map<String, dynamic>;
  final units = (root['units'] as List).cast<Map<String, dynamic>>();
  final unitIndex = units.indexWhere((u) => u['id'] == unitId);
  if (unitIndex == -1) {
    stderr.writeln('$outputPath içinde $unitId bulunamadı.');
    exit(1);
  }

  final existingNodes = ((units[unitIndex]['nodes'] as List?) ?? [])
      .cast<Map<String, dynamic>>();
  final generatedNodes = <Map<String, dynamic>>[];
  for (final n in existingNodes) {
    final isComplete =
        ((n['flashcards'] as List?)?.length ?? 0) >= 5 &&
        ((n['multipleChoice'] as List?)?.length ?? 0) >= 5 &&
        ((n['fillBlank'] as List?)?.length ?? 0) >= 2 &&
        ((n['trueFalse'] as List?)?.length ?? 0) >= 2;
    if (isComplete) generatedNodes.add(n);
  }
  final doneIds = generatedNodes.map((n) => n['id']).toSet();

  final client = HttpClient();

  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (doneIds.contains(node.id)) {
      stderr.writeln('=== ${node.title} (önceden tamamlanmış, atlanıyor) ===');
      continue;
    }
    stderr.writeln('=== ${node.title} ===');
    final topic =
        'TYT Biyoloji sınavına hazırlanan bir öğrenci için "$unitTitle" '
        'ünitesinin "${node.title}" alt konusu. Sorular '
        'SADECE aşağıdaki kapsam notlarındaki kavramlara dayanmalı, bu '
        'notların dışına çıkmamalı, TYT seviyesinde kalmalı:\n${node.scope}';

    stderr.writeln('  -> Hafıza kartları üretiliyor (50, 5 parça)...');
    final flashcardParts = await _generatePartedFlashcards(
      client: client,
      apiKey: apiKey,
      topic: topic,
      totalParts: 5,
      titlePrefix: 'Kart Seti',
    );

    stderr.writeln('  -> Çoktan seçmeli sorular üretiliyor (50, 5 parça)...');
    final mcParts = await _generatePartedQuestions(
      client: client,
      apiKey: apiKey,
      topic: topic,
      totalParts: 5,
      titlePrefix: 'Test',
      contentLabel: 'çoktan seçmeli soru',
      generateBatch: (avoidList) =>
          _generateMultipleChoiceBatch(client, apiKey, topic, avoidList),
    );

    stderr.writeln('  -> Boşluk doldurma soruları üretiliyor (20, 2 parça)...');
    final fillBlankParts = await _generatePartedQuestions(
      client: client,
      apiKey: apiKey,
      topic: topic,
      totalParts: 2,
      titlePrefix: 'Boşluk Doldurma',
      contentLabel: 'boşluk doldurma sorusu',
      generateBatch: (avoidList) =>
          _generateFillBlankBatch(client, apiKey, topic, avoidList),
    );

    stderr.writeln('  -> Doğru/Yanlış soruları üretiliyor (20, 2 parça)...');
    final trueFalseParts = await _generatePartedQuestions(
      client: client,
      apiKey: apiKey,
      topic: topic,
      totalParts: 2,
      titlePrefix: 'Doğru/Yanlış',
      contentLabel: 'doğru/yanlış ifadesi',
      generateBatch: (avoidList) =>
          _generateTrueFalseBatch(client, apiKey, topic, avoidList),
    );

    generatedNodes.add({
      'id': node.id,
      'order': i + 1,
      'title': node.title,
      'estimatedMinutes': node.estimatedMinutes,
      'flashcards': flashcardParts,
      'multipleChoice': mcParts,
      'fillBlank': fillBlankParts,
      'trueFalse': trueFalseParts,
    });

    stderr.writeln(
      '  <- Tamamlandı: ${flashcardParts.length} kart parçası, '
      '${mcParts.length} ÇS parçası, ${fillBlankParts.length} BD parçası, '
      '${trueFalseParts.length} D/Y parçası',
    );

    units[unitIndex] = {...units[unitIndex], 'nodes': generatedNodes};
    root['units'] = units;
    outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
    stderr.writeln('  (ara kayıt yazıldı: ${outFile.path})');
  }

  client.close();
  stderr.writeln('Tüm alt konular tamamlandı: ${outFile.path}');
}

Future<List<Map<String, dynamic>>> _generatePartedFlashcards({
  required HttpClient client,
  required String apiKey,
  required String topic,
  required int totalParts,
  required String titlePrefix,
}) async {
  final parts = <Map<String, dynamic>>[];
  final acceptedTexts = <String>[];
  var extraAttempts = 0;

  while (parts.length < totalParts) {
    final cards = <Flashcard>[];
    while (cards.length < batchSize) {
      final batch = await _generateFlashcardBatch(client, apiKey, topic, acceptedTexts);
      var addedThisRound = 0;
      for (final card in batch) {
        if (cards.length >= batchSize) break;
        final text = '${card.question} ${card.answer}';
        if (text.trim().isEmpty) continue;
        final isDuplicate = acceptedTexts.any(
          (existing) => _similarity(text, existing) >= similarityThreshold,
        );
        if (isDuplicate) continue;
        cards.add(card);
        acceptedTexts.add(text);
        addedThisRound++;
      }
      stderr.writeln(
        '     parti: +$addedThisRound (parça ${parts.length + 1}/$totalParts, '
        '${cards.length}/$batchSize hafıza kartı)',
      );
      if (addedThisRound == 0) {
        extraAttempts++;
        if (extraAttempts > maxRetryBatchesPerType) {
          stderr.writeln(
            '     UYARI: $maxRetryBatchesPerType ek denemeden sonra hâlâ '
            'yeterli benzersiz hafıza kartı üretilemedi, '
            '${cards.length}/$batchSize ile devam ediliyor.',
          );
          break;
        }
      }
    }
    parts.add({
      'title': '$titlePrefix ${parts.length + 1}',
      'cards': cards.map((c) => c.toJson()).toList(),
    });
  }
  return parts;
}

Future<List<Map<String, dynamic>>> _generatePartedQuestions({
  required HttpClient client,
  required String apiKey,
  required String topic,
  required int totalParts,
  required String titlePrefix,
  required String contentLabel,
  required Future<List<QuizQuestion>> Function(List<String> avoidList) generateBatch,
}) async {
  final parts = <Map<String, dynamic>>[];
  final acceptedTexts = <String>[];
  var extraAttempts = 0;

  while (parts.length < totalParts) {
    final questions = <QuizQuestion>[];
    while (questions.length < batchSize) {
      final batch = await generateBatch(acceptedTexts);
      var addedThisRound = 0;
      for (final q in batch) {
        if (questions.length >= batchSize) break;
        if (q.question.trim().isEmpty) continue;
        final isDuplicate = acceptedTexts.any(
          (existing) => _similarity(q.question, existing) >= similarityThreshold,
        );
        if (isDuplicate) continue;
        questions.add(q);
        acceptedTexts.add(q.question);
        addedThisRound++;
      }
      stderr.writeln(
        '     parti: +$addedThisRound (parça ${parts.length + 1}/$totalParts, '
        '${questions.length}/$batchSize $contentLabel)',
      );
      if (addedThisRound == 0) {
        extraAttempts++;
        if (extraAttempts > maxRetryBatchesPerType) {
          stderr.writeln(
            '     UYARI: $maxRetryBatchesPerType ek denemeden sonra hâlâ '
            'yeterli benzersiz $contentLabel üretilemedi, '
            '${questions.length}/$batchSize ile devam ediliyor.',
          );
          break;
        }
      }
    }
    parts.add({
      'title': '$titlePrefix ${parts.length + 1}',
      'questions': questions.map((q) => q.toJson()).toList(),
    });
  }
  return parts;
}

double _similarity(String a, String b) {
  final wa = _wordSet(a);
  final wb = _wordSet(b);
  if (wa.isEmpty || wb.isEmpty) return 0;
  final intersection = wa.intersection(wb).length;
  final union = wa.union(wb).length;
  return union == 0 ? 0 : intersection / union;
}

Set<String> _wordSet(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-zçğıöşü0-9\s]'), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.length > 2)
    .toSet();

String _avoidListBlock(List<String> avoidList, {int maxItems = 40}) {
  if (avoidList.isEmpty) return '';
  final shown = avoidList.length > maxItems
      ? avoidList.sublist(avoidList.length - maxItems)
      : avoidList;
  final bullets = shown.map((t) => '- $t').join('\n');
  return '\n\nDaha önce bu alt konu için üretilmiş olanlar (BUNLARLA AYNI '
      'veya ÇOK BENZER bir soru/kart ÜRETME, farklı bir kavrama veya '
      'farklı bir açıya odaklan):\n$bullets';
}

const _turkishCharNote =
    'Türkçe karakterleri (ş, ğ, ı, ü, ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve '
    'eksiksiz kullan; harfleri ASCII karşılıklarına çevirme.';

Future<List<Flashcard>> _generateFlashcardBatch(
  HttpClient client,
  String apiKey,
  String topic,
  List<String> avoidList,
) async {
  final json = await _generateJson(
    client,
    apiKey,
    'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde, '
    'öğrenmeye yönelik TAM OLARAK $batchSize tane soru-cevap kartı '
    'oluştur. Cevaplar kısa, net, tartışmasız TEK bir doğru cevap olmalı. '
    '$_turkishCharNote\n\nKonu: $topic${_avoidListBlock(avoidList)}',
    {
      'type': 'OBJECT',
      'properties': {
        'cards': {
          'type': 'ARRAY',
          'minItems': batchSize,
          'maxItems': batchSize,
          'items': {
            'type': 'OBJECT',
            'properties': {
              'question': {'type': 'STRING'},
              'answer': {'type': 'STRING'},
            },
            'required': ['question', 'answer'],
          },
        },
      },
      'required': ['cards'],
    },
  );
  final rawCards = json['cards'] as List;
  return rawCards
      .whereType<Map<String, dynamic>>()
      .map(Flashcard.fromJson)
      .where(
        (c) =>
            c.question.isNotEmpty &&
            c.answer.isNotEmpty &&
            !_looksFolded(c.question) &&
            !_looksFolded(c.answer),
      )
      .toList();
}

Future<List<QuizQuestion>> _generateMultipleChoiceBatch(
  HttpClient client,
  String apiKey,
  String topic,
  List<String> avoidList,
) async {
  final json = await _generateJson(
    client,
    apiKey,
    'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde, her '
    'biri 4 şıklı (A, B, C, D) ve tek doğru cevabı olan TAM OLARAK '
    '$batchSize tane çoktan seçmeli soru oluştur. correctIndex, doğru '
    'şıkkın options listesindeki 0 tabanlı indeksi olmalı. Bir sorunun 4 '
    'şıkkı birbirinden kesinlikle farklı olmalı. Her soru için kısa (1-2 '
    'cümlelik) bir explanation yaz. $_turkishCharNote'
    '\n\nKonu: $topic${_avoidListBlock(avoidList)}',
    {
      'type': 'OBJECT',
      'properties': {
        'questions': {
          'type': 'ARRAY',
          'minItems': batchSize,
          'maxItems': batchSize,
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
      },
      'required': ['questions'],
    },
  );
  final rawQuestions = json['questions'] as List;
  return rawQuestions
      .whereType<Map<String, dynamic>>()
      .map(QuizQuestion.fromJson)
      .where(
        (q) =>
            q.question.isNotEmpty &&
            !_looksFolded(q.question) &&
            !q.options.any(_looksFolded) &&
            q.options.length == 4 &&
            q.correctIndex >= 0 &&
            q.correctIndex < 4,
      )
      .toList();
}

Future<List<QuizQuestion>> _generateFillBlankBatch(
  HttpClient client,
  String apiKey,
  String topic,
  List<String> avoidList,
) async {
  const maxAttempts = 4;
  List<QuizQuestion> lastResult = const [];
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final json = await _generateJson(
      client,
      apiKey,
      'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde TAM '
      'OLARAK $batchSize tane boşluk doldurma sorusu oluştur. Her sorunun '
      'metninde boşluk bırakılacak yere "____" (alt çizgi) koy, answer '
      'alanına o boşluğa gelmesi gereken kısa (tek kelime veya kısa bir '
      'ifade) doğru cevabı yaz. answer alanını normal Türkçe yazım '
      'kurallarına uygun şekilde yaz; Türkçe özel karakterleri (ç, ğ, ı, '
      'ö, ş, ü ve büyük halleri Ç, Ğ, İ, Ö, Ş, Ü) gerektiği yerde '
      'MUTLAKA kullan, ASCII karşılıklarına çevirme (doğru örnek: '
      '"üreme", yanlış örnek: "ureme"). Her soru için kısa (1-2 cümlelik) '
      'bir explanation yaz. $_turkishCharNote'
      '\n\nKonu: $topic${_avoidListBlock(avoidList)}',
      {
        'type': 'OBJECT',
        'properties': {
          'questions': {
            'type': 'ARRAY',
            'minItems': batchSize,
            'maxItems': batchSize,
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
        },
        'required': ['questions'],
      },
    );
    final rawQuestions = json['questions'] as List;
    final questions = rawQuestions
        .whereType<Map<String, dynamic>>()
        .map(
          (q) => QuizQuestion(
            question: (q['question'] as String? ?? '').trim(),
            options: [(q['answer'] as String? ?? '').trim()],
            correctIndex: 0,
            explanation: (q['explanation'] as String? ?? '').trim(),
            type: QuestionType.fillBlank,
          ),
        )
        .where(
          (q) =>
              q.question.isNotEmpty &&
              q.answerText.isNotEmpty &&
              !_looksFolded(q.question),
        )
        .toList();

    final hasCorruptedAnswer = questions.any((q) => q.answerText.contains('�'));
    if (!hasCorruptedAnswer && questions.length >= batchSize) {
      return questions;
    }
    lastResult = questions;
    stderr.writeln(
      '     (boşluk doldurma cevabında bozuk karakter tespit edildi, '
      'yeniden üretiliyor... deneme ${attempt + 1}/$maxAttempts)',
    );
  }
  stderr.writeln(
    '     UYARI: $maxAttempts denemeden sonra hâlâ bozuk karakter '
    'olabilir, bulunanla devam ediliyor.',
  );
  return lastResult;
}

Future<List<QuizQuestion>> _generateTrueFalseBatch(
  HttpClient client,
  String apiKey,
  String topic,
  List<String> avoidList,
) async {
  final json = await _generateJson(
    client,
    apiKey,
    'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde TAM '
    'OLARAK $batchSize tane doğru/yanlış ifadesi oluştur. Her ifade '
    'konudaki bir bilgiyi doğru ya da kasıtlı olarak yanlış şekilde '
    'sunmalı; isTrue alanı ifadenin doğru olup olmadığını belirtmeli. '
    'Yaklaşık yarısı doğru, yaklaşık yarısı yanlış ifade olsun. Her ifade '
    'için kısa (1-2 cümlelik) bir explanation yaz. $_turkishCharNote'
    '\n\nKonu: $topic${_avoidListBlock(avoidList)}',
    {
      'type': 'OBJECT',
      'properties': {
        'questions': {
          'type': 'ARRAY',
          'minItems': batchSize,
          'maxItems': batchSize,
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
      'required': ['questions'],
    },
  );
  final rawQuestions = json['questions'] as List;
  return rawQuestions
      .whereType<Map<String, dynamic>>()
      .map(
        (q) => QuizQuestion(
          question: (q['statement'] as String? ?? '').trim(),
          options: const ['Doğru', 'Yanlış'],
          correctIndex: (q['isTrue'] as bool? ?? true) ? 0 : 1,
          explanation: (q['explanation'] as String? ?? '').trim(),
          type: QuestionType.trueFalse,
        ),
      )
      .where((q) => q.question.isNotEmpty && !_looksFolded(q.question))
      .toList();
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

final List<DateTime> _recentRequestTimes = [];
const _maxRequestsPerWindow = 12;
const _rateWindow = Duration(seconds: 60);

Future<void> _throttle() async {
  final now = DateTime.now();
  _recentRequestTimes.removeWhere((t) => now.difference(t) > _rateWindow);
  if (_recentRequestTimes.length >= _maxRequestsPerWindow) {
    final oldest = _recentRequestTimes.first;
    final waitFor =
        _rateWindow - now.difference(oldest) + const Duration(seconds: 1);
    if (waitFor > Duration.zero) {
      stderr.writeln('     (hız sınırı: ${waitFor.inSeconds}s bekleniyor...)');
      await Future.delayed(waitFor);
    }
  }
  _recentRequestTimes.add(DateTime.now());
}

Duration? _parseRetryDelay(String responseBody) {
  final match = RegExp(r'"retryDelay"\s*:\s*"(\d+)s"').firstMatch(responseBody);
  if (match == null) return null;
  return Duration(seconds: int.parse(match.group(1)!));
}

Future<Map<String, dynamic>> _generateJson(
  HttpClient client,
  String apiKey,
  String prompt,
  Map<String, dynamic> schema,
) async {
  final data = await _post(client, apiKey, {
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
    },
  });
  final text = _extractText(data);
  return jsonDecode(text) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _post(
  HttpClient client,
  String apiKey,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
  );
  Object? lastError;
  const maxAttempts = 6;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await _throttle();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('x-goog-api-key', apiKey);
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 429) {
        final retryDelay = _parseRetryDelay(responseBody) ?? const Duration(seconds: 60);
        final wait = retryDelay + const Duration(seconds: 5);
        stderr.writeln(
          '     (429 hız sınırı, ${wait.inSeconds}s bekleyip tekrar '
          'deneniyor... deneme ${attempt + 1}/$maxAttempts)',
        );
        await Future.delayed(wait);
        lastError = Exception('HTTP 429: $responseBody');
        continue;
      }
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      lastError = e;
      stderr.writeln('     (deneme ${attempt + 1} başarısız: $e, tekrar deneniyor...)');
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
  }
  throw Exception('İstek $maxAttempts denemede de başarısız oldu: $lastError');
}

String _extractText(Map<String, dynamic> data) {
  final candidates = data['candidates'] as List;
  final parts = candidates[0]['content']['parts'] as List;
  return parts
      .map((part) => (part as Map<String, dynamic>)['text'])
      .whereType<String>()
      .join()
      .trim();
}

/// A long text with none of the Turkish-specific letters is almost certainly
/// ASCII-folded ("hucre", "gore", ...) — real Turkish biology sentences
/// contain ç ğ ı ö ş ü.
bool _looksFolded(String s) {
  if (s.length < 30) return false;
  return !RegExp('[çğıöşüÇĞİÖŞÜâîû]').hasMatch(s);
}
