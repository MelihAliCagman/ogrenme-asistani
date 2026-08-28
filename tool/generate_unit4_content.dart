// One-off tool: generates the Ünite 4 ("Canlıların Sınıflandırılması")
// content for the "Ders Yolu" (skill path) feature via Gemini and merges
// it into tool/curriculum_path_output.json for review — same
// offline generate -> review JSON -> admin seed pattern, batching, and
// anti-duplication logic as tool/generate_unit2_content.dart /
// tool/generate_unit3_content.dart.
//
// Node ids in this file stay unit-local ("node1".."node7") on purpose:
// CurriculumUnit.fromJson (lib/models/curriculum_path.dart) prefixes
// every node id with its owning unit's Firestore doc id at load time
// (e.g. "unit4_node1"), so cross-unit id collisions can't happen.
//
// This script writes FLAT arrays (50/50/20/20 per node) — same as the
// unit2/unit3 scripts. Run tool/migrate_curriculum_parts.dart afterward
// to reshape them into the 5x10/5x10/2x10/2x10 "part" structure before
// seeding.
//
// Plain Dart (no Flutter engine needed) so it can run headlessly here.
// Reads GEMINI_API_KEY straight out of .env. Reuses the exact
// Flashcard/QuizQuestion wire format (both plain-Dart models, no Flutter
// imports) so the output slots into CurriculumNode.fromJson unchanged.
//
// Run with: dart run tool/generate_unit4_content.dart

import 'dart:convert';
import 'dart:io';

import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

const model = 'gemini-flash-lite-latest';
const outputPath = 'tool/curriculum_path_output.json';

const unitId = 'unit4';
const batchSize = 10;
const flashcardsTotal = 50;
const multipleChoiceTotal = 50;
const fillBlankTotal = 20;
const trueFalseTotal = 20;

/// Max extra batch attempts (beyond the "one batch per 10 items" minimum)
/// allowed per (node, content type) before giving up and shipping fewer
/// items than the target with a warning.
const maxRetryBatchesPerType = 6;

/// Above this Jaccard word-overlap ratio, a new item is treated as a
/// near-duplicate of an already-accepted item and dropped.
const similarityThreshold = 0.6;

