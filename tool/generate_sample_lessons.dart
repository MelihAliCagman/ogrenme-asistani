// One-off tool: generates content for the Keşfet (Discover) tab's sample
// lessons via Gemini and writes it to tool/sample_lessons_output.json for
// review. Run with: dart run tool/generate_sample_lessons.dart
//
// Plain Dart (no Flutter engine needed) so it can run headlessly here.
// Reads GEMINI_API_KEY straight out of .env.

import 'dart:convert';
import 'dart:io';

const model = 'gemini-flash-lite-latest';

const lessons = [
  (
    title: 'KPSS Genel Kültür',
    color: 0xFF1976D2, // Colors.blue.shade700-ish
    topicPrompt:
        'KPSS (Kamu Personeli Seçme Sınavı) Genel Kültür bölümü için '
        'Türkiye tarihi, coğrafyası, güncel anayasal düzen ve genel kültür '
        'konularından, orta zorlukta, sınava hazırlanan bir adayın '
        'öğrenmesi gereken temel bilgiler',
  ),
  (
    title: 'CompTIA A+ Donanım',
    color: 0xFFEF6C00, // Colors.orange.shade800-ish
    topicPrompt:
        'CompTIA A+ sertifika sınavının donanım (hardware) bölümü için '
        'bilgisayar bileşenleri (anakart, işlemci, RAM, depolama, güç '
        'kaynağı, çevre birimleri) hakkında temel ve orta seviye teknik '
        'bilgiler',
  ),
  (
    title: 'YDS İngilizce',
    color: 0xFF388E3C, // Colors.green.shade700-ish
    topicPrompt:
        'YDS (Yabancı Dil Sınavı) İngilizce sınavına hazırlanan bir '
        'adayın bilmesi gereken orta-ileri seviye kelime bilgisi, temel '
        'dilbilgisi yapıları (tenses, conditionals, passive voice vb.) ve '
        'sık çıkan konular',
  ),
];

Future<void> main() async {
  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }

  final client = HttpClient();
  final results = <Map<String, dynamic>>[];

  for (final lesson in lessons) {
    stderr.writeln('Üretiliyor: ${lesson.title}...');

    final summary = await _generateText(
      client,
      apiKey,
      'Aşağıdaki konu için, bu konuya yeni başlayan bir öğrenciye hitap '
      'eden, 3-5 cümlelik kısa ve motive edici bir "ders özeti" yaz. '
      'Sadece özet metnini yaz, başlık veya madde işareti kullanma. '
      'Türkçe karakterleri (ş, ğ, ı, ü, ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve '
      'eksiksiz kullan.\n\nKonu: ${lesson.topicPrompt}',
    );

    final cardsJson = await _generateJson(
      client,
      apiKey,
      'Aşağıdaki konudan öğrenmeye yönelik TAM OLARAK 10 tane soru-cevap '
      'kartı oluştur. Sorular önemli kavramları test etmeli; cevaplar '
      'kısa, net, tartışmasız TEK bir doğru cevap olmalı (birden fazla '
      'olası cevabı parantez içinde sıralama, seçenek sunma). Türkçe '
      'karakterleri (ş, ğ, ı, ü, ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve '
      'eksiksiz kullan; harfleri ASCII karşılıklarına (s, g, i, u, o, c) '
      'çevirme.\n\nKonu: ${lesson.topicPrompt}',
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

    final quizJson = await _generateJson(
      client,
      apiKey,
      'Aşağıdaki konudan, her biri 4 şıklı (A, B, C, D) ve tek doğru '
      'cevabı olan TAM OLARAK 10 tane çoktan seçmeli soru oluştur. '
      'correctIndex, doğru şıkkın options listesindeki 0 tabanlı '
      'indeksi olmalı. Her soru için kısa (1-2 cümlelik) bir explanation '
      'yaz. Bir sorunun 4 şıkkı birbirinden kesinlikle farklı olmalı, '
      'aynı şık iki kez tekrar etmemeli. Türkçe karakterleri (ş, ğ, ı, ü, '
      'ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve eksiksiz kullan; harfleri ASCII '
      'karşılıklarına (s, g, i, u, o, c) çevirme.'
      '\n\nKonu: ${lesson.topicPrompt}',
      {
        'type': 'OBJECT',
        'properties': {
          'questions': {
            'type': 'ARRAY',
            'minItems': 10,
            'maxItems': 10,
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

    results.add({
      'title': lesson.title,
      'color': lesson.color,
      'summaryText': summary.trim(),
      'flashcards': cardsJson['cards'],
      'quizQuestions': quizJson['questions'],
    });
  }

  client.close();

  final outFile = File('tool/sample_lessons_output.json');
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(results),
  );
  stderr.writeln('Yazıldı: ${outFile.path}');
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

Future<String> _generateText(
  HttpClient client,
  String apiKey,
  String prompt,
) async {
  final data = await _post(client, apiKey, {
    'contents': [
      {
        'parts': [
          {'text': prompt},
        ],
      },
    ],
  });
  return _extractText(data);
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
