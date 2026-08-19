import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/quiz_attempt.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/streak_repository.dart';
import 'package:ogrenme_asistani/widgets/quiz_attempt_tile.dart';

class QuizSetScreen extends StatefulWidget {
  const QuizSetScreen({super.key, required this.quizSet, this.subject});

  final QuizSet quizSet;

  /// The quiz's own subject, if any — shown in the result note
  /// regardless of where this screen was opened from.
  final Subject? subject;

  @override
  State<QuizSetScreen> createState() => _QuizSetScreenState();
}

class _QuizSetScreenState extends State<QuizSetScreen> {
  final _repository = QuizSetRepository();
  late List<int> _order;
  int _currentIndex = 0;
  int? _selectedOption;
  int _correctCount = 0;
  bool _finished = false;
  final List<int> _wrongIndices = [];
  final Map<int, int> _wrongSelections = {};
  final Map<int, String> _wrongTextAnswers = {};
  late List<QuizAttempt> _attempts;

  final TextEditingController _fillBlankController = TextEditingController();
  bool _fillBlankSubmitted = false;
  bool _fillBlankCorrect = false;

  /// For each question (keyed by its original index), a shuffled
  /// permutation of its option indices — re-rolled every attempt so the
  /// answer position can't be memorized.
  late Map<int, List<int>> _optionOrder;

  QuizQuestion get _currentQuestion =>
      widget.quizSet.questions[_order[_currentIndex]];

  String get _currentFillBlankDisplayText =>
      _fillBlankDisplayText(_currentQuestion);

  List<int> get _currentOptionOrder => _optionOrder[_order[_currentIndex]]!;

  /// The displayed position (0..3) of the correct answer for the
  /// current question, after option shuffling.
  int get _currentCorrectDisplayIndex =>
      _currentOptionOrder.indexOf(_currentQuestion.correctIndex);

