import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:ogrenme_asistani/models/chat_message.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

class GeminiException implements Exception {
  GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiService {
  GeminiService({this.model = 'gemini-flash-lite-latest'});

  final String model;

  Future<String> sendMessage(String prompt, {String? systemInstruction}) {
    return _generateText(
      _singleTurn(prompt),
      systemInstruction: systemInstruction,
    );
  }

  /// Streams the reply as it's generated. Each emitted value is an
  /// incremental text chunk (not the full text so far). [history] is the
  /// full conversation so far (oldest first, ending with the latest user
  /// message) so Gemini has context from earlier turns, not just the
  /// newest message.
  Stream<String> sendMessageStream(
    List<ChatMessage> history, {
    String? systemInstruction,
  }) {
    return _generateTextStream(
      _historyToContents(history),
      systemInstruction: systemInstruction,
    );
  }

  List<Map<String, dynamic>> _singleTurn(String text) => [
    {
      'parts': [
        {'text': text},
      ],
    },
  ];

  /// Converts stored chat messages into Gemini's `contents` turn format.
  /// Error placeholders (e.g. "couldn't respond" messages shown in the
  /// UI) are dropped since they were never real model output.
  List<Map<String, dynamic>> _historyToContents(List<ChatMessage> history) {
    return history
        .where((m) => !m.isError)
        .map(
          (m) => {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          },
        )
        .toList();
  }

  /// Suggests a short (max ~4 word), meaningful chat title based on the
  /// user's first message, e.g. "Fotosentez konusunu tekrar anlat" ->
  /// "Fotosentez Tekrarı".
  Future<String> generateChatTitle(String firstMessage) async {
    final prompt =
        'Aşağıdaki mesajla başlayan bir sohbet için en fazla 4 kelimelik, '
        'kısa ve anlamlı bir başlık öner. Sadece başlığı düz metin olarak '
        'yaz; tırnak işareti, noktalama veya açıklama ekleme.\n\n'
        'Mesaj:\n$firstMessage';
    final text = await _generateText(_singleTurn(prompt));
    return text.trim().replaceAll(RegExp(r'^["\x27]+|["\x27]+$'), '');
  }

  Future<({String title, List<Flashcard> cards})> generateFlashcards(
    String sourceText, {
    int cardCount = 10,
  }) async {
    final prompt =
        'Aşağıdaki ders notundan/metinden öğrenmeye yönelik TAM OLARAK '
        '$cardCount tane soru-cevap kartı oluştur ve konuyu özetleyen kısa '
        '(en fazla 4 kelime) bir başlık ver. Ne eksik ne fazla, tam olarak '
        '$cardCount kart üretmelisin. Sorular metindeki önemli kavramları '
        'test etmeli, cevaplar kısa ve net olmalı.\n\nMetin:\n$sourceText';

    final text = await _generateText(
      _singleTurn(prompt),
      generationConfig: {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'cards': {
              'type': 'ARRAY',
              'minItems': cardCount,
              'maxItems': cardCount,
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
          'required': ['title', 'cards'],
        },
      },
    );

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] Kart JSON\'u ayrıştırılamadı: $e');
      debugPrint('[GeminiService] Ham metin: $text');
      throw GeminiException('Kartlar oluşturulurken yanıt okunamadı.');
    }

    final title = (parsed['title'] as String? ?? '').trim();
    final rawCards = parsed['cards'] as List? ?? [];
    final cards = rawCards
        .whereType<Map<String, dynamic>>()
        .map(Flashcard.fromJson)
        .where((card) => card.question.isNotEmpty && card.answer.isNotEmpty)
        .toList();

    if (cards.isEmpty) {
      throw GeminiException('Kart oluşturulamadı.');
    }

    return (title: title.isEmpty ? 'Kart Seti' : title, cards: cards);
  }

  Future<({String title, List<QuizQuestion> questions})> generateQuiz(
    String sourceText,
  ) async {
    final prompt =
        'Aşağıdaki ders notundan/metinden öğrenmeye yönelik, her biri 4 '
        'şıklı (A, B, C, D) ve tek doğru cevabı olan 5 ile 20 arasında (mümkünse '
        'en az 10 tane, metnin uzunluğuna göre daha fazla olabilir) çoktan '
        'seçmeli soru oluştur ve konuyu özetleyen kısa (en fazla 4 kelime) bir '
        'başlık ver. correctIndex, doğru şıkkın options listesindeki 0 tabanlı '
        'indeksi olmalı. Her soru için ayrıca kısa (1-2 cümlelik) bir '
        'explanation yaz; bu açıklama doğru cevabın neden doğru olduğunu '
        'özetlemeli.\n\nMetin:\n$sourceText';

    final text = await _generateText(
      _singleTurn(prompt),
      generationConfig: {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'questions': {
              'type': 'ARRAY',
              'minItems': 5,
              'maxItems': 20,
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
          'required': ['title', 'questions'],
        },
      },
    );

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] Test JSON\'u ayrıştırılamadı: $e');
      debugPrint('[GeminiService] Ham metin: $text');
      throw GeminiException('Test oluşturulurken yanıt okunamadı.');
    }

    final title = (parsed['title'] as String? ?? '').trim();
    final rawQuestions = parsed['questions'] as List? ?? [];
    final questions = rawQuestions
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

    if (questions.isEmpty) {
      throw GeminiException('Test oluşturulamadı.');
    }

    return (title: title.isEmpty ? 'Test Seti' : title, questions: questions);
  }

  Future<String> _generateText(
    List<Map<String, dynamic>> contents, {
    Map<String, dynamic>? generationConfig,
    String? systemInstruction,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[GeminiService] GEMINI_API_KEY bulunamadı veya boş.');
      throw GeminiException('API anahtarı bulunamadı.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': contents,
              if (systemInstruction != null)
                'systemInstruction': {
                  'parts': [{'text': systemInstruction}],
                },
              'generationConfig': ?generationConfig,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('[GeminiService] İstek gönderilemedi: $e');
      throw GeminiException('Sunucuya bağlanılamadı.');
    }

    if (response.statusCode != 200) {
      debugPrint(
        '[GeminiService] HTTP ${response.statusCode} yanıtı: ${response.body}',
      );
      throw GeminiException(
        'Sunucudan hata yanıtı alındı (${response.statusCode}).',
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] Yanıt JSON olarak ayrıştırılamadı: $e');
      debugPrint('[GeminiService] Ham yanıt: ${response.body}');
      throw GeminiException('Yanıt okunamadı.');
    }

    try {
      final candidates = data['candidates'] as List;
      final parts = candidates[0]['content']['parts'] as List;
      final text = parts
          .map((part) => (part as Map<String, dynamic>)['text'])
          .whereType<String>()
          .join();
      if (text.isEmpty) {
        throw GeminiException('Yanıt boş döndü.');
      }
      return text.trim();
    } catch (e) {
      debugPrint('[GeminiService] Yanıt beklenen formatta değil: $e');
      debugPrint('[GeminiService] Alınan veri: $data');
      if (e is GeminiException) rethrow;
      throw GeminiException('Yanıt beklenen formatta değil.');
    }
  }

  Stream<String> _generateTextStream(
    List<Map<String, dynamic>> contents, {
    String? systemInstruction,
  }) async* {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[GeminiService] GEMINI_API_KEY bulunamadı veya boş.');
      throw GeminiException('API anahtarı bulunamadı.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse',
    );

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-goog-api-key'] = apiKey
      ..body = jsonEncode({
        'contents': contents,
        if (systemInstruction != null)
          'systemInstruction': {
            'parts': [{'text': systemInstruction}],
          },
      });

    http.StreamedResponse response;
    try {
      response = await http.Client()
          .send(request)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('[GeminiService] Streaming isteği gönderilemedi: $e');
      throw GeminiException('Sunucuya bağlanılamadı.');
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      debugPrint('[GeminiService] HTTP ${response.statusCode} yanıtı: $body');
      throw GeminiException(
        'Sunucudan hata yanıtı alındı (${response.statusCode}).',
      );
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final jsonStr = line.substring(6).trim();
      if (jsonStr.isEmpty) continue;

      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) continue;
        final parts =
            (candidates[0] as Map<String, dynamic>)['content']?['parts']
                as List?;
        if (parts == null) continue;
        final text = parts
            .map((part) => (part as Map<String, dynamic>)['text'])
            .whereType<String>()
            .join();
        if (text.isNotEmpty) yield text;
      } catch (e) {
        debugPrint('[GeminiService] Stream parçası ayrıştırılamadı: $e');
      }
    }
  }
}
