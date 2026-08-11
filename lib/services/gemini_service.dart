import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:ogrenme_asistani/models/flashcard.dart';

class GeminiException implements Exception {
  GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiService {
  GeminiService({this.model = 'gemini-flash-lite-latest'});

  final String model;

  Future<String> sendMessage(String prompt) {
    return _generateText(prompt);
  }

  Future<({String title, List<Flashcard> cards})> generateFlashcards(
    String sourceText,
  ) async {
    final prompt =
        'Aşağıdaki ders notundan/metinden öğrenmeye yönelik 5 ile 10 arasında '
        'soru-cevap kartı oluştur ve konuyu özetleyen kısa (en fazla 4 kelime) '
        'bir başlık ver. Sorular metindeki önemli kavramları test etmeli, '
        'cevaplar kısa ve net olmalı.\n\nMetin:\n$sourceText';

    final text = await _generateText(
      prompt,
      generationConfig: {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'cards': {
              'type': 'ARRAY',
              'minItems': 5,
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

  Future<String> _generateText(
    String prompt, {
    Map<String, dynamic>? generationConfig,
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
              'contents': [
                {
                  'parts': [{'text': prompt}],
                },
              ],
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
}
