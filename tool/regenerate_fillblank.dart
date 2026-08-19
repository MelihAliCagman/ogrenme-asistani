// One-off repair tool: re-generates ONLY the `fillBlank` arrays inside
// tool/curriculum_path_output.json's existing nodes (flashcards/
// multipleChoice/trueFalse and all unit titles are left untouched), with
// validation that retries the model call whenever an answer comes back
// with a corrupted (U+FFFD) or ASCII-folded-away-from-Turkish character.
// See tool/generate_curriculum_path.dart for the original full-content
// generator this mirrors.
//
// Run with: dart run tool/regenerate_fillblank.dart

import 'dart:convert';
import 'dart:io';

import 'package:ogrenme_asistani/models/quiz_question.dart';

const model = 'gemini-flash-lite-latest';
const _outputPath = 'tool/curriculum_path_output.json';

Future<void> main() async {
  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }

  final file = File(_outputPath);
  if (!file.existsSync()) {
    stderr.writeln('Bulunamadı: $_outputPath');
    exit(1);
  }
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final units = data['units'] as List;

  final client = HttpClient();

  for (final rawUnit in units) {
    final unit = rawUnit as Map<String, dynamic>;
    final nodes = unit['nodes'] as List;
    for (final rawNode in nodes) {
      final node = rawNode as Map<String, dynamic>;
      final title = node['title'] as String;
      stderr.writeln('=== $title ===');
      final topic =
          'TYT Biyoloji sınavına hazırlanan bir öğrenci için "$title" '
          'konusu.';
      final questions = await _generateFillBlank(client, apiKey, topic);
      node['fillBlank'] = questions.map((q) => q.toJson()).toList();
      stderr.writeln('  -> ${questions.length} boşluk doldurma sorusu yenilendi.');
    }
  }

  client.close();

  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stderr.writeln('Yazıldı: $_outputPath');
}

Future<List<QuizQuestion>> _generateFillBlank(
  HttpClient client,
  String apiKey,
  String topic,
) async {
  const maxAttempts = 4;
  List<QuizQuestion> lastResult = const [];
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final json = await _generateJson(
      client,
      apiKey,
      'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde TAM '
      'OLARAK 5 tane boşluk doldurma sorusu oluştur. Her sorunun metninde '
      'boşluk bırakılacak yere "____" (alt çizgi) koy, answer alanına o '
      'boşluğa gelmesi gereken kısa (tek kelime veya kısa bir ifade) doğru '
      'cevabı yaz. answer alanını normal Türkçe yazım kurallarına uygun '
      'şekilde yaz; Türkçe özel karakterleri (ç, ğ, ı, ö, ş, ü ve büyük '
      'halleri Ç, Ğ, İ, Ö, Ş, Ü) gerektiği yerde MUTLAKA kullan, ASCII '
      'karşılıklarına çevirme (doğru örnek: "üreme", yanlış örnek: '
      '"ureme"). Her soru için kısa (1-2 cümlelik) bir explanation yaz. '
      'Türkçe karakterleri (ş, ğ, ı, ü, ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve '
      'eksiksiz kullan; harfleri ASCII karşılıklarına çevirme.'
      '\n\nKonu: $topic',
      {
        'type': 'OBJECT',
        'properties': {
          'questions': {
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
        .where((q) => q.question.isNotEmpty && q.answerText.isNotEmpty)
        .toList();

    final hasCorruptedAnswer = questions.any(
      (q) => q.answerText.contains('�'),
    );
    if (!hasCorruptedAnswer && questions.length >= 5) {
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
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('x-goog-api-key', apiKey);
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
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
  throw Exception('İstek 3 denemede de başarısız oldu: $lastError');
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
