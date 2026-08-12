import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';

/// A non-persisted quiz flow for previewing a Keşfet sample lesson's
/// test — same shuffle/scoring mechanics as the real quiz screen, but
/// nothing is saved (no attempt history) since the content isn't the
/// user's own yet.
class SampleQuizScreen extends StatefulWidget {
  const SampleQuizScreen({
    super.key,
    required this.title,
    required this.questions,
  });

  final String title;
  final List<QuizQuestion> questions;

  @override
  State<SampleQuizScreen> createState() => _SampleQuizScreenState();
}

class _SampleQuizScreenState extends State<SampleQuizScreen> {
  late List<int> _order;
  late Map<int, List<int>> _optionOrder;
  int _currentIndex = 0;
  int? _selectedOption;
  int _correctCount = 0;
  bool _finished = false;
  final List<int> _wrongIndices = [];

  QuizQuestion get _currentQuestion =>
      widget.questions[_order[_currentIndex]];

  List<int> get _currentOptionOrder => _optionOrder[_order[_currentIndex]]!;

  int get _currentCorrectDisplayIndex =>
      _currentOptionOrder.indexOf(_currentQuestion.correctIndex);

  @override
  void initState() {
    super.initState();
    _startQuiz();
  }

  void _startQuiz() {
    setState(() {
      _order = List.generate(widget.questions.length, (i) => i)..shuffle();
      _optionOrder = {
        for (final questionIndex in _order)
          questionIndex:
              List.generate(widget.questions[questionIndex].options.length, (i) => i)
                ..shuffle(),
      };
      _currentIndex = 0;
      _selectedOption = null;
      _correctCount = 0;
      _finished = false;
      _wrongIndices.clear();
    });
  }

  void _selectOption(int displayIndex) {
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = displayIndex;
      if (displayIndex == _currentCorrectDisplayIndex) {
        _correctCount++;
      } else {
        _wrongIndices.add(_order[_currentIndex]);
      }
    });
  }

  void _next() {
    if (_currentIndex + 1 < _order.length) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
      });
      return;
    }
    setState(() => _finished = true);
  }

  void _backToLesson() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _finished ? _buildSummary(context) : _buildQuiz(context),
      ),
    );
  }

  Widget _buildQuiz(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final question = _currentQuestion;
    final optionOrder = _currentOptionOrder;
    const optionLabels = ['A', 'B', 'C', 'D'];
    final isWrongSelected =
        _selectedOption != null &&
        _selectedOption != _currentCorrectDisplayIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_currentIndex + 1} / ${_order.length}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  question.question,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var displayIndex = 0; displayIndex < optionOrder.length; displayIndex++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    label: optionLabels[displayIndex],
                    text: question.options[optionOrder[displayIndex]],
                    state: _optionState(displayIndex),
                    onTap: () => _selectOption(displayIndex),
                  ),
                ),
              if (isWrongSelected && question.explanation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          question.explanation,
                          style: TextStyle(color: colorScheme.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        FilledButton(
          onPressed: _selectedOption == null ? null : _next,
          child: Text(_currentIndex + 1 < _order.length ? 'İleri' : 'Bitir'),
        ),
      ],
    );
  }

  _OptionState _optionState(int displayIndex) {
    if (_selectedOption == null) return _OptionState.neutral;
    if (displayIndex == _currentCorrectDisplayIndex) return _OptionState.correct;
    if (displayIndex == _selectedOption) return _OptionState.incorrect;
    return _OptionState.neutral;
  }

  Widget _buildSummary(BuildContext context) {
    final total = _order.length;
    final percent = total == 0 ? 0 : (_correctCount / total * 100).round();

    return ListView(
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.emoji_events_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '$_correctCount/$total doğru',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Doğru oranı: %$percent',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _startQuiz,
              icon: const Icon(Icons.replay),
              label: const Text('Tekrar Başla'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _backToLesson,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Derse Dön'),
            ),
          ],
        ),
        if (_wrongIndices.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            'Yanlış Yapılan Sorular',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final index in _wrongIndices)
            _WrongQuestionCard(question: widget.questions[index]),
        ],
      ],
    );
  }
}

enum _OptionState { neutral, correct, incorrect }

class _WrongQuestionCard extends StatelessWidget {
  const _WrongQuestionCard({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              question.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(
              'Doğru cevap: ${question.options[question.correctIndex]}',
              style: TextStyle(color: colorScheme.primary),
            ),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(question.explanation),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color background;
    Color foreground;
    switch (state) {
      case _OptionState.correct:
        background = Colors.green.withValues(alpha: 0.15);
        foreground = Colors.green.shade800;
        break;
      case _OptionState.incorrect:
        background = colorScheme.errorContainer;
        foreground = colorScheme.onErrorContainer;
        break;
      case _OptionState.neutral:
        background = colorScheme.surfaceContainerHigh;
        foreground = colorScheme.onSurface;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: foreground.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: foreground.withValues(alpha: 0.15),
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: foreground))),
            if (state == _OptionState.correct)
              Icon(Icons.check_circle, color: foreground, size: 20),
            if (state == _OptionState.incorrect)
              Icon(Icons.cancel, color: foreground, size: 20),
          ],
        ),
      ),
    );
  }
}
