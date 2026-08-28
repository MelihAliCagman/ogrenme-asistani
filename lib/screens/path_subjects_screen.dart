import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/screens/path_exam_subjects_screen.dart';
import 'package:ogrenme_asistani/services/curriculum_path_repository.dart';

/// Top level of the "Ders Yolları" hierarchy — reached from the Ana
/// Sayfa "Ders Yolları" entry. Lists the distinct exam types (e.g. "YKS")
/// found across every seeded [CurriculumPathRepository.loadAvailablePaths]
/// entry; tapping one drills into [PathExamSubjectsScreen] for that exam
/// type's ders list. Purely data-derived — a newly seeded path with a new
/// `examType` shows up here with no app code change.
class PathSubjectsScreen extends StatefulWidget {
  const PathSubjectsScreen({super.key});

  @override
  State<PathSubjectsScreen> createState() => _PathSubjectsScreenState();
}

class _PathSubjectsScreenState extends State<PathSubjectsScreen> {
  final _repository = CurriculumPathRepository();
  List<String> _examTypes = [];
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
      final examTypes = paths.map((p) => p.examType).where((e) => e.isNotEmpty).toSet().toList()
        ..sort();
      setState(() {
        _examTypes = examTypes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ders yolları yüklenemedi. İnternet bağlantını kontrol et.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ders Yolları')),
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
    if (_examTypes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Henüz bir ders yolu eklenmedi.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _examTypes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final examType = _examTypes[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.school_outlined)),
            title: Text(examType),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PathExamSubjectsScreen(examType: examType),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
