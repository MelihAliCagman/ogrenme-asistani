import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrenme_asistani/models/sample_lesson.dart';

/// Reads the public, read-only `sample_lessons` collection used by the
/// Keşfet (Discover) tab. Content is authored once (outside the app) and
/// shared by every user — never written to from the client.
class SampleLessonRepository {
  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('sample_lessons');

  Future<List<SampleLesson>> loadAll() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => SampleLesson.fromJson(doc.id, doc.data()))
        .toList();
  }
}
