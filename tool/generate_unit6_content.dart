// One-off tool: generates the Ünite 6 ("Mayoz ve Eşeyli Üreme") content
// for the "Ders Yolu" (skill path) feature via Gemini and merges it into
// tool/curriculum_path_output.json for review — same offline generate ->
// review JSON -> admin seed pattern, batching, and anti-duplication
// logic as tool/generate_unit5_content.dart.
//
// Node ids in this file stay unit-local ("node1".."node4") on purpose:
// CurriculumUnit.fromJson (lib/models/curriculum_path.dart) prefixes
// every node id with its owning unit's Firestore doc id at load time
// (e.g. "unit6_node1"), so cross-unit id collisions can't happen.
//
// Writes content ALREADY split into the part structure (5x10 Test, 5x10
// Kart Seti, 2x10 Doğru/Yanlış, 2x10 Boşluk Doldurma) as it generates
// each batch — no separate migrate_curriculum_parts.dart pass needed.
//
// Plain Dart (no Flutter engine needed) so it can run headlessly here.
// Reads GEMINI_API_KEY straight out of .env. Reuses the exact
// Flashcard/QuizQuestion wire format (both plain-Dart models, no Flutter
// imports) so the output slots into CurriculumNode.fromJson unchanged.
//
// Run with: dart run tool/generate_unit6_content.dart

import 'dart:convert';
import 'dart:io';

import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

const model = 'gemini-flash-lite-latest';
const outputPath = 'tool/curriculum_path_output.json';

const unitId = 'unit6';
const batchSize = 10;

const maxRetryBatchesPerType = 6;
const similarityThreshold = 0.6;

const nodes = [
  (
    id: 'node1',
    title: 'Mayoz I Evreleri',
    estimatedMinutes: 22,
    scope: '''
- Mayoz, birbirini takip eden Mayoz I ve Mayoz II aşamalarından oluşur, sonuçta genetik çeşitliliğe sahip haploit üreme hücreleri oluşur.
- Profaz I: mayozun en uzun ve en karmaşık evresi. Homolog kromozomlar yan yana gelip tetrat (4 kromatitli yapı) oluşturur. Sinapsis: homolog kromozomların geçici olarak fiziksel birleşmesi. Krossing over (parça değişimi): kardeş olmayan kromatidler arasında kiazma denilen bölgelerde genetik madde alışverişi olur.
- Önemli not: tetrat sayısı hücrenin haploit kromozom sayısına eşittir, kromatit sayısı kromozom sayısının iki katıdır (örnek: 2n=4 durumunda tetrat/kromatit ilişkisi).
- Metafaz I, Anafaz I (homolog kromozomlar zıt kutuplara ayrılır - kardeş kromatidler değil), Telofaz I kısaca değinilir.
- Sitokinez I: hayvan hücresinde boğumlanma, bitki hücresinde orta lamel oluşumuyla gerçekleşir, sonuçta genetik olarak farklı 2 haploit hücre oluşur.
''',
  ),
  (
    id: 'node2',
    title: 'Mayoz II Evreleri',
    estimatedMinutes: 20,
    scope: '''
- Mayoz I ile Mayoz II arasında interfaz yoktur ve DNA eşlenmez (kritik nokta).
- Profaz II: Profaz I'e göre kısa sürer; çekirdek zarı ve çekirdekçik (varsa) dağılır, iğ iplikleri oluşur, kromozomlar belirginleşir.
- Metafaz II, Anafaz II (bu kez kardeş kromatidler ayrılır, mitozdaki anafaza benzer), Telofaz II.
- Sitokinez II: hayvan hücresinde boğumlanma, bitki hücresinde hücre plağı oluşumu; sonuçta birbirinden ve ana hücreden genetik olarak farklı 4 haploit kardeş hücre oluşur (örnek: 2n=4'ten n=2 kromozomlu 4 hücre).
''',
  ),
  (
    id: 'node3',
    title: 'Mitoz ve Mayoz Karşılaştırması',
    estimatedMinutes: 20,
    scope: '''
- Hücre sayısı: mitoz 2 yeni hücre, mayoz 4 yeni hücre üretir.
- Kromozom sayısı: mitozda ana hücreyle aynı kalır, mayozda yarıya iner.
- Krossing over: mayozun Profaz I'inde görülür, mitozun profazında görülmez.
- Zamanlama: mitoz zigot evresinden itibaren yaşam boyu sürer, mayoz canlının üreme olgunluğu döneminde gerçekleşir.
- Anafaz farkı: mitozda kardeş kromatidler ayrılır; mayozda Anafaz I'de homolog kromozomlar, Anafaz II'de kardeş kromatidler ayrılır.
- DNA içeriği: mitoz sonrası hücrelerde DNA ana hücreyle aynı, mayoz sonrası hücrelerde DNA miktarı yarıya iner.
- Hücre döngüsü basamakları: mitoz interfaz+mitoz+sitokinezden oluşur, mayoz ara sitokinezli iki tam bölünmeden oluşur.
''',
  ),
  (
    id: 'node4',
    title: 'Eşeyli Üreme',
    estimatedMinutes: 20,
    scope: '''
- Tanım: farklı cinsiyetteki aynı tür iki canlının iki haploit gametinin döllenmesiyle yeni yavru oluşması.
- Mayoz bölünme ve döllenme bu sistemin temelidir; dişi gamete yumurta, erkek gamete sperm denir; döllenmiş yumurtaya zigot denir (diploit hücre).
- Gametler şansa bağlı bir araya geldiği için tür içi genetik çeşitlilik oluşur, yavrular hem anne hem babadan genetik malzeme taşır.
- Önemli notlar: prokaryotlarda mitoz, mayoz ve döllenme gerçekleşmez; bitkilerde tohum oluşumu eşeyli üremenin kanıtıdır; eşeyli üreme adaptasyon yeteneğini artırır.
- Örnekler: şeftali/erik/orkide gibi çiçekli bitkilerde tek çiçekte hem erkek hem dişi organ bulunabilir; solucan/güve/istiridye gibi hermafrodit canlılar gametlerini farklı zamanlarda üretir, böylece kendi kendini döllemek yerine başka bireylerle çiftleşip genetik çeşitliliği artırır.
- Eşeysiz-eşeyli üreme karşılaştırma tablosu: genetik çeşitlilik (eşeysizde yok/mutasyon hariç, eşeylide var), ebeveyn sayısı (eşeysizde tek atadan, eşeylide iki genetik ebeveynden), bölünme temeli (eşeysiz mitoz, eşeyli mayoz), döllenme (eşeysizde yok, eşeylide var), çevreye uyum olasılığı (eşeysizde düşük, eşeylide yüksek).
''',
  ),
];

Future<void> main() async {
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
        'TYT Biyoloji sınavına hazırlanan bir öğrenci için "Mayoz ve '
        'Eşeyli Üreme" ünitesinin "${node.title}" alt konusu. Sorular '
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
      .where((c) => c.question.isNotEmpty && c.answer.isNotEmpty)
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
        .where((q) => q.question.isNotEmpty && q.answerText.isNotEmpty)
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
