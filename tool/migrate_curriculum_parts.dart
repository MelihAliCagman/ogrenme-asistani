// One-off migration: reshapes tool/curriculum_path_output.json's node
// content from flat arrays (50 flashcards, 50 multipleChoice, 20
// fillBlank, 20 trueFalse) into small named "parts" of 10 items each —
// "Kart Seti 1..5", "Test 1..5", "Boşluk Doldurma 1..2",
// "Doğru/Yanlış 1..2" — matching the new CurriculumNode part-based model
// (lib/models/curriculum_path.dart). This is a pure reshape of content
// ALREADY generated and reviewed — it does not call Gemini or invent any
// new content, just splits the existing flat lists.
//
// Idempotent: a node whose content is already part-shaped (an item with
// a nested 'cards'/'questions' key instead of 'question'/'answer'
// directly) is left untouched, so running this twice is a no-op.
//
// After running, push the reshaped file to Firestore with:
//   dart run tool/seed_curriculum_path_admin.dart
//
// Run with: dart run tool/migrate_curriculum_parts.dart

import 'dart:convert';
import 'dart:io';

const outputPath = 'tool/curriculum_path_output.json';
const partSize = 10;

void main() {
  final file = File(outputPath);
  if (!file.existsSync()) {
    stderr.writeln('$outputPath bulunamadı.');
    exit(1);
  }
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final units = (root['units'] as List).cast<Map<String, dynamic>>();

  var migratedNodes = 0;
  var skippedNodes = 0;

  for (final unit in units) {
    final nodes = (unit['nodes'] as List? ?? []).cast<Map<String, dynamic>>();
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (_isAlreadyPartShaped(node)) {
        skippedNodes++;
        continue;
      }
      nodes[i] = {
        ...node,
        'flashcards': _chunkFlashcards(
          (node['flashcards'] as List? ?? []).cast<Map<String, dynamic>>(),
          'Kart Seti',
        ),
        'multipleChoice': _chunkQuestions(
          (node['multipleChoice'] as List? ?? []).cast<Map<String, dynamic>>(),
          'Test',
        ),
        'fillBlank': _chunkQuestions(
          (node['fillBlank'] as List? ?? []).cast<Map<String, dynamic>>(),
          'Boşluk Doldurma',
        ),
        'trueFalse': _chunkQuestions(
          (node['trueFalse'] as List? ?? []).cast<Map<String, dynamic>>(),
          'Doğru/Yanlış',
        ),
      };
      migratedNodes++;
      stderr.writeln('  -> ${unit['id']}/${node['id']} (${node['title']}) parçalara bölündü.');
    }
  }

  root['units'] = units;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
  stderr.writeln(
    'Tamamlandı: $migratedNodes düğüm parçalara bölündü, $skippedNodes düğüm '
    'zaten parçalıydı (atlandı). Yazıldı: $outputPath',
  );
}

/// A node counts as already migrated if its flashcards field is empty,
/// or its first item has a 'cards' key (a part) rather than 'question'/
/// 'answer' directly (the old flat shape) — same check mirrored for the
/// quiz-shaped fields via a 'questions' key.
bool _isAlreadyPartShaped(Map<String, dynamic> node) {
  final flashcards = node['flashcards'] as List? ?? [];
  if (flashcards.isNotEmpty) {
    final first = flashcards.first as Map<String, dynamic>;
    if (first.containsKey('cards')) return true;
    if (first.containsKey('question')) return false;
  }
  final multipleChoice = node['multipleChoice'] as List? ?? [];
  if (multipleChoice.isNotEmpty) {
    final first = multipleChoice.first as Map<String, dynamic>;
    if (first.containsKey('questions')) return true;
    if (first.containsKey('question')) return false;
  }
  // Both fields empty (a not-yet-authored node, e.g. an empty unit) —
  // nothing to migrate either way; treat as "already fine".
  return true;
}

List<Map<String, dynamic>> _chunkFlashcards(
  List<Map<String, dynamic>> cards,
  String titlePrefix,
) {
  final parts = <Map<String, dynamic>>[];
  for (var start = 0; start < cards.length; start += partSize) {
    final end = (start + partSize < cards.length) ? start + partSize : cards.length;
    parts.add({
      'title': '$titlePrefix ${parts.length + 1}',
      'cards': cards.sublist(start, end),
    });
  }
  return parts;
}

List<Map<String, dynamic>> _chunkQuestions(
  List<Map<String, dynamic>> questions,
  String titlePrefix,
) {
  final parts = <Map<String, dynamic>>[];
  for (var start = 0; start < questions.length; start += partSize) {
    final end =
        (start + partSize < questions.length) ? start + partSize : questions.length;
    parts.add({
      'title': '$titlePrefix ${parts.length + 1}',
      'questions': questions.sublist(start, end),
    });
  }
  return parts;
}