const nodes = [
  (
    id: 'node1',
    title: 'Sınıflandırmanın Temel İlkeleri',
    estimatedMinutes: 15,
    scope: '''
- 7 temel kategori: âlem, şube/filum, sınıf, takım, familya, cins, tür - büyükten küçüğe sıralanır.
- Takson: belirli bir kategoriye ait, ortak özellikleri paylaşan bireyler topluluğu.
- Hiyerarşide âlemden türe inildikçe: genetik çeşitlilik azalır, canlı çeşidi azalır, birey sayısı azalır, ortak özellik sayısı artar, homolog organ sayısı artar, akrabalık derecesi ve embriyonik/genetik benzerlik artar.
- Tür kavramı ilk olarak John Ray tarafından ortaya atıldı; tür, ortak atadan gelen, yapısal/işlevsel olarak benzer, doğal koşullarda üreyip verimli (kısır olmayan) yavru verebilen bireyler topluluğudur.
- Aynı türün bireyleri genelde aynı kromozom sayısına sahiptir, ama farklı türler de aynı kromozom sayısına sahip olabilir (örn. insan, bazı bitkiler, bazı balıklar) - bu akrabalık göstermez.
''',
  ),
  (
    id: 'node2',
    title: 'Bakteriler Âlemi ve Virüsler',
    estimatedMinutes: 20,
    scope: '''
- Bakteri hücre yapısı: sitoplazma (%80 su, nükleik asit/enzim/amino asit/karbonhidrat/lipit/inorganik madde içerir), pilus (konjugasyonla DNA aktarımı), kapsül (yapışma, dayanıklılık, su kaybını önleme), tek halkasal DNA (çekirdeksiz, sitoplazmada), hücre çeperi (peptidoglikan, koruma/şekil verme), ribozomlar (sitoplazmada dağınık, protein sentezi), hücre zarı (seçici geçirgen fosfolipit çift tabaka), plazmit (küçük halkasal DNA, genetik mühendislikte kullanılır), flagellum (hareket, küresel olmayan çoğu bakteride bulunur).
- Virüsler: canlı-cansız arası geçiş formu, protein kılıf + DNA veya RNA içerir, elektron mikroskobuyla görülür (çubuk/küre/elips/spiral şekilli). Metabolik aktivite gösteremezler (kendi sitoplazma/enzim sistemleri yok), zorunlu hücre içi parazittirler, belirli canlı/doku/hücreleri hedefler (örn. HIV akyuvarları enfekte eder), pH/radyasyon/sıcaklığa duyarlıdırlar, enzim sistemleri olmadığı için antibiyotiklere dirençlidirler. Hava/su/temas/vücut sıvılarıyla bulaşır, enfekte hücreler interferon salgılayarak savunur. Konak hücrenin enzim/enerji/kaynaklarını kullanarak çoğalırlar.
''',
  ),
  (
    id: 'node3',
    title: 'Arkeler Âlemi',
    estimatedMinutes: 15,
    scope: '''
- 1970'lerde gen dizileri ve ribozomal RNA parçaları karşılaştırılarak bakterilerden ayrı bir âlem olarak sınıflandırıldı.
- Tek hücreli prokaryot, bazı ökaryot-benzeri özellikler taşır; patojen türleri yok, endospor oluşturamazlar.
- Yapı: sitoplazma (%80 su), pilus (konjugasyonla DNA aktarımı), DNA (histon proteinlere sarılı - ökaryotlara benzer), hücre zarı (seçici geçirgen lipit çift tabaka), hücre çeperi (pseudopeptidoglikan), ribozom (yapısal olarak ökaryot ribozomlarına benzer, bu yüzden antibiyotiklere dirençli), flagellum (hareket).
- Yaşam ortamına göre gruplar: halofiller (aşırı tuzlu ortam), metanojenler (oksijensiz ortam, metan üretir), termofiller (sıcak su kaynakları).
''',
  ),
  (
    id: 'node4',
    title: 'Protista Âlemi',
    estimatedMinutes: 22,
    scope: '''
- Ökaryot canlılar arasında en ilkel grup, tek veya çok hücreli olabilir, sucul ortam/nemli toprak/parazit olarak yaşar.
- Kamçılılar: hücre çeperi yok, 1-2 kamçı var, koruyucu pellikula tabakası var, ışığa duyarlı göz lekesi ve fotosentez için kloroplast bulunabilir, ışık yetersizken dıştan beslenebilir (örn. Euglena).
- Kök ayaklılar: örnek amip, yalancı ayak (pseudopod) ile hareket eder, sabit şekli yoktur, yalancı ayaklarını hem hareket hem besin yakalamak için kullanır, bazı türleri insan/hayvan sindirim sisteminde parazitleşir.
- Algler: fotosentez yapar, hücre çeperi var, karada/suda yaşar, dünya oksijeninin önemli bir kısmını üretir, pigmentine göre yeşil/kahverengi/altın/kırmızı renkte olabilir.
- Slime moldler (küf benzeri): iplik yapılı, belirli hücre şekli yok, gerçek mantarlardan farklı olarak çok çekirdekli, amipsi hareket eder, hücre çeperi yoktur, nemli ortamda yaşar, eşeyli/eşeysiz üreyebilir, ayrıştırıcı olarak madde döngüsüne katkı sağlar.
- Önem: silis içeren protist kalıntıları diyatom toprağı oluşturur (diş macunu, yalıtım malzemesi), algler protein/vitamin/mineral açısından zengin besin kaynağıdır, atık arıtma/antibiyotik üretimi/kozmetik sanayinde kullanılır, sucul ortamda oksijen/besin kaynağıdır, ayrıştırıcı rolü vardır.
''',
  ),
  (
    id: 'node5',
    title: 'Mantarlar Âlemi',
    estimatedMinutes: 18,
    scope: '''
- Ökaryot, hücre çeperi kitinden yapılı, heterotrof (saprofit/parazit/simbiyotik beslenebilir) canlılardır, fotosentez yapmazlar.
- Vücut yapısı hif adı verilen ipliksi yapılardan oluşur, hifler bir araya gelerek miçel (misel) yapısını oluşturur.
- Üreme genelde sporla (eşeyli veya eşeysiz) gerçekleşir.
- Tek hücreli örnek: maya (fermantasyon, ekmek/alkol üretiminde kullanılır). Çok hücreli örnek: küf mantarları, şapkalı mantarlar.
- Simbiyotik ilişkiler: liken (mantar + alg/siyanobakteri ortak yaşamı), mikoriza (mantar + bitki kökü ortak yaşamı, bitkinin su/mineral alımını artırır).
- Ekosistemdeki rolü: başlıca ayrıştırıcı olarak organik maddeyi parçalayıp madde döngüsüne katkı sağlar; bazı türleri insanlarda hastalık (mantar enfeksiyonu) yapabilir, bazıları (penisilin gibi) antibiyotik üretiminde kullanılır.
''',
  ),
  (
    id: 'node6',
    title: 'Bitkiler Âlemi',
    estimatedMinutes: 22,
    scope: '''
- Fotosentetik ototrof beslenen, ökaryot, çoğunlukla çok hücreli canlılardır; kloroplastlarındaki klorofil sayesinde güneş enerjisini biyokimyasal enerjiye çevirir, su ve CO2'den organik madde üretir, oksijen açığa çıkar, üretilen glikoz nişasta halinde depolanır.
- Hücre çeperi selülozdan yapılıdır, turgor basıncıyla bitkiye diklik/destek sağlar.
- Yapraklarda gaz alışverişi ve terlemeyi sağlayan açılıp kapanabilen gözenekler (stoma) bulunur.
- Bitki kısımları: kök (su/mineral alımı, depolama, toprağa bağlanma) ve sürgün (gövde, dal, yaprak, çiçek, meyve, tohum).
- Üreme: kök/gövde/yaprakla eşeysiz, çiçek/meyve/tohumla eşeyli (spor veya tohumla gerçekleşir).
- Çok yıllık bitkilerde büyüme yaşam boyu sürer; bitkiler yer değiştiremez ama yönelim/irkilme hareketleri gösterebilir.
- Damarlı bitkilerde iletim demetleri (damar) su/mineral/organik madde taşır.
- Örnekler: damarsız tohumsuz (kara yosunu, ciğer otu), damarlı tohumsuz (eğrelti otu, atkuyruğu), damarlı tohumlu (karahindiba).
- Tam parazit (küsküt otu) ve yarı parazit (ökse otu) örnekleri de değinilebilir.
''',
  ),
  (
    id: 'node7',
    title: 'Hayvanlar Âlemi (Omurgasız ve Omurgalı)',
    estimatedMinutes: 25,
    scope: '''
- Genel özellikler: ökaryot, çok hücreli, aktif yer değiştirebilen, heterotrof beslenen, oksijenli solunum yapan, çoğunlukla eşeyli üreyen canlılardır.
- Omurgasızlar: omurga yapısı yok, sinir sistemi karın bölgesinde, genelde açık kan dolaşımı. Süngerler: en basit organizasyonlu, denizde zemine bağlı yaşar, vücut açıklıklarıyla gaz/besin alışverişi yapar, yüksek rejenerasyon yeteneği var. Sölenterler: doku düzeyinde organizasyon, kas/sinir dokusu var, örnekler hidra/denizanası/mercan.
- Omurgalılar: sırt boyunca omurlardan oluşan omurga, iç iskelet, sırtta sinir kordonu; hepsinde kapalı dolaşım var; suda yaşayanlar solungaçla, karada yaşayanlar akciğerle solunum yapar; kalp 2-4 odacıklı olabilir.
- Balıklar: tatlı/tuzlu suda yaşar, suya geçirimsiz pullu vücut, kıkırdak veya kemik iskelet, dış ortam sıcaklığından etkilenir (soğukkanlı), kış uykusuna yatmaz, boşaltım atığı amonyak, solungaçla solur.
- Kuşlar: uçabilen ilk omurgalı grup, keratin yapılı pul/tüy/pençe, gagalı-dişsiz, 4 odacıklı kalp (tam ayrık kan), sabit vücut sıcaklığı (sıcakkanlı), hava boşluklu içi boş kemikler, ön uzuvlar kanada dönüşmüş, gelişmiş görme/işitme, zayıf koku alma.
- Memeliler: kıllı vücut (bazı sucul türler hariç), sıcakkanlı, alveollü akciğer, göğüs-karın boşluğunu ayıran diyafram kası, 4 odacıklı kalp, deri bezleri (ter/yağ/süt bezi), iç döllenme ve gelişim, çoğunda plasenta ile embriyo beslenmesi, atık boşaltımı için böbrek.
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

  // Resume support: a node already on disk with a full item count for
  // every content type is treated as done and skipped, so a crash
  // (rate limit, network) only costs the in-progress node's work, not
  // everything generated before it.
  final existingNodes = ((units[unitIndex]['nodes'] as List?) ?? [])
      .cast<Map<String, dynamic>>();
  final generatedNodes = <Map<String, dynamic>>[];
  for (final n in existingNodes) {
    final isComplete =
        ((n['flashcards'] as List?)?.length ?? 0) >= flashcardsTotal &&
        ((n['multipleChoice'] as List?)?.length ?? 0) >= multipleChoiceTotal &&
        ((n['fillBlank'] as List?)?.length ?? 0) >= fillBlankTotal &&
        ((n['trueFalse'] as List?)?.length ?? 0) >= trueFalseTotal;
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
        'TYT Biyoloji sınavına hazırlanan bir öğrenci için "Canlıların '
        'Sınıflandırılması" ünitesinin "${node.title}" alt konusu. Sorular '
        'SADECE aşağıdaki kapsam notlarındaki kavramlara dayanmalı, bu '
        'notların dışına çıkmamalı, TYT seviyesinde kalmalı:\n${node.scope}';

    stderr.writeln('  -> Hafıza kartları üretiliyor ($flashcardsTotal)...');
    final flashcards = await _generateBatched<Flashcard>(
      client: client,
      apiKey: apiKey,
      topic: topic,
      total: flashcardsTotal,
      contentLabel: 'hafıza kartı',
      textOf: (c) => '${c.question} ${c.answer}',
      generateOne: (avoidList) =>
          _generateFlashcardBatch(client, apiKey, topic, avoidList),
    );

    stderr.writeln(
      '  -> Çoktan seçmeli sorular üretiliyor ($multipleChoiceTotal)...',
    );
    final multipleChoice = await _generateBatched<QuizQuestion>(
      client: client,
      apiKey: apiKey,
      topic: topic,
      total: multipleChoiceTotal,
      contentLabel: 'çoktan seçmeli soru',
      textOf: (q) => q.question,
      generateOne: (avoidList) =>
          _generateMultipleChoiceBatch(client, apiKey, topic, avoidList),
    );

    stderr.writeln(
      '  -> Boşluk doldurma soruları üretiliyor ($fillBlankTotal)...',
    );
    final fillBlank = await _generateBatched<QuizQuestion>(
      client: client,
      apiKey: apiKey,
      topic: topic,
      total: fillBlankTotal,
      contentLabel: 'boşluk doldurma sorusu',
      textOf: (q) => q.question,
      generateOne: (avoidList) =>
          _generateFillBlankBatch(client, apiKey, topic, avoidList),
    );

    stderr.writeln(
      '  -> Doğru/Yanlış soruları üretiliyor ($trueFalseTotal)...',
    );
    final trueFalse = await _generateBatched<QuizQuestion>(
      client: client,
      apiKey: apiKey,
      topic: topic,
      total: trueFalseTotal,
      contentLabel: 'doğru/yanlış ifadesi',
      textOf: (q) => q.question,
      generateOne: (avoidList) =>
          _generateTrueFalseBatch(client, apiKey, topic, avoidList),
    );

    generatedNodes.add({
      'id': node.id,
      'order': i + 1,
      'title': node.title,
      'estimatedMinutes': node.estimatedMinutes,
      'flashcards': flashcards.map((c) => c.toJson()).toList(),
      'multipleChoice': multipleChoice.map((q) => q.toJson()).toList(),
      'fillBlank': fillBlank.map((q) => q.toJson()).toList(),
      'trueFalse': trueFalse.map((q) => q.toJson()).toList(),
    });

    stderr.writeln(
      '  <- Tamamlandı: ${flashcards.length}/$flashcardsTotal kart, '
      '${multipleChoice.length}/$multipleChoiceTotal ÇS, '
      '${fillBlank.length}/$fillBlankTotal BD, '
      '${trueFalse.length}/$trueFalseTotal D/Y',
    );

    // Checkpoint after every node so a crash mid-run (rate limit, network)
    // only loses the node currently in progress.
    units[unitIndex] = {...units[unitIndex], 'nodes': generatedNodes};
    root['units'] = units;
    outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
    stderr.writeln('  (ara kayıt yazıldı: ${outFile.path})');
  }

  client.close();
  stderr.writeln('Tüm alt konular tamamlandı: ${outFile.path}');
}

/// Generates [total] items of type [T] in batches of [batchSize],
/// carrying forward a growing "avoid these" list of already-accepted item
/// texts so each new batch's prompt can steer the model away from
/// repeats, and locally filtering out anything too textually similar to
/// what's already been accepted. Retries a batch (with the avoid-list
/// updated) up to [maxRetryBatchesPerType] extra times if it doesn't net
/// enough new unique items, then gives up and ships what it has.
Future<List<T>> _generateBatched<T>({
  required HttpClient client,
  required String apiKey,
  required String topic,
  required int total,
  required String contentLabel,
  required String Function(T) textOf,
  required Future<List<T>> Function(List<String> avoidList) generateOne,
}) async {
  final accepted = <T>[];
  final acceptedTexts = <String>[];
  var extraAttempts = 0;

  while (accepted.length < total) {
    final remaining = total - accepted.length;
    final batch = await generateOne(acceptedTexts);
    var addedThisRound = 0;
    for (final item in batch) {
      if (accepted.length >= total) break;
      final text = textOf(item);
      if (text.trim().isEmpty) continue;
      final isDuplicate = acceptedTexts.any(
        (existing) => _similarity(text, existing) >= similarityThreshold,
      );
      if (isDuplicate) continue;
      accepted.add(item);
      acceptedTexts.add(text);
      addedThisRound++;
    }
    stderr.writeln(
      '     parti: +$addedThisRound (istenen $batchSize, kalan $remaining '
      '-> toplam ${accepted.length}/$total $contentLabel)',
    );
    if (addedThisRound == 0) {
      extraAttempts++;
      if (extraAttempts > maxRetryBatchesPerType) {
        stderr.writeln(
          '     UYARI: $maxRetryBatchesPerType ek denemeden sonra hâlâ '
          'yeterli benzersiz $contentLabel üretilemedi, '
          '${accepted.length}/$total ile devam ediliyor.',
        );
        break;
      }
    }
  }
  return accepted;
}

/// Jaccard similarity over normalized word sets (lowercased, punctuation
/// stripped, words shorter than 3 chars dropped) — a simple, dependency
/// free text-similarity check good enough to catch near-duplicate
/// questions/cards without needing embeddings.
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

/// Same U+FFFD/ASCII-fold corruption guard as generate_curriculum_path.dart
/// — fill-blank answers are graded character-for-character so a mangled
/// Turkish-character answer is worse than a slow retry.
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

    final hasCorruptedAnswer = questions.any(
      (q) => q.answerText.contains('�'),
    );
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
        // options are fixed as ['Doğru', 'Yanlış'] with correctIndex
        // pointing at whichever one matches isTrue, so the D/Y badge
        // (which reads off options[correctIndex]) always matches the
        // statement's actual truth value.
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

/// Timestamps of recent requests, used to stay under the free-tier
/// per-minute quota (observed as 15 req/min for gemini-flash-lite-latest)
/// by pacing ourselves under that limit instead of firing bursts and
/// eating 429s.
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

/// Pulls the server-suggested `retryDelay` (e.g. `"55s"`) out of a 429
/// response body, if present.
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
        final retryDelay = _parseRetryDelay(responseBody) ??
            const Duration(seconds: 60);
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
      stderr.writeln(
        '     (deneme ${attempt + 1} başarısız: $e, tekrar deneniyor...)',
      );
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
