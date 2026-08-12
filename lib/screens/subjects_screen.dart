import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/screens/subject_detail_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/chat_session_repository.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final _repository = SubjectRepository();
  final _chatRepository = ChatSessionRepository();
  final _cardSetRepository = CardSetRepository();
  final _quizSetRepository = QuizSetRepository();
  List<Subject> _subjects = [];
  StreamSubscription<List<Subject>>? _subjectsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _watchSubjects();
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  void _watchSubjects() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    _subjectsSubscription = _repository.watchAll(uid).listen((subjects) {
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    });
  }

  Future<void> _addSubject() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final result = await showDialog<_SubjectFormResult>(
      context: context,
      builder: (context) => const _SubjectFormDialog(),
    );
    if (result == null) return;

    await _repository.createSubject(
      uid,
      name: result.name,
      color: result.color,
    );
  }

  Future<void> _editSubject(Subject subject) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final result = await showDialog<_SubjectFormResult>(
      context: context,
      builder: (context) => _SubjectFormDialog(initial: subject),
    );
    if (result == null) return;

    await _repository.updateSubject(
      uid,
      subject.id,
      name: result.name,
      color: result.color,
    );
  }

  Future<void> _deleteSubject(Subject subject) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dersi sil'),
        content: Text(
          '"${subject.name}" dersini silmek istediğine emin misin? '
          'Bu derse bağlı sohbet ve kartlar silinmez, "Genel" grubuna geri döner.',
        ),
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

    await Future.wait([
      _chatRepository.clearSubjectFromChats(uid, subject.id),
      _cardSetRepository.clearSubjectFromSets(subject.id),
      _quizSetRepository.clearSubjectFromSets(subject.id),
    ]);
    await _repository.deleteSubject(uid, subject.id);
  }

  Future<void> _openSubject(Subject subject) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubjectDetailScreen(subject: subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dersler')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addSubject,
                icon: const Icon(Icons.add),
                label: const Text('Ders Ekle'),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henüz ders yok. "Ders Ekle" ile ilk dersini oluştur.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _subjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: subject.color,
              child: Icon(Subject.icon, color: Colors.white),
            ),
            title: Text(subject.name),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editSubject(subject);
                if (value == 'delete') _deleteSubject(subject);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
            onTap: () => _openSubject(subject),
          ),
        );
      },
    );
  }
}

class _SubjectFormResult {
  _SubjectFormResult(this.name, this.color);

  final String name;
  final Color color;
}

class _SubjectFormDialog extends StatefulWidget {
  const _SubjectFormDialog({this.initial});

  final Subject? initial;

  @override
  State<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<_SubjectFormDialog> {
  late final _controller = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late Color _selectedColor =
      widget.initial?.color ?? Subject.defaultColors.first;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectSuggestion(String name) {
    setState(() => _controller.text = name);
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(_SubjectFormResult(name, _selectedColor));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Dersi Düzenle' : 'Ders Ekle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Ders adı',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Subject.suggestions
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      onPressed: () => _selectSuggestion(s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('Renk seç', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: Subject.defaultColors.map((color) {
                final isSelected = color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Kaydet' : 'Ekle'),
        ),
      ],
    );
  }
}
