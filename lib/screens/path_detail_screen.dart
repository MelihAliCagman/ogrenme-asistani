import 'dart:math' as math;

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

/// The Duolingo-style unit/node map for one subject's "Ders Yolu". Each
/// node tracks completion per content kind (see [PathContentKind]) and
/// unlocks the next node once every kind it has content for is done —
/// content (flashcards/quiz sets) is copied into the user's own
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
          ? PathProgress(subjectKey: widget.subjectKey, nodeProgress: const {})
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

  /// Horizontal px offset for a node's circle, alternating left/right so
  /// the path reads as a gentle zigzag instead of a flat vertical list.
  static double _staggerFor(int index) => index.isEven ? 16.0 : -16.0;

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

  Future<QuizSet> _materializeQuiz(CurriculumNode node, PathContentKind kind) async {
    final suffix = switch (kind) {
      PathContentKind.multipleChoice => 'mc',
      PathContentKind.fillBlank => 'fillblank',
      PathContentKind.trueFalse => 'truefalse',
      PathContentKind.flashcards =>
        throw ArgumentError('flashcards has no quiz set'),
    };
    final id = _materializedId(node.id, suffix);
    final repository = QuizSetRepository();
    final all = await repository.loadAll();
    for (final set in all) {
      if (set.id == id) return set;
    }
    final List<QuizQuestion> questions = switch (kind) {
      PathContentKind.multipleChoice => node.multipleChoice,
      PathContentKind.fillBlank => node.fillBlank,
      PathContentKind.trueFalse => node.trueFalse,
      PathContentKind.flashcards =>
        throw ArgumentError('flashcards has no quiz set'),
    };
    final newSet = QuizSet(
      id: id,
      title: '${node.title} - ${kind.setFormat.shortLabel}',
      createdAt: DateTime.now(),
      questions: questions,
    );
    await repository.saveAll([newSet, ...all]);
    return newSet;
  }

  /// Marks one content kind of one node as completed and reloads
  /// progress so the ring/lock state on screen reflects it immediately.
  /// No minimum score is required — reaching the end of the set (or, for
  /// flashcards, reviewing every card) is enough.
  Future<void> _markKindCompleted(CurriculumNode node, PathContentKind kind) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _progressRepository.markContentCompleted(
      uid,
      widget.subjectKey,
      node.id,
      kind,
    );
    final progress = await _progressRepository.load(uid, widget.subjectKey);
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  Future<void> _openContent(CurriculumNode node, PathContentKind kind) async {
    if (kind == PathContentKind.flashcards) {
      final set = await _materializeFlashcards(node);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CardSetDetailScreen(
            cardSet: set,
            onAllCardsReviewed: () => _markKindCompleted(node, kind),
          ),
        ),
      );
      return;
    }
    final set = await _materializeQuiz(node, kind);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizSetScreen(
          quizSet: set,
          onFinished: () => _markKindCompleted(node, kind),
        ),
      ),
    );
  }

  Future<void> _openNodeSheet(CurriculumNode node) async {
    final progress = _progress?.progressFor(node.id) ?? const NodeProgress();
    final kind = await showModalBottomSheet<PathContentKind>(
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
            for (final contentKind in PathContentKind.values)
              _ContentKindTile(
                kind: contentKind,
                available: node.hasContent(contentKind),
                completed: progress.isKindCompleted(contentKind),
                onTap: node.hasContent(contentKind)
                    ? () => Navigator.of(context).pop(contentKind)
                    : null,
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

    final progress = _progress;
    final allNodes = path.allNodes;
    var flatIndex = 0;
    final children = <Widget>[];
    for (var unitIndex = 0; unitIndex < path.units.length; unitIndex++) {
      final unit = path.units[unitIndex];
      children.add(_UnitBanner(unit: unit));
      children.add(const SizedBox(height: 12));
      if (unit.isComingSoon) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      for (var i = 0; i < unit.nodes.length; i++) {
        final node = unit.nodes[i];
        final index = flatIndex;
        final isCompleted = progress?.isNodeCompleted(node) ?? false;
        final isUnlocked =
            index == 0 || (progress?.isNodeCompleted(allNodes[index - 1]) ?? false);
        final isLast = index == allNodes.length - 1;
        children.add(
          _NodeTile(
            node: node,
            progress: progress?.progressFor(node.id),
            isCompleted: isCompleted,
            isUnlocked: isUnlocked,
            isLast: isLast,
            stagger: _staggerFor(index),
            nextStagger: isLast ? null : _staggerFor(index + 1),
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
      children.add(const SizedBox(height: 20));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: children,
    );
  }
}

/// Vertically stacked "BÖLÜM {order}: {title}" banner above each unit's
/// nodes — colored/highlighted for available units, muted for
/// [CurriculumUnit.isComingSoon] ones.
class _UnitBanner extends StatelessWidget {
  const _UnitBanner({required this.unit});

  final CurriculumUnit unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isComingSoon = unit.isComingSoon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isComingSoon
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'BÖLÜM ${unit.order}: ${unit.title}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: isComingSoon
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          if (isComingSoon) ...[
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
    required this.progress,
    required this.isCompleted,
    required this.isUnlocked,
    required this.isLast,
    required this.stagger,
    required this.nextStagger,
    required this.onTap,
  });

  final CurriculumNode node;
  final NodeProgress? progress;
  final bool isCompleted;
  final bool isUnlocked;
  final bool isLast;

  /// Horizontal px offset for this node's circle — see
  /// [_PathDetailScreenState._staggerFor]. `null` on [nextStagger] for
  /// the very last node (no connector drawn below it).
  final double stagger;
  final double? nextStagger;
  final VoidCallback onTap;

  static const double _slotWidth = 92;
  static const double _ringDiameter = 60;

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

    final filled = isUnlocked
        ? PathContentKind.values
              .map((kind) => !node.hasContent(kind) || (progress?.isKindCompleted(kind) ?? false))
              .toList()
        : const [false, false, false, false];

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
                  // (a zigzag) without ever overlapping the title text
                  // that follows in the row — the connector below stays
                  // anchored to the same exact pixel offset via
                  // Transform.translate, so it lines up with the circle.
                  SizedBox(
                    width: _slotWidth,
                    child: Transform.translate(
                      offset: Offset(stagger, 0),
                      child: Center(
                        child: _NodeProgressRing(
                          filled: filled,
                          trackColor: colorScheme.outlineVariant,
                          fillColor: Colors.green,
                          diameter: _ringDiameter,
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
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: SizedBox(
                        width: _slotWidth,
                        child: CustomPaint(
                          painter: _DashedConnectorPainter(
                            startX: _slotWidth / 2 + stagger,
                            endX: _slotWidth / 2 + (nextStagger ?? stagger),
                            color: lineColor,
                          ),
                          child: const SizedBox.expand(),
                        ),
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

/// Wraps a node's [CircleAvatar] with a thin 4-slice progress ring — one
/// slice per [PathContentKind], in the same top-clockwise order as
/// [PathContentKind.values] (Hafıza Kartı, Çoktan Seçmeli, Boşluk
/// Doldurma, Doğru/Yanlış) — filled once that kind is completed.
class _NodeProgressRing extends StatelessWidget {
  const _NodeProgressRing({
    required this.filled,
    required this.trackColor,
    required this.fillColor,
    required this.diameter,
    required this.child,
  });

  final List<bool> filled;
  final Color trackColor;
  final Color fillColor;
  final double diameter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(diameter, diameter),
            painter: _ProgressRingPainter(
              filled: filled,
              trackColor: trackColor,
              fillColor: fillColor,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.filled,
    required this.trackColor,
    required this.fillColor,
  });

  final List<bool> filled;
  final Color trackColor;
  final Color fillColor;

  static const _strokeWidth = 3.5;
  static const _gapDegrees = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _strokeWidth / 2,
      _strokeWidth / 2,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );
    const sweep = 90.0 - _gapDegrees;
    for (var i = 0; i < filled.length; i++) {
      final start = -90.0 + i * 90.0 + _gapDegrees / 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = filled[i] ? fillColor : trackColor;
      canvas.drawArc(
        rect,
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    if (oldDelegate.trackColor != trackColor || oldDelegate.fillColor != fillColor) {
      return true;
    }
    for (var i = 0; i < filled.length; i++) {
      if (oldDelegate.filled[i] != filled[i]) return true;
    }
    return false;
  }
}

/// A dashed connector curving between two consecutive nodes' zigzagged
/// x-offsets, instead of a straight vertical line.
class _DashedConnectorPainter extends CustomPainter {
  _DashedConnectorPainter({
    required this.startX,
    required this.endX,
    required this.color,
  });

  final double startX;
  final double endX;
  final Color color;

  static const _dashLength = 5.0;
  static const _gapLength = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(startX, 0)
      ..quadraticBezierTo((startX + endX) / 2, size.height / 2, endX, size.height);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedConnectorPainter oldDelegate) =>
      oldDelegate.startX != startX ||
      oldDelegate.endX != endX ||
      oldDelegate.color != color;
}

/// One row in the node's content-kind bottom sheet — name + a small
/// completed/empty mark, or "İçerik yok" when the node has none of that
/// kind (disabled, no tap).
class _ContentKindTile extends StatelessWidget {
  const _ContentKindTile({
    required this.kind,
    required this.available,
    required this.completed,
    required this.onTap,
  });

  final PathContentKind kind;
  final bool available;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final format = kind.setFormat;
    return ListTile(
      enabled: available,
      leading: Icon(format.icon),
      title: Text(format.shortLabel),
      trailing: !available
          ? Text(
              'İçerik yok',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            )
          : Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: completed ? Colors.green : colorScheme.outlineVariant,
            ),
      onTap: onTap,
    );
  }
}
