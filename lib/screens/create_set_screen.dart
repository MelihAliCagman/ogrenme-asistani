import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/models/quiz_question.dart';
import 'package:ogrenme_asistani/models/quiz_set.dart';
import 'package:ogrenme_asistani/models/set_format.dart';
import 'package:ogrenme_asistani/models/subject.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/gemini_service.dart';
import 'package:ogrenme_asistani/services/quiz_set_repository.dart';
import 'package:ogrenme_asistani/services/subject_repository.dart';
import 'package:ogrenme_asistani/widgets/subject_picker.dart';

/// Standalone creation flow for a flashcard or quiz (multiple choice,
/// fill-blank or true/false) set, opened from the "+ Kart Oluştur" /
/// "+ Test Oluştur" buttons on the Setlerim list. Pops with `true` when
/// a set was successfully created so the caller can refresh its list.
class CreateSetScreen extends StatefulWidget {
  const CreateSetScreen({super.key, required this.format});

  /// The initial format. When it's a quiz format, the user can still
  /// switch between the three quiz sub-types inside this screen.
  final SetFormat format;

  @override
  State<CreateSetScreen> createState() => _CreateSetScreenState();
}

class _CreateSetScreenState extends State<CreateSetScreen> {
  static const _maxFileSizeBytes = 10 * 1024 * 1024;
  static const _quizFormats = [
    SetFormat.multipleChoice,
    SetFormat.fillBlank,
    SetFormat.trueFalse,
  ];

  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final CardSetRepository _cardSetRepository = CardSetRepository();
  final QuizSetRepository _quizSetRepository = QuizSetRepository();
  final SubjectRepository _subjectRepository = SubjectRepository();

  List<Subject> _subjects = [];
  StreamSubscription<List<Subject>>? _subjectsSubscription;
  String? _selectedSubjectId;
  SetDifficulty _difficulty = SetDifficulty.aiDecide;
  int _count = 10;
  late SetFormat _format = widget.format;

  bool _isLoading = false;
  String? _errorMessage;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;

  bool get _isQuiz => _format.isQuiz;

  @override
  void initState() {
    super.initState();
    _watchSubjects();
  }

