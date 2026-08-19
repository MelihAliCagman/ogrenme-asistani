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
  /// newest message. When [imageBytes]/[imageMimeType] are given, they're
  /// attached to the last (newest) turn in [history] — used for "solve
  /// this photographed question" messages.
  Stream<String> sendMessageStream(
    List<ChatMessage> history, {
    String? systemInstruction,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) {
    final contents = _historyToContents(history);
    if (imageBytes != null && imageMimeType != null && contents.isNotEmpty) {
      final last = contents.last;
      final parts = <Map<String, dynamic>>[
        ...(last['parts'] as List).cast<Map<String, dynamic>>(),
        <String, dynamic>{
          'inlineData': <String, dynamic>{
            'mimeType': imageMimeType,
            'data': base64Encode(imageBytes),
          },
        },
      ];
      contents[contents.length - 1] = <String, dynamic>{
        ...last,
        'parts': parts,
      };
    }
    return _generateTextStream(contents, systemInstruction: systemInstruction);
  }

  List<Map<String, dynamic>> _singleTurn(String text) => [
    {
      'parts': [
        {'text': text},
      ],
    },
  ];

  /// Builds a single-turn `contents` payload with an optional inline file
  /// (e.g. a PDF) attached alongside the prompt text, using Gemini's
  /// multimodal `inlineData` part.
  List<Map<String, dynamic>> _singleTurnWithFile(
    String promptText, {
    Uint8List? fileBytes,
    String? fileMimeType,
  }) {
    final parts = <Map<String, dynamic>>[
      {'text': promptText},
    ];
    if (fileBytes != null && fileMimeType != null) {
      parts.add({
        'inlineData': {
          'mimeType': fileMimeType,
          'data': base64Encode(fileBytes),
        },
      });
    }
    return [
      {'parts': parts},
    ];
  }

  /// Converts stored chat messages into Gemini's `contents` turn format.
  /// Error placeholders (e.g. "couldn't respond" messages shown in the
  /// UI) are dropped since they were never real model output.
  List<Map<String, dynamic>> _historyToContents(List<ChatMessage> history) {
    return history
        .where((m) => !m.isError)
        .map<Map<String, dynamic>>(
          (m) => <String, dynamic>{
            'role': m.isUser ? 'user' : 'model',
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{'text': m.text},
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

  /// Combines the base [instructions] with the source text and/or an
  /// attached file. When a file is attached, [sourceText] (if non-empty)
  /// is treated as an extra instruction from the user (e.g. "3. bölümden
  /// soru çıkmasın") rather than the content itself.
  String _buildPrompt(
    String instructions, {
    String? sourceText,
    required bool hasFile,
  }) {
    final extra = sourceText?.trim() ?? '';
    if (hasFile) {
      return extra.isEmpty
          ? '$instructions Kaynak, ekli dosyadır.'
          : '$instructions Kaynak, ekli dosyadır. Ayrıca kullanıcının şu ek '
                'talimatına uy: $extra';
    }
    return '$instructions\n\nMetin:\n$extra';
  }

  Future<({String title, List<Flashcard> cards})> generateFlashcards({
    String? sourceText,
    Uint8List? fileBytes,
    String? fileMimeType,
    int cardCount = 10,
    String? difficultyInstruction,
  }) async {
    final instructions =
        'Aşağıdaki ders notundan/metinden öğrenmeye yönelik TAM OLARAK '
        '$cardCount tane soru-cevap kartı oluştur ve konuyu özetleyen kısa '
        '(en fazla 4 kelime) bir başlık ver. Ne eksik ne fazla, tam olarak '
        '$cardCount kart üretmelisin. Sorular metindeki önemli kavramları '
        'test etmeli, cevaplar kısa ve net olmalı.'
        '${difficultyInstruction == null ? '' : ' $difficultyInstruction'}';
    final prompt = _buildPrompt(
      instructions,
      sourceText: sourceText,
      hasFile: fileBytes != null,
    );

    final text = await _generateText(
      _singleTurnWithFile(
        prompt,
        fileBytes: fileBytes,
        fileMimeType: fileMimeType,
      ),
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

  Future<({String title, List<QuizQuestion> questions})> generateQuiz({
    String? sourceText,
    Uint8List? fileBytes,
    String? fileMimeType,
    int questionCount = 10,
    String? difficultyInstruction,
  }) async {
    final instructions =
        'Aşağıdaki ders notundan/metinden öğrenmeye yönelik TAM OLARAK '
        '$questionCount tane, her biri 4 şıklı (A, B, C, D) ve tek doğru '
        'cevabı olan çoktan seçmeli soru oluştur ve konuyu özetleyen kısa '
        '(en fazla 4 kelime) bir başlık ver. Ne eksik ne fazla, tam olarak '
        '$questionCount soru üretmelisin. correctIndex, doğru şıkkın options '
        'listesindeki 0 tabanlı indeksi olmalı. Her soru için ayrıca kısa '
        '(1-2 cümlelik) bir explanation yaz; bu açıklama doğru cevabın neden '
        'doğru olduğunu özetlemeli.'
        '${difficultyInstruction == null ? '' : ' $difficultyInstruction'}';
    final prompt = _buildPrompt(
      instructions,
      sourceText: sourceText,
      hasFile: fileBytes != null,
    );

    final text = await _generateText(
      _singleTurnWithFile(
        prompt,
        fileBytes: fileBytes,
        fileMimeType: fileMimeType,
      ),
      generationConfig: {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'questions': {
              'type': 'ARRAY',
              'minItems': questionCount,
              'maxItems': questionCount,
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

  Future<({String title, List<QuizQuestion> questions})>
  generateFillBlankQuestions({
    String? sourceText,
    Uint8List? fileBytes,
    String? fileMimeType,
    int questionCount = 10,
    String? difficultyInstruction,
  }) async {
    final instructions =
        'Aşağıdaki ders notundan/metinden öğrenmeye yönelik TAM OLARAK '
        '$questionCount tane boşluk doldurma sorusu oluştur ve konuyu '
        'özetleyen kısa (en fazla 4 kelime) bir başlık ver. Ne eksik ne '
        'fazla, tam olarak $questionCount soru üretmelisin. Her sorunun '
        'metninde boşluk bırakılacak yere "____" (alt çizgi) koy, answer '
        'alanına o boşluğa gelmesi gereken kısa (tek kelime veya kısa bir '
        'ifade) doğru cevabı yaz. answer alanını normal Türkçe yazım '
        'kurallarına uygun şekilde yaz; Türkçe özel karakterleri (ç, ğ, ı, '
        'ö, ş, ü ve büyük halleri Ç, Ğ, İ, Ö, Ş, Ü) gerektiği yerde MUTLAKA '
        'kullan, ASCII karşılıklarına çevirme (doğru örnek: "üreme", '
        'yanlış örnek: "ureme"). Her soru için ayrıca kısa (1-2 cümlelik) '
        'bir explanation yaz.'
        '${difficultyInstruction == null ? '' : ' $difficultyInstruction'}';
    final prompt = _buildPrompt(
      instructions,
      sourceText: sourceText,
      hasFile: fileBytes != null,
    );

    final text = await _generateText(
      _singleTurnWithFile(
        prompt,
        fileBytes: fileBytes,
        fileMimeType: fileMimeType,
      ),
      generationConfig: {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'questions': {
              'type': 'ARRAY',
              'minItems': questionCount,
              'maxItems': questionCount,
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
          'required': ['title', 'questions'],
        },
      },
    );

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] Boşluk doldurma JSON\'u ayrıştırılamadı: $e');
      debugPrint('[GeminiService] Ham metin: $text');
      throw GeminiException('Sorular oluşturulurken yanıt okunamadı.');
    }

    final title = (parsed['title'] as String? ?? '').trim();
    final rawQuestions = parsed['questions'] as List? ?? [];
    final questions = rawQuestions
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => QuizQuestion(
            question: (json['question'] as String? ?? '').trim(),
            options: [(json['answer'] as String? ?? '').trim()],
            correctIndex: 0,
            explanation: (json['explanation'] as String? ?? '').trim(),
            type: QuestionType.fillBlank,
          ),
        )
        .where(
          (q) =>
              q.question.isNotEmpty &&
              q.answerText.isNotEmpty &&
              !q.answerText.contains('�'),
        )
        .toList();

    if (questions.isEmpty) {
      throw GeminiException('Sorular oluşturulamadı.');
    }

    return (
      title: title.isEmpty ? 'Boşluk Doldurma Seti' : title,
      questions: questions,
    );
  }

  Future<({String title, List<QuizQuestion> questions})>
  generateTrueFalseQuestions({
    String? sourceText,
    Uint8List? fileBytes,
    String? fileMimeType,
    int questionCount = 10,
    String? difficultyInstruction,
  }) async {
    final instructions =
        'Aşağıdaki ders notundan/metinden öğrenmeye yönelik TAM OLARAK '
        '$questionCount tane doğru/yanlış sorusu (ifadesi) oluştur ve '
        'konuyu özetleyen kısa (en fazla 4 kelime) bir başlık ver. Ne '
        'eksik ne fazla, tam olarak $questionCount ifade üretmelisin. Her '
        'ifade metindeki bir bilgiyi doğru ya da kasıtlı olarak yanlış '
        'şekilde sunmalı; isTrue alanı ifadenin doğru olup olmadığını '
        'belirtmeli. Her ifade için ayrıca kısa (1-2 cümlelik) bir '
        'explanation yaz; bu açıklama ifadenin neden doğru/yanlış '
        'olduğunu özetlemeli.'
        '${difficultyInstruction == null ? '' : ' $difficultyInstruction'}';
    final prompt = _buildPrompt(
      instructions,
      sourceText: sourceText,
      hasFile: fileBytes != null,
    );

    final text = await _generateText(
      _singleTurnWithFile(
        prompt,
        fileBytes: fileBytes,
        fileMimeType: fileMimeType,
      ),
      generationConfig: {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'questions': {
              'type': 'ARRAY',
              'minItems': questionCount,
              'maxItems': questionCount,
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
          'required': ['title', 'questions'],
        },
      },
    );

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiService] Doğru/Yanlış JSON\'u ayrıştırılamadı: $e');
      debugPrint('[GeminiService] Ham metin: $text');
      throw GeminiException('Sorular oluşturulurken yanıt okunamadı.');
    }

    final title = (parsed['title'] as String? ?? '').trim();
    final rawQuestions = parsed['questions'] as List? ?? [];
    final questions = rawQuestions
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => QuizQuestion(
            question: (json['statement'] as String? ?? '').trim(),
            options: const ['Doğru', 'Yanlış'],
            correctIndex: (json['isTrue'] as bool? ?? true) ? 0 : 1,
            explanation: (json['explanation'] as String? ?? '').trim(),
            type: QuestionType.trueFalse,
          ),
        )
        .where((q) => q.question.isNotEmpty)
        .toList();

    if (questions.isEmpty) {
      throw GeminiException('Sorular oluşturulamadı.');
    }

    return (
      title: title.isEmpty ? 'Doğru/Yanlış Seti' : title,
      questions: questions,
    );
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
