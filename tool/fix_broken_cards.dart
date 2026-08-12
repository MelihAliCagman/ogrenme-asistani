// One-off fixer: regenerates flashcards for specific (lesson, difficulty)
// pairs found to have lost Turkish diacritics, and patches them into
// tool/sample_lessons_output.json in place.

import 'dart:convert';
import 'dart:io';

const model = 'gemini-flash-lite-latest';

const targets = [
  (
    title: 'CompTIA A+ Donanım',
    difficultyKey: 'easy',
    topicPrompt:
        'CompTIA A+ sertifika sınavının donanım (hardware) bölümü için '
        'bilgisayar bileşenleri (anakart, işlemci, RAM, depolama, güç '
        'kaynağı, çevre birimleri) hakkında teknik bilgiler',
    hint: 'Yeni başlayanlara uygun, temel ve genel kavramları test eden kolay seviye',
  ),
];

Future<void> main() async {
  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }

  final file = File('tool/sample_lessons_output.json');
  final lessons = jsonDecode(file.readAsStringSync()) as List;
  final client = HttpClient();

  for (final target in targets) {
    stderr.writeln('Düzeltiliyor: ${target.title} / ${target.difficultyKey}');
    final lesson = lessons.firstWhere(
      (l) => (l as Map<String, dynamic>)['title'] == target.title,
    ) as Map<String, dynamic>;
    final levels = lesson['levels'] as Map<String, dynamic>;
    final content = levels[target.difficultyKey] as Map<String, dynamic>;

    Map<String, dynamic> cardsJson;
    var attempt = 0;
    while (true) {
      attempt++;
      cardsJson = await _generateJson(
        client,
        apiKey,
        'Aşağıdaki konudan, ${target.hint} düzeyinde, öğrenmeye yönelik '
        'TAM OLARAK 10 tane soru-cevap kartı oluştur. Cevaplar kısa, net, '
        'tartışmasız TEK bir doğru cevap olmalı. Türkçe karakterleri (ş, '
        'ğ, ı, ü, ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) MUTLAKA doğru ve eksiksiz '
        'kullan; harfleri ASCII karşılıklarına (s, g, i, u, o, c) asla '
        'çevirme, bu çok önemli.\n\nKonu: ${target.topicPrompt}',
        {
          'type': 'OBJECT',
          'properties': {
            'cards': {
              'type': 'ARRAY',
              'minItems': 10,
              'maxItems': 10,
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
      final cards = cardsJson['cards'] as List;
      final allHaveTurkish = cards.every((c) {
        final text = '${(c as Map)['question']} ${c['answer']}';
        return 'şığüöçİĞÜÖÇŞ'.split('').any(text.contains);
      });
      if (allHaveTurkish) break;
      if (attempt >= 6) {
        stderr.writeln('  UYARI: 6 denemede de tam düzelmedi, son sonuç kullanılıyor.');
        break;
      }
      stderr.writeln('  (hâlâ karakter sorunu var, tekrar deneniyor... deneme $attempt)');
    }

    content['flashcards'] = cardsJson['cards'];
  }

  client.close();
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lessons));
  stderr.writeln('Güncellendi: ${file.path}');
}

String? _readEnvKey(String key) {
  final f = File('.env');
  if (!f.existsSync()) return null;
  for (final line in f.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('$key=')) return trimmed.substring(key.length + 1).trim();
  }
  return null;
}

Future<Map<String, dynamic>> _generateJson(
  HttpClient client,
  String apiKey,
  String prompt,
  Map<String, dynamic> schema,
) async {
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
  );
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
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
              'responseSchema': schema,
            },
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List;
      final parts = candidates[0]['content']['parts'] as List;
      final text = parts
          .map((p) => (p as Map<String, dynamic>)['text'])
          .whereType<String>()
          .join();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('  (istek başarısız: $e, tekrar deneniyor...)');
      await Future.delayed(Duration(seconds: 5 * (attempt + 1)));
    }
  }
  throw Exception('İstek 3 denemede de başarısız oldu.');
}
