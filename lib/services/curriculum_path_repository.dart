import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/curriculum_path.dart';

/// Reads the public, read-only `curriculum_paths` collection (the
/// Duolingo-style "Ders Yolu" unit/node map). Content is authored once
/// via the admin seed tool — never written to from the client, same
/// pattern as `sample_lessons`/[SampleLessonRepository].
class CurriculumPathRepository {
  CollectionReference<Map<String, dynamic>> get _paths =>
      FirebaseFirestore.instance.collection('curriculum_paths');

  /// The subject keys/titles of every seeded path, for the "Ders
  /// Yolları" chooser screen.
  Future<List<({String subjectKey, String title})>> loadAvailablePaths() async {
    final snapshot = await _paths.get();
    return snapshot.docs
        .map(
          (doc) => (
            subjectKey: doc.id,
            title: doc.data()['title'] as String? ?? doc.id,
          ),
        )
        .toList();
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
