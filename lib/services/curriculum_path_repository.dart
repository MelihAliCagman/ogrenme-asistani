import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/curriculum_path.dart';

/// The chooser-level facts about one seeded path (one ders of one exam
/// stage, e.g. "TYT Türkçe") — enough to draw its card without loading its
/// units.
class CurriculumPathSummary {
  const CurriculumPathSummary({
    required this.subjectKey,
    required this.title,
    required this.examType,
    required this.subject,
    required this.hasContent,
    required this.unitCount,
    required this.nodeCount,
  });

  final String subjectKey;
  final String title;
  final String examType;
  final String subject;

  /// `false` for an outline-only path (units/topics listed, no questions
  /// written yet).
  final bool hasContent;
  final int unitCount;
  final int nodeCount;

  /// "TYT", "AYT" or "YDT" — the first segment of [subjectKey]
  /// (`tyt_turkce` -> `TYT`).
  String get stage => subjectKey.split('_').first.toUpperCase();
}

/// Reads the public, read-only `curriculum_paths` collection (the
/// Duolingo-style "Ders Yolu" unit/node map). Content is authored once
/// via the admin seed tool — never written to from the client, same
/// pattern as `sample_lessons`/[SampleLessonRepository].
class CurriculumPathRepository {
  CollectionReference<Map<String, dynamic>> get _paths =>
      FirebaseFirestore.instance.collection('curriculum_paths');

  /// Every seeded path's chooser-relevant fields, for the "Ders Yolları"
  /// hierarchy (sınav türü -> ders -> path, e.g. YKS -> Biyoloji -> "TYT
  /// Biyoloji") — grouped/derived purely from this data at the UI layer,
  /// so a newly seeded path (a new subject, or a new exam-scoped variant
  /// like "AYT Biyoloji") slots into the hierarchy without any app code
  /// change. [hasContent] is `false` for a placeholder path seeded with
  /// no units yet (e.g. "AYT Biyoloji" before it's authored), shown as
  /// locked/"Yakında" the same way an empty [CurriculumUnit] already is.
  Future<List<CurriculumPathSummary>> loadAvailablePaths() async {
    final snapshot = await _paths.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CurriculumPathSummary(
        subjectKey: doc.id,
        title: data['title'] as String? ?? doc.id,
        examType: data['examType'] as String? ?? '',
        subject: data['subject'] as String? ?? '',
        hasContent: data['hasContent'] as bool? ?? false,
        unitCount: (data['unitCount'] as num?)?.toInt() ?? 0,
        nodeCount: (data['nodeCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<CurriculumPath?> loadPath(String subjectKey) async {
    final doc = await _paths.doc(subjectKey).get();
    final data = doc.data();
    if (data == null) return null;
    final unitsSnapshot = await _paths
        .doc(subjectKey)
        .collection('units')
        .orderBy('order')
        .get();
    final units = unitsSnapshot.docs
        .map((d) => CurriculumUnit.fromJson(d.id, d.data()))
        .toList();
    return CurriculumPath.fromJson(subjectKey, data, units);
  }
}
