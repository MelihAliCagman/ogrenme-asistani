import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/widgets/flip_card.dart';
import 'package:ogrenme_asistani/widgets/labeled_info_card.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.cardSet, this.onFinished});

  final FlashcardSet cardSet;

  /// Called once the swipe-through session reaches its summary screen —
  /// i.e. every card has been reviewed, regardless of score. Used by
  /// the Ders Yolları path screen to mark that node's flashcard content
  /// as completed.
  final VoidCallback? onFinished;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<Flashcard> _shuffledCards;
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _correctCount = 0;
  int _incorrectCount = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startQuiz();
  }

  void _startQuiz() {
    setState(() {
      _shuffledCards = List.of(widget.cardSet.cards)..shuffle();
      _currentIndex = 0;
      _showAnswer = false;
      _correctCount = 0;
      _incorrectCount = 0;
      _finished = false;
    });
  }

  void _revealAnswer() {
    setState(() {
      _showAnswer = true;
    });
  }

  void _answer(bool knewIt) {
    setState(() {
      if (knewIt) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }

      if (_currentIndex + 1 < _shuffledCards.length) {
        _currentIndex++;
        _showAnswer = false;
      } else {
        _finished = true;
      }
    });
    if (_finished) {
      widget.onFinished?.call();
    }
  }

  /// Always pops back to whichever screen pushed this one (always
  /// [CardSetDetailScreen], which itself may have come from Setlerim, a
  /// ders detayı, or a Ders Yolları node) instead of a hardcoded
  /// destination.
  void _backToOrigin() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tekrar Et - ${widget.cardSet.title}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _finished ? _buildSummary(context) : _buildQuiz(context),
      ),
    );
  }

  Widget _buildQuiz(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = _shuffledCards[_currentIndex];

    final flipCard = FlipCard(
      // Once already revealed, tapping again just flips the FlipCard
      // locally back and forth (harmless) — onFlip is only needed to
      // learn about the FIRST flip, which is when the answer becomes
      // visible and swiping should unlock.
      onFlip: _showAnswer ? null : _revealAnswer,
      front: LabeledInfoCard(
        label: 'SORU',
        text: card.question,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
        textFontSize: 18,
      ),
      back: LabeledInfoCard(
        label: 'CEVAP',
        text: card.answer,
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        textFontSize: 18,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_currentIndex + 1} / ${_shuffledCards.length}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Dismissible(
            key: ValueKey('card_$_currentIndex'),
            // Swiping only does anything once the card's been flipped
            // to show its answer — before that, a horizontal drag is
            // just FlipCard's own tap-to-flip gesture underneath.
            direction: _showAnswer ? DismissDirection.horizontal : DismissDirection.none,
            onDismissed: (direction) =>
                _answer(direction == DismissDirection.startToEnd),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.cancel, color: colorScheme.error, size: 32),
            ),
            child: flipCard,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final total = _shuffledCards.length;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        Icon(
          Icons.emoji_events_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '$_correctCount/$total doğru bildin',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Bilemediğin: $_incorrectCount',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _startQuiz,
          icon: const Icon(Icons.replay),
          label: const Text('Tekrar Başla'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _backToOrigin,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Geri Dön'),
        ),
        ],
      ),
    );
  }
}
