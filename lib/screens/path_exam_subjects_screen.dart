import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/screens/path_variants_screen.dart';
import 'package:ogrenme_asistani/services/curriculum_path_repository.dart';

/// Level 2 of the "Ders Yolları" hierarchy — the ders list for one exam
/// type (e.g. "Biyoloji" under "YKS"). Tapping a ders drills into
/// [PathVariantsScreen] for its exam-scoped path variants (e.g. "TYT
/// Biyoloji" / "AYT Biyoloji"). Purely data-derived from
/// [CurriculumPathRepository.loadAvailablePaths], grouped by `subject`.
class PathExamSubjectsScreen extends StatefulWidget {
  const PathExamSubjectsScreen({super.key, required this.examType});

  final String examType;

  @override
  State<PathExamSubjectsScreen> createState() => _PathExamSubjectsScreenState();
}

class _PathExamSubjectsScreenState extends State<PathExamSubjectsScreen> {
  final _repository = CurriculumPathRepository();
  List<String> _subjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final paths = await _repository.loadAvailablePaths();
      if (!mounted) return;
      final subjects = paths
          .where((p) => p.examType == widget.examType)
          .map((p) => p.subject)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Dersler yüklenemedi. İnternet bağlantını kontrol et.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.examType)),
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
    if (_subjects.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Henüz bir ders eklenmedi.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
            title: Text(subject),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PathVariantsScreen(
                    examType: widget.examType,
                    subject: subject,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