  void _watchSubjects() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _subjectsSubscription = _subjectRepository.watchAll(uid).listen((
      subjects,
    ) {
      if (!mounted) return;
      setState(() => _subjects = subjects);
    });
  }

  Subject? _subjectFor(String? subjectId) {
    if (subjectId == null) return null;
    for (final subject in _subjects) {
      if (subject.id == subjectId) return subject;
    }
    return null;
  }

  Future<void> _pickSubject() async {
    final subjectId = await pickSubject(
      context,
      subjects: _subjects,
      currentSubjectId: _selectedSubjectId,
    );
    if (subjectId == null || !mounted) return;
    setState(() {
      _selectedSubjectId = subjectId == noSubjectPicked ? null : subjectId;
    });
  }

  Future<void> _pickFile() async {
    setState(() => _errorMessage = null);
    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
    } catch (e) {
      debugPrint('[CreateSetScreen] Dosya seçilemedi: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Dosya seçilirken bir sorun oluştu. Lütfen tekrar dene.';
      });
      return;
    }
    if (file == null) return;

    Uint8List bytes;
    try {
      final size = await file.length();
      if (size > _maxFileSizeBytes) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Dosya boyutu 10 MB sınırını aşıyor. Lütfen daha küçük bir PDF seç.';
        });
        return;
      }
      bytes = await file.readAsBytes();
    } catch (e) {
      debugPrint('[CreateSetScreen] Dosya okunamadı: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Dosya okunamadı. Lütfen tekrar dener misin?';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedFileBytes = bytes;
      _selectedFileName = file!.name;
    });
  }

  void _removeSelectedFile() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = null;
    });
  }

  Future<void> _create() async {
    final text = _controller.text.trim();
    final fileBytes = _selectedFileBytes;
    if (text.isEmpty && fileBytes == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_format == SetFormat.flashcards) {
        final result = await _geminiService.generateFlashcards(
          sourceText: text.isEmpty ? null : text,
          fileBytes: fileBytes,
          fileMimeType: fileBytes == null ? null : 'application/pdf',
          cardCount: _count,
          difficultyInstruction: _difficulty.promptInstruction,
        );
        final sets = await _cardSetRepository.loadAll();
        final newSet = FlashcardSet(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: result.title,
          createdAt: DateTime.now(),
          cards: result.cards,
          subjectId: _selectedSubjectId,
        );
        await _cardSetRepository.saveAll([newSet, ...sets]);
      } else {
        final result = await _generateQuizQuestions(text, fileBytes);
        final sets = await _quizSetRepository.loadAll();
        final newSet = QuizSet(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: result.title,
          createdAt: DateTime.now(),
          questions: result.questions,
          subjectId: _selectedSubjectId,
        );
        await _quizSetRepository.saveAll([newSet, ...sets]);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[CreateSetScreen] Oluşturma başarısız: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Oluşturulamadı. Lütfen internet bağlantını kontrol edip tekrar dener misin?';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<({String title, List<QuizQuestion> questions})> _generateQuizQuestions(
    String text,
    Uint8List? fileBytes,
  ) {
    final fileMimeType = fileBytes == null ? null : 'application/pdf';
    switch (_format) {
      case SetFormat.fillBlank:
        return _geminiService.generateFillBlankQuestions(
          sourceText: text.isEmpty ? null : text,
          fileBytes: fileBytes,
          fileMimeType: fileMimeType,
          questionCount: _count,
          difficultyInstruction: _difficulty.promptInstruction,
        );
      case SetFormat.trueFalse:
        return _geminiService.generateTrueFalseQuestions(
          sourceText: text.isEmpty ? null : text,
          fileBytes: fileBytes,
          fileMimeType: fileMimeType,
          questionCount: _count,
          difficultyInstruction: _difficulty.promptInstruction,
        );
      case SetFormat.multipleChoice:
      case SetFormat.flashcards:
        return _geminiService.generateQuiz(
          sourceText: text.isEmpty ? null : text,
          fileBytes: fileBytes,
          fileMimeType: fileMimeType,
          questionCount: _count,
          difficultyInstruction: _difficulty.promptInstruction,
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = _isQuiz ? const [10, 15, 20] : const [5, 10, 15, 20];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isQuiz ? 'Test Oluştur' : 'Kart Oluştur'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isQuiz) ...[
              Text(
                'Soru tipi',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quizFormats.map((format) {
                  return ChoiceChip(
                    label: Text(format.label),
                    selected: _format == format,
                    onSelected: (_) => setState(() => _format = format),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Dosya Yükle (PDF)'),
                ),
              ],
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(
                    'Seçilen dosya: $_selectedFileName',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: _isLoading ? null : _removeSelectedFile,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 3,
              decoration: InputDecoration(
                hintText: _selectedFileBytes == null
                    ? 'Ders notunu veya metni buraya yapıştır...'
                    : 'İsteğe bağlı ek talimat yaz (örn. "sadece 2. üniteye '
                          'odaklan")',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isQuiz ? 'Soru sayısı' : 'Kart sayısı',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  for (final c in counts)
                    ButtonSegment(value: c, label: Text('$c')),
                ],
                selected: {_count},
                onSelectionChanged: (selection) {
                  setState(() => _count = selection.first);
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Zorluk seviyesi',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SetDifficulty.values.map((difficulty) {
                return ChoiceChip(
                  label: Text(difficulty.label),
                  selected: _difficulty == difficulty,
                  onSelected: (_) => setState(() => _difficulty = difficulty),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _pickSubject,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _subjectFor(_selectedSubjectId)?.name ??
                          'Ders seç (opsiyonel)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isLoading ? null : _create,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading
                    ? 'Oluşturuluyor...'
                    : _isQuiz
                    ? 'Test Oluştur'
                    : 'Kart Oluştur',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