  @override
  void initState() {
    super.initState();
    _attempts = List.of(widget.quizSet.attempts);
    _startQuiz();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      StreakRepository().recordActivityToday(
        uid,
        subjectId: widget.quizSet.subjectId,
        subjectName: widget.subject?.name,
      );
    }
  }

  void _startQuiz() {
    setState(() {
      _order = List.generate(widget.quizSet.questions.length, (i) => i)
        ..shuffle();
      _optionOrder = {
        for (final questionIndex in _order)
          questionIndex:
              List.generate(
                  widget.quizSet.questions[questionIndex].options.length,
                  (i) => i,
                )
                ..shuffle(),
      };
      _currentIndex = 0;
      _selectedOption = null;
      _correctCount = 0;
      _finished = false;
      _wrongIndices.clear();
      _wrongSelections.clear();
      _wrongTextAnswers.clear();
      _fillBlankController.clear();
      _fillBlankSubmitted = false;
      _fillBlankCorrect = false;
    });
  }

  void _submitFillBlankAnswer() {
    if (_fillBlankSubmitted) return;
    final given = _fillBlankController.text.trim();
    final expected = _currentQuestion.answerText.trim();
    final isCorrect = given.toLowerCase() == expected.toLowerCase();
    setState(() {
      _fillBlankSubmitted = true;
      _fillBlankCorrect = isCorrect;
      if (isCorrect) {
        _correctCount++;
      } else {
        final questionIndex = _order[_currentIndex];
        _wrongIndices.add(questionIndex);
        _wrongTextAnswers[questionIndex] = given;
      }
    });
  }

  void _selectOption(int displayIndex) {
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = displayIndex;
      if (displayIndex == _currentCorrectDisplayIndex) {
        _correctCount++;
      } else {
        final questionIndex = _order[_currentIndex];
        _wrongIndices.add(questionIndex);
        _wrongSelections[questionIndex] = _currentOptionOrder[displayIndex];
      }
    });
  }

  void _next() {
    if (_currentIndex + 1 < _order.length) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _fillBlankController.clear();
        _fillBlankSubmitted = false;
        _fillBlankCorrect = false;
      });
      return;
    }
    setState(() => _finished = true);
    _saveAttempt();
  }

  Future<void> _saveAttempt() async {
    final attempt = QuizAttempt(
      completedAt: DateTime.now(),
      correctCount: _correctCount,
      totalCount: _order.length,
      wrongQuestionIndices: List.of(_wrongIndices),
      wrongSelections: Map.of(_wrongSelections),
      wrongTextAnswers: Map.of(_wrongTextAnswers),
    );
    setState(() => _attempts = [..._attempts, attempt]);
    await _repository.addAttempt(widget.quizSet.id, attempt);
  }

  /// Always pops back to whichever screen pushed this one — Setlerim,
  /// a ders detayı, or a Ders Yolları node all push this screen directly,
  /// so a plain pop naturally lands back on the session's real starting
  /// point instead of a hardcoded destination.
  void _backToOrigin() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _fillBlankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.quizSet.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _finished ? _buildSummary(context) : _buildQuiz(context),
      ),
    );
  }

  Widget _buildQuiz(BuildContext context) {
    final question = _currentQuestion;
    final isFillBlank = question.type == QuestionType.fillBlank;
    final canAdvance = isFillBlank ? _fillBlankSubmitted : _selectedOption != null;

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
          child: isFillBlank ? _buildFillBlankBody(context) : _buildChoiceBody(context),
        ),
        FilledButton(
          onPressed: canAdvance ? _next : null,
          child: Text(_currentIndex + 1 < _order.length ? 'İleri' : 'Bitir'),
        ),
      ],
    );
  }

  Widget _buildChoiceBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final question = _currentQuestion;
    final optionOrder = _currentOptionOrder;
    final optionLabels = question.type == QuestionType.trueFalse
        ? const ['D', 'Y']
        : const ['A', 'B', 'C', 'D'];
    final isWrongSelected =
        _selectedOption != null &&
        _selectedOption != _currentCorrectDisplayIndex;

    return ListView(
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
        if (isWrongSelected && question.explanation.isNotEmpty)
          _ExplanationBox(explanation: question.explanation),
      ],
    );
  }

  Widget _buildFillBlankBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final question = _currentQuestion;

    Color? borderColor;
    if (_fillBlankSubmitted) {
      borderColor = _fillBlankCorrect ? Colors.green : colorScheme.error;
    }

    return ListView(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectableText(
            _currentFillBlankDisplayText,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _fillBlankController,
          enabled: !_fillBlankSubmitted,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitFillBlankAnswer(),
          decoration: InputDecoration(
            hintText: 'Cevabını buraya yaz...',
            border: const OutlineInputBorder(),
            focusedBorder: borderColor == null
                ? null
                : OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2)),
            enabledBorder: borderColor == null
                ? null
                : OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2)),
            suffixIcon: !_fillBlankSubmitted
                ? null
                : Icon(
                    _fillBlankCorrect ? Icons.check_circle : Icons.cancel,
                    color: borderColor,
                  ),
          ),
        ),
        if (!_fillBlankSubmitted) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _submitFillBlankAnswer,
            child: const Text('Cevapla'),
          ),
        ],
        if (_fillBlankSubmitted && !_fillBlankCorrect) ...[
          const SizedBox(height: 12),
          Text(
            'Doğru cevap: ${question.answerText}',
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (_fillBlankSubmitted &&
            !_fillBlankCorrect &&
            question.explanation.isNotEmpty)
          _ExplanationBox(explanation: question.explanation),
      ],
    );
  }

  _OptionState _optionState(int displayIndex) {
    if (_selectedOption == null) return _OptionState.neutral;
    if (displayIndex == _currentCorrectDisplayIndex) return _OptionState.correct;
    if (displayIndex == _selectedOption) return _OptionState.incorrect;
    return _OptionState.neutral;
  }

  /// Question indices that were wrong in the previous attempt (the one
  /// right before this one) but correct this time — a simple sign of
  /// progress.
  List<int> get _improvedSinceLastAttempt {
    if (_attempts.length < 2) return [];
    final previous = _attempts[_attempts.length - 2];
    return previous.wrongQuestionIndices
        .where((i) => !_wrongIndices.contains(i))
        .toList();
  }

  Widget _buildSummary(BuildContext context) {
    final total = _order.length;
    final percent = total == 0 ? 0 : (_correctCount / total * 100).round();
    final improved = _improvedSinceLastAttempt;

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
        if (_wrongIndices.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.subject != null
                ? '${widget.subject!.name} dersinde ${_wrongIndices.length} soruda hata yaptın. Bu konuyu tekrar etmen faydalı olabilir.'
                : '${_wrongIndices.length} soruda hata yaptın. Bu konuyu tekrar etmen faydalı olabilir.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (improved.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Önceki denemede yanlış yaptığın ${improved.length} soruyu bu sefer doğru yaptın. İlerliyorsun!',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.green.shade700),
            textAlign: TextAlign.center,
          ),
        ],
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
              onPressed: _backToOrigin,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Geri Dön'),
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
            _WrongQuestionCard(
              question: widget.quizSet.questions[index],
              givenAnswer: _wrongTextAnswers[index],
            ),
        ],
        if (_attempts.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            'Geçmiş Denemeler',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _attempts.length; i++)
            QuizAttemptTile(
              attemptNumber: i + 1,
              attempt: _attempts[i],
              questions: widget.quizSet.questions,
            ),
        ],
      ],
    );
  }
}

final _blankMarker = RegExp('_{3,}');

/// The fill-blank question text with its "____" placeholder replaced by
/// underscores matching the correct answer's letter count (e.g. a
/// 4-letter answer shows "_ _ _ _"), instead of a fixed-length blank.
String _fillBlankDisplayText(QuizQuestion question) {
  final letterCount = question.answerText.trim().replaceAll(' ', '').length;
  final placeholder = List.filled(letterCount > 0 ? letterCount : 1, '_').join(' ');
  return question.question.replaceFirst(_blankMarker, placeholder);
}

enum _OptionState { neutral, correct, incorrect }

class _WrongQuestionCard extends StatelessWidget {
  const _WrongQuestionCard({required this.question, this.givenAnswer});

  final QuizQuestion question;

  /// The user's own typed answer, for fill-blank questions only.
  final String? givenAnswer;

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
              question.type == QuestionType.fillBlank
                  ? _fillBlankDisplayText(question)
                  : question.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (question.type == QuestionType.fillBlank &&
                givenAnswer != null &&
                givenAnswer!.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(
                'Senin cevabın: $givenAnswer',
                style: TextStyle(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: 6),
            SelectableText(
              'Doğru cevap: ${question.answerText}',
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

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
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
                explanation,
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ),
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
            Expanded(
              child: Text(text, style: TextStyle(color: foreground)),
            ),
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
