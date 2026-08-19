import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/curriculum_path.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/path_progress.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/set_format.dart';
import 'package:ogrenme_asistani/screens/card_set_detail_screen.dart';
import 'package:ogrenme_asistani/screens/quiz_set_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/curriculum_path_repository.dart';
import 'package:ogrenme_asistani/services/path_progress_repository.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';

enum _ContentKind { flashcards, multipleChoice, fillBlank, trueFalse }

extension on _ContentKind {
  SetFormat get setFormat {
    switch (this) {
      case _ContentKind.flashcards:
        return SetFormat.flashcards;
      case _ContentKind.multipleChoice:
        return SetFormat.multipleChoice;
      case _ContentKind.fillBlank:
        return SetFormat.fillBlank;
      case _ContentKind.trueFalse:
        return SetFormat.trueFalse;
    }
  }
}

/// The Duolingo-style unit/node map for one subject's "Ders Yolu". Nodes
/// unlock in order as the user passes each one's test (≥60%); content
/// (flashcards/quiz sets) is copied into the user's own
/// [CardSetRepository]/[QuizSetRepository] on first open — with a
/// deterministic id so re-opening reuses the same set — so the existing
/// flip-card/quiz screens work completely unmodified.
class PathDetailScreen extends StatefulWidget {
  const PathDetailScreen({super.key, required this.subjectKey});

  final String subjectKey;

  @override
  State<PathDetailScreen> createState() => _PathDetailScreenState();
}

class _PathDetailScreenState extends State<PathDetailScreen> {
  final _pathRepository = CurriculumPathRepository();
  final _progressRepository = PathProgressRepository();

  CurriculumPath? _path;
  PathProgress? _progress;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = await _pathRepository.loadPath(widget.subjectKey);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final progress = (path == null || uid == null)
          ? PathProgress(subjectKey: widget.subjectKey, completedNodeIds: const {})
          : await _progressRepository.load(uid, widget.subjectKey);
      if (!mounted) return;
      setState(() {
        _path = path;
        _progress = progress;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ders yolu yüklenemedi. İnternet bağlantını kontrol et.';
        _isLoading = false;
      });
    }
  }

  /// Horizontal offset (in px) for a node's circle, cycling through a
  /// gentle center/right/center/left wave so the path reads more like a
  /// winding map than a flat list, without needing custom path painting.
  static double _staggerFor(int index) {
    const wave = [0.0, 28.0, 0.0, -28.0];
    return wave[index % wave.length];
  }

  String _materializedId(String nodeId, String suffix) =>
      'path_${widget.subjectKey}_${nodeId}_$suffix';

  Future<FlashcardSet> _materializeFlashcards(CurriculumNode node) async {
    final id = _materializedId(node.id, 'flashcards');
    final repository = CardSetRepository();
    final all = await repository.loadAll();
    for (final set in all) {
      if (set.id == id) return set;
    }
    final newSet = FlashcardSet(
      id: id,
      title: '${node.title} - Kartlar',
      createdAt: DateTime.now(),
      cards: node.flashcards,
    );
    await repository.saveAll([newSet, ...all]);
    return newSet;
  }

  Future<QuizSet> _materializeQuiz(CurriculumNode node, _ContentKind kind) async {
    final suffix = kind == _ContentKind.multipleChoice
        ? 'mc'
        : kind == _ContentKind.fillBlank
        ? 'fillblank'
        : 'truefalse';
    final id = _materializedId(node.id, suffix);
    final repository = QuizSetRepository();
    final all = await repository.loadAll();
    for (final set in all) {
      if (set.id == id) return set;
    }
    final List<QuizQuestion> questions = kind == _ContentKind.multipleChoice
        ? node.multipleChoice
        : kind == _ContentKind.fillBlank
        ? node.fillBlank
        : node.trueFalse;
    final newSet = QuizSet(
      id: id,
      title: '${node.title} - ${kind.setFormat.shortLabel}',
      createdAt: DateTime.now(),
      questions: questions,
    );
    await repository.saveAll([newSet, ...all]);
    return newSet;
  }

  /// After a quiz screen returns, re-reads that materialized set's own
  /// (already-persisted) latest attempt and reuses its score — no quiz
  /// grading logic is duplicated here.
  Future<void> _refreshCompletionAfterQuiz(String quizSetId, String nodeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final all = await QuizSetRepository().loadAll();
    QuizSet? updated;
    for (final set in all) {
      if (set.id == quizSetId) {
        updated = set;
        break;
      }
    }
    if (updated == null || updated.attempts.isEmpty) return;
    final last = updated.attempts.last;
    if (last.totalCount == 0) return;
    if (last.correctCount / last.totalCount < 0.6) return;

    await _progressRepository.markNodeCompleted(uid, widget.subjectKey, nodeId);
    final progress = await _progressRepository.load(uid, widget.subjectKey);
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  Future<void> _openContent(CurriculumNode node, _ContentKind kind) async {
    if (kind == _ContentKind.flashcards) {
      final set = await _materializeFlashcards(node);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => CardSetDetailScreen(cardSet: set)),
      );
      return;
    }
    final set = await _materializeQuiz(node, kind);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => QuizSetScreen(quizSet: set)),
    );
    await _refreshCompletionAfterQuiz(set.id, node.id);
  }

  Future<void> _openNodeSheet(CurriculumNode node) async {
    final items = [
      if (node.flashcards.isNotEmpty)
        (kind: _ContentKind.flashcards, count: node.flashcards.length),
      if (node.multipleChoice.isNotEmpty)
        (kind: _ContentKind.multipleChoice, count: node.multipleChoice.length),
      if (node.fillBlank.isNotEmpty)
        (kind: _ContentKind.fillBlank, count: node.fillBlank.length),
      if (node.trueFalse.isNotEmpty)
        (kind: _ContentKind.trueFalse, count: node.trueFalse.length),
    ];
    if (items.isEmpty) return;
    final kind = await showModalBottomSheet<_ContentKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                node.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(item.kind.setFormat.icon),
                title: Text(item.kind.setFormat.shortLabel),
                trailing: Text('${item.count} adet'),
                onTap: () => Navigator.of(context).pop(item.kind),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    await _openContent(node, kind);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_path?.title ?? 'Ders Yolu')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }
    final path = _path;
    if (path == null) {
      return const Center(child: Text('Bu ders için henüz bir yol yok.'));
    }

    final allNodes = path.allNodes;
    var flatIndex = 0;
    final children = <Widget>[];
    for (var unitIndex = 0; unitIndex < path.units.length; unitIndex++) {
      final unit = path.units[unitIndex];
      children.add(_UnitHeader(unit: unit));
      if (unit.isComingSoon) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      for (var i = 0; i < unit.nodes.length; i++) {
        final node = unit.nodes[i];
        final index = flatIndex;
        final isCompleted = _progress?.isCompleted(node.id) ?? false;
        final isUnlocked = index == 0 || (_progress?.isCompleted(allNodes[index - 1].id) ?? false);
        final isLast = index == allNodes.length - 1;
        children.add(
          _NodeTile(
            node: node,
            isCompleted: isCompleted,
            isUnlocked: isUnlocked,
            isLast: isLast,
            stagger: _staggerFor(index),
            onTap: () {
              if (!isUnlocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Önce bir önceki konuyu tamamlamalısın.'),
                  ),
                );
                return;
              }
              _openNodeSheet(node);
            },
          ),
        );
        flatIndex++;
      }
      children.add(const SizedBox(height: 12));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }
}

