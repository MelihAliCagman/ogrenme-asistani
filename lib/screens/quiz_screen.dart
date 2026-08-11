import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/widgets/labeled_info_card.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.cardSet});

  final FlashcardSet cardSet;

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
  }

  void _backToCardsList() {
    Navigator.of(context).popUntil((route) => route.isFirst);
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LabeledInfoCard(
                label: 'SORU',
                text: card.question,
                background: colorScheme.primaryContainer,
                foreground: colorScheme.onPrimaryContainer,
                textFontSize: 18,
              ),
              if (_showAnswer) ...[
                const SizedBox(height: 12),
                LabeledInfoCard(
                  label: 'CEVAP',
                  text: card.answer,
                  background: colorScheme.secondaryContainer,
                  foreground: colorScheme.onSecondaryContainer,
                  textFontSize: 18,
                ),
              ],
            ],
          ),
        ),
        if (!_showAnswer)
          FilledButton(
            onPressed: _revealAnswer,
            child: const Text('Cevabı Göster'),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _answer(false),
                  child: const Text('Bilemedim'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _answer(true),
                  child: const Text('Bildim'),
                ),
              ),
            ],
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
          onPressed: _backToCardsList,
          icon: const Icon(Icons.style),
          label: const Text("Kartlarım'a Dön"),
        ),
        ],
      ),
    );
  }
}
