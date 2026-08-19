// One-off tool: generates the Faz 1 pilot content for the "Ders Yolu"
// (skill path) feature via Gemini and writes it to
// tool/curriculum_path_output.json for review, mirroring
// tool/generate_sample_lessons.dart's approach.
//
// Only Ünite 1 (8 nodes) gets real content in this pass — the other
// units are written with just a title and empty node list, so they show
// as locked/"Yakında" on the path screen until Phase 2 fills them in.
//
// Plain Dart (no Flutter engine needed) so it can run headlessly here.
// Reads GEMINI_API_KEY straight out of .env. Reuses the exact
// Flashcard/QuizQuestion wire format (both plain-Dart models, no Flutter
// imports) so the output slots into CurriculumNode.fromJson unchanged.
//
// Run with: dart run tool/generate_curriculum_path.dart

import 'dart:convert';
import 'dart:io';

import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

const model = 'gemini-flash-lite-latest';
const subjectKey = 'tyt_biyoloji';
const subjectTitle = 'TYT Biyoloji';

const unit1Title = 'Canlıların Ortak Özellikleri ve Temel Bileşenler';

const unit1Nodes = [
  (
    id: 'node1',
    title: 'Canlıların Ortak Özellikleri',
    detail:
        'hücresel yapı, beslenme, solunum, boşaltım, üreme, uyarılara tepki, '
        'homeostazi ve canlıların organizasyon basamakları (hücre, doku, '
        'organ, sistem, organizma)',
    estimatedMinutes: 15,
  ),
  (
    id: 'node2',
    title: 'İnorganik Bileşikler',
    detail: 'su ve minerallerin canlılardaki önemi, işlevleri ve özellikleri',
    estimatedMinutes: 12,
  ),
  (
    id: 'node3',
    title: 'Karbonhidratlar',
    detail:
        'monosakkarit, disakkarit, polisakkarit yapıları ve canlılardaki '
        'işlevleri',
    estimatedMinutes: 12,
  ),
  (
    id: 'node4',
    title: 'Lipitler (Yağlar)',
    detail: 'yağların yapısı, çeşitleri ve canlılardaki işlevleri',
    estimatedMinutes: 12,
  ),
  (
    id: 'node5',
    title: 'Proteinler',
    detail:
        'amino asit yapısı, peptit bağı, proteinlerin yapısı ve '
        'işlevleri',
    estimatedMinutes: 12,
  ),
  (
    id: 'node6',
    title: 'Enzimler',
    detail:
        'enzimlerin yapısı, çalışma prensibi, enzim-substrat ilişkisi ve '
        'enzim aktivitesini etkileyen faktörler (sıcaklık, pH, '
        'konsantrasyon)',
    estimatedMinutes: 15,
  ),
  (
    id: 'node7',
    title: 'Vitaminler',
    detail:
        'yağda ve suda çözünen vitaminlerin özellikleri ve canlılardaki '
        'önemi',
    estimatedMinutes: 12,
  ),
  (
    id: 'node8',
    title: 'Nükleik Asitler',
    detail: "DNA ve RNA'nın temel yapısı, nükleotit yapısı ve görevleri",
    estimatedMinutes: 15,
  ),
];

/// Other units, seeded with just a title (no nodes yet) so they render
/// locked/"Yakında" — content comes in Phase 2.
const otherUnitTitles = [
  'Hücre ve Organelleri',
  'Hücre Zarından Madde Geçişi',
  'Canlıların Sınıflandırılması',
  'Mitoz ve Eşeysiz Üreme',
  'Mayoz ve Eşeyli Üreme',
  'Kalıtımın Genel İlkeleri',
  'Ekosistem Ekolojisi',
  'Güncel Çevre Sorunları',
];