class _UnitHeader extends StatelessWidget {
  const _UnitHeader({required this.unit});

  final CurriculumUnit unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ünite ${unit.order}: ${unit.title}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: unit.isComingSoon ? colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          if (unit.isComingSoon) ...[
            const SizedBox(width: 8),
            Icon(Icons.lock_outline, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Yakında',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.isCompleted,
    required this.isUnlocked,
    required this.isLast,
    required this.stagger,
    required this.onTap,
  });

  final CurriculumNode node;
  final bool isCompleted;
  final bool isUnlocked;
  final bool isLast;

  /// Horizontal px offset for this node's circle — see
  /// [_PathDetailScreenState._staggerFor].
  final double stagger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final circleColor = isCompleted
        ? Colors.green
        : isUnlocked
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final iconColor = isCompleted || isUnlocked
        ? Colors.white
        : colorScheme.onSurfaceVariant;
    // The connector below a completed node reads as "already traveled",
    // so it's colored the same as the completed state.
    final lineColor = isCompleted ? Colors.green : colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  // Fixed-width slot so the circle can wander left/right
                  // (a wave, like a winding path) without ever overlapping
                  // the title text that follows in the row — the spine
                  // line below stays centered in this same slot.
                  SizedBox(
                    width: 76,
                    child: Align(
                      alignment: Alignment(stagger / 28, 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: isUnlocked && !isCompleted
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              )
                            : null,
                        child: CircleAvatar(
                          radius: isUnlocked && !isCompleted ? 24 : 22,
                          backgroundColor: circleColor,
                          child: isCompleted
                              ? Icon(Icons.check, color: iconColor)
                              : isUnlocked
                              ? Text(
                                  '${node.order}',
                                  style: TextStyle(
                                    color: iconColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Icon(Icons.lock_outline, color: iconColor, size: 18),
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: lineColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isUnlocked ? null : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '~${node.estimatedMinutes} dk',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
