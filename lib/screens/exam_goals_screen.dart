import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/exam_goal.dart';
import 'package:ogrenme_asistani/services/exam_goal_repository.dart';

/// Lists the user's exam goals ("Hedeflerim") with add/edit/delete,
/// reached from a tappable row on the Profil screen.
class ExamGoalsScreen extends StatefulWidget {
  const ExamGoalsScreen({super.key});

  @override
  State<ExamGoalsScreen> createState() => _ExamGoalsScreenState();
}

class _ExamGoalsScreenState extends State<ExamGoalsScreen> {
  final _repository = ExamGoalRepository();
  List<ExamGoal> _goals = [];
  StreamSubscription<List<ExamGoal>>? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _watchGoals();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _watchGoals() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    _subscription = _repository.watchAll(uid).listen((goals) {
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    });
  }

  Future<void> _addGoal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final result = await showModalBottomSheet<_GoalFormResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _GoalFormSheet(),
    );
    if (result == null) return;
    await _repository.createGoal(
      uid,
      name: result.name,
      date: result.date,
      targetScore: result.targetScore,
    );
  }

  Future<void> _editGoal(ExamGoal goal) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final result = await showModalBottomSheet<_GoalFormResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _GoalFormSheet(initial: goal),
    );
    if (result == null) return;
    await _repository.updateGoal(
      uid,
      goal.id,
      name: result.name,
      date: result.date,
      targetScore: result.targetScore,
    );
  }

  Future<void> _deleteGoal(ExamGoal goal) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hedefi sil'),
        content: Text('"${goal.name}" hedefini silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteGoal(uid, goal.id);
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  int _daysUntil(DateTime date) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return targetDate.difference(todayDate).inDays;
  }

  String _countdownLabel(int days) {
    if (days > 0) return '$days gün kaldı';
    if (days == 0) return 'Bugün!';
    return '${-days} gün önce geçti';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hedeflerim')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henüz bir sınav hedefin yok. "+" ile ilk hedefini ekle (ör. '
            '"KPSS 2027").',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final goal = _goals[index];
        final days = _daysUntil(goal.date);
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: days < 0
                  ? Theme.of(context).colorScheme.surfaceContainerHigh
                  : Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.flag_outlined),
            ),
            title: Text(goal.name),
            subtitle: Text(
              '${_dateLabel(goal.date)} · ${_countdownLabel(days)}'
              '${goal.targetScore == null ? '' : ' · Hedef: ${goal.targetScore}'}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editGoal(goal);
                if (value == 'delete') _deleteGoal(goal);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoalFormResult {
  _GoalFormResult(this.name, this.date, this.targetScore);

  final String name;
  final DateTime date;
  final double? targetScore;
}

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({this.initial});

  final ExamGoal? initial;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final _scoreController = TextEditingController(
    text: widget.initial?.targetScore?.toString() ?? '',
  );
  late DateTime _date = widget.initial?.date ?? DateTime.now();

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final scoreText = _scoreController.text.trim();
    final targetScore = scoreText.isEmpty ? null : double.tryParse(scoreText);
    Navigator.of(context).pop(_GoalFormResult(name, _date, targetScore));
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Hedefi Düzenle' : 'Hedef Ekle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              decoration: const InputDecoration(
                labelText: 'Hedef adı (ör. KPSS 2027)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tarih',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dateLabel(_date)),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hedef puan (opsiyonel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Kaydet' : 'Ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