Future<void> main() async {
  final apiKey = _readEnvKey('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY bulunamadı (.env).');
    exit(1);
  }

  final client = HttpClient();
  final nodes = <Map<String, dynamic>>[];

  for (var i = 0; i < unit1Nodes.length; i++) {
    final node = unit1Nodes[i];
    stderr.writeln('=== ${node.title} ===');
    final topic =
        'TYT Biyoloji sınavına hazırlanan bir öğrenci için "${node.title}" '
        'konusu: ${node.detail}.';

    stderr.writeln('  -> Hafıza kartları üretiliyor...');
    final flashcards = await _generateFlashcards(client, apiKey, topic);

    stderr.writeln('  -> Çoktan seçmeli sorular üretiliyor...');
    final multipleChoice = await _generateMultipleChoice(client, apiKey, topic);

    stderr.writeln('  -> Boşluk doldurma soruları üretiliyor...');
    final fillBlank = await _generateFillBlank(client, apiKey, topic);

    stderr.writeln('  -> Doğru/Yanlış soruları üretiliyor...');
    final trueFalse = await _generateTrueFalse(client, apiKey, topic);

    nodes.add({
      'id': node.id,
      'order': i + 1,
      'title': node.title,
      'estimatedMinutes': node.estimatedMinutes,
      'flashcards': flashcards.map((c) => c.toJson()).toList(),
      'multipleChoice': multipleChoice.map((q) => q.toJson()).toList(),
      'fillBlank': fillBlank.map((q) => q.toJson()).toList(),
      'trueFalse': trueFalse.map((q) => q.toJson()).toList(),
    });
  }

  client.close();

  final units = <Map<String, dynamic>>[
    {'id': 'unit1', 'order': 1, 'title': unit1Title, 'nodes': nodes},
    for (var i = 0; i < otherUnitTitles.length; i++)
      {
        'id': 'unit${i + 2}',
        'order': i + 2,
        'title': otherUnitTitles[i],
        'nodes': const [],
      },
  ];

  final output = {
    'subjectKey': subjectKey,
    'title': subjectTitle,
    'units': units,
  };

  final outFile = File('tool/curriculum_path_output.json');
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stderr.writeln('Yazıldı: ${outFile.path}');
}

Future<List<Flashcard>> _generateFlashcards(
  HttpClient client,
  String apiKey,
  String topic,
) async {
  final json = await _generateJson(
    client,
    apiKey,
    'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde, '
    'öğrenmeye yönelik TAM OLARAK 10 tane soru-cevap kartı oluştur. '
    'Cevaplar kısa, net, tartışmasız TEK bir doğru cevap olmalı. Türkçe '
    'karakterleri (ş, ğ, ı, ü, ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve eksiksiz '
    'kullan; harfleri ASCII karşılıklarına çevirme.\n\nKonu: $topic',
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
  final rawCards = json['cards'] as List;
  return rawCards
      .whereType<Map<String, dynamic>>()
      .map(Flashcard.fromJson)
      .where((c) => c.question.isNotEmpty && c.answer.isNotEmpty)
      .toList();
}

Future<List<QuizQuestion>> _generateMultipleChoice(
  HttpClient client,
  String apiKey,
  String topic,
) async {
  final json = await _generateJson(
    client,
    apiKey,
    'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde, her '
    'biri 4 şıklı (A, B, C, D) ve tek doğru cevabı olan TAM OLARAK 10 '
    'tane çoktan seçmeli soru oluştur. correctIndex, doğru şıkkın options '
    'listesindeki 0 tabanlı indeksi olmalı. Bir sorunun 4 şıkkı '
    'birbirinden kesinlikle farklı olmalı. Her soru için kısa (1-2 '
    'cümlelik) bir explanation yaz. Türkçe karakterleri (ş, ğ, ı, ü, ö, '
    'ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve eksiksiz kullan; harfleri ASCII '
    'karşılıklarına çevirme.\n\nKonu: $topic',
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
  final rawQuestions = json['questions'] as List;
  return rawQuestions
      .whereType<Map<String, dynamic>>()
      .map(QuizQuestion.fromJson)
      .where(
        (q) =>
            q.question.isNotEmpty &&
            q.options.length == 4 &&
            q.correctIndex >= 0 &&
            q.correctIndex < 4,
      )
      .toList();
}

/// Gemini's structured-JSON decoder occasionally emits a corrupted
/// (U+FFFD-containing) or ASCII-folded "answer" for fill-blank items —
/// seen in practice with words like "üreme"/"uyarılara" coming back as
/// "ureme"/mangled bytes. Since the exact answer text is graded
/// character-for-character, this retries the whole batch (fresh model
/// sample) whenever any answer looks corrupted, instead of shipping bad
/// answer keys.
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

Future<List<QuizQuestion>> _generateTrueFalse(
  HttpClient client,
  String apiKey,
  String topic,
) async {
  final json = await _generateJson(
    client,
    apiKey,
    'Aşağıdaki konudan, TYT (Temel Yeterlilik Testi) seviyesinde TAM '
    'OLARAK 5 tane doğru/yanlış ifadesi oluştur. Her ifade konudaki bir '
    'bilgiyi doğru ya da kasıtlı olarak yanlış şekilde sunmalı; isTrue '
    'alanı ifadenin doğru olup olmadığını belirtmeli. Her ifade için '
    'kısa (1-2 cümlelik) bir explanation yaz. Türkçe karakterleri (ş, ğ, '
    'ı, ü, ö, ç, İ, Ş, Ğ, Ü, Ö, Ç) doğru ve eksiksiz kullan; harfleri '
    'ASCII karşılıklarına çevirme.\n\nKonu: $topic',
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
      .where((q) => q.question.isNotEmpty)
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
