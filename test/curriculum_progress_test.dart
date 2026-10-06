import 'package:flutter_test/flutter_test.dart';
import 'package:ogrenme_asistani/models/curriculum_path.dart';
import 'package:ogrenme_asistani/models/path_progress.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

Map<String, dynamic> _cardPart(String title) => {
  'title': title,
  'cards': [
    {'question': 'S', 'answer': 'C'},
  ],
};

Map<String, dynamic> _quizPart(String title) => {
  'title': title,
  'questions': [
    {
      'question': 'Soru?',
      'options': ['A', 'B', 'C', 'D'],
      'correctIndex': 2,
      'explanation': 'Açıklama',
    },
  ],
};

CurriculumNode _node({int cardParts = 2, int mcParts = 2}) {
  return CurriculumNode.fromJson({
    'id': 'node1',
    'order': 1,
    'title': 'Konu',
    'flashcards': [for (var i = 1; i <= cardParts; i++) _cardPart('Kart Seti $i')],
    'multipleChoice': [for (var i = 1; i <= mcParts; i++) _quizPart('Test $i')],
  }, unitId: 'unit6');
}

void main() {
  group('CurriculumNode', () {
    test('düğüm kimliği ünite kimliğiyle öneklenir', () {
      expect(_node().id, 'unit6_node1');
    });

    test('içeriği olmayan tür tamamlanmayı engellemez', () {
      final node = _node();
      expect(node.hasContent(PathContentKind.fillBlank), isFalse);
      expect(node.hasContent(PathContentKind.flashcards), isTrue);
    });

    test('içeriği hiç olmayan (sadece müfredat) konu asla tamamlanmış sayılmaz', () {
      final outline = CurriculumNode.fromJson({
        'id': 'node1',
        'order': 1,
        'title': 'Sadece başlık',
      }, unitId: 'unit1');
      expect(outline.hasAnyContent, isFalse);
      expect(outline.isFullyCompleted(const NodeProgress()), isFalse);
      final unit = CurriculumUnit.fromJson('unit1', {
        'order': 1,
        'title': 'U1',
        'nodes': [
          {'id': 'node1', 'order': 1, 'title': 'Sadece başlık'},
        ],
      });
      expect(unit.hasContent, isFalse);
      expect(unit.contentNodeCount, 0);
      expect(unit.isComingSoon, isFalse);
    });

    test('tüm parçalar bitmeden düğüm tamamlanmış sayılmaz', () {
      final node = _node();
      const half = NodeProgress(
        completedFlashcardParts: {0, 1},
        completedMultipleChoiceParts: {0},
      );
      expect(node.isFullyCompleted(half), isFalse);
    });

    test('içeriği olan tüm türlerin tüm parçaları bitince tamamlanır', () {
      final node = _node();
      const all = NodeProgress(
        completedFlashcardParts: {0, 1},
        completedMultipleChoiceParts: {0, 1},
      );
      expect(node.isFullyCompleted(all), isTrue);
    });
  });

  group('NodeProgress', () {
    test('parçası olmayan tür asla tamamlanmış sayılmaz', () {
      const progress = NodeProgress();
      expect(progress.isKindCompleted(PathContentKind.trueFalse, 0), isFalse);
    });

    test('aynı parça iki kez kaydedilince fazladan sayılmaz', () {
      final progress = NodeProgress.fromJson({
        'completedParts': {
          'flashcards': [0, 0, 1],
        },
      });
      expect(progress.completedFlashcardParts, {0, 1});
      expect(progress.isKindCompleted(PathContentKind.flashcards, 3), isFalse);
    });
  });

  group('CurriculumUnit', () {
    test('düğümsüz ünite "yakında" sayılır ve düğümler sıralanır', () {
      expect(
        CurriculumUnit.fromJson('unit7', {'title': 'U7'}).isComingSoon,
        isTrue,
      );
      final unit = CurriculumUnit.fromJson('unit1', {
        'order': 1,
        'title': 'U1',
        'nodes': [
          {'id': 'node2', 'order': 2, 'title': 'B'},
          {'id': 'node1', 'order': 1, 'title': 'A'},
        ],
      });
      expect(unit.nodes.map((n) => n.title), ['A', 'B']);
    });
  });

  group('QuizQuestion', () {
    test('JSON gidiş-dönüşü soruyu korur', () {
      final q = QuizQuestion.fromJson({
        'question': 'Soru?',
        'options': ['A', 'B'],
        'correctIndex': 1,
        'explanation': 'x',
        'type': 'trueFalse',
      });
      final again = QuizQuestion.fromJson(q.toJson());
      expect(again.question, 'Soru?');
      expect(again.correctIndex, 1);
      expect(again.type, QuestionType.trueFalse);
    });
  });
}
