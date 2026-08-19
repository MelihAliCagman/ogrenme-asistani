import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/screens/path_detail_screen.dart';
import 'package:ogrenme_asistani/services/curriculum_path_repository.dart';

/// Lists the seeded "Ders Yolu" (skill path) subjects — reached from the
/// Ana Sayfa "Ders Yolları" entry. Tapping one opens its [PathDetailScreen].
class PathSubjectsScreen extends StatefulWidget {
  const PathSubjectsScreen({super.key});

  @override
  State<PathSubjectsScreen> createState() => _PathSubjectsScreenState();
}

class _PathSubjectsScreenState extends State<PathSubjectsScreen> {
  final _repository = CurriculumPathRepository();
  List<({String subjectKey, String title})> _paths = [];
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
      setState(() {
        _paths = paths;
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
    if (_paths.isEmpty) {
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
      itemCount: _paths.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final path = _paths[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.route_outlined)),
            title: Text(path.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      PathDetailScreen(subjectKey: path.subjectKey),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
