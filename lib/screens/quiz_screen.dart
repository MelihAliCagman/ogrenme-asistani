import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';

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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SORU',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.question,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showAnswer) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CEVAP',
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.answer,
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
