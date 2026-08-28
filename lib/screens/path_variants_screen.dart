import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/screens/path_detail_screen.dart';
import 'package:ogrenme_asistani/services/curriculum_path_repository.dart';

/// Level 3 (leaf) of the "Ders Yolları" hierarchy — the individual
/// exam-scoped path variants for one ders (e.g. "TYT Biyoloji"/"AYT
/// Biyoloji" under YKS -> Biyoloji). A variant with no content yet
/// ([hasContent] `false`, e.g. a seeded placeholder) shows locked/
/// "Yakında" instead of opening — same convention as an empty
/// [CurriculumUnit] on the unit list itself. Tapping an available one
/// opens its [PathDetailScreen].
class PathVariantsScreen extends StatefulWidget {
  const PathVariantsScreen({
    super.key,
    required this.examType,
    required this.subject,
  });

  final String examType;
  final String subject;

  @override
  State<PathVariantsScreen> createState() => _PathVariantsScreenState();
}

class _PathVariantsScreenState extends State<PathVariantsScreen> {
  final _repository = CurriculumPathRepository();
  List<({String subjectKey, String title, bool hasContent})> _variants = [];
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
      final variants =
          paths
              .where(
                (p) => p.examType == widget.examType && p.subject == widget.subject,
              )
              .map(
                (p) => (
                  subjectKey: p.subjectKey,
                  title: p.title,
                  hasContent: p.hasContent,
                ),
              )
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));
      setState(() {
        _variants = variants;
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
      appBar: AppBar(title: Text(widget.subject)),
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
    if (_variants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Henüz bir ders yolu eklenmedi.', textAlign: TextAlign.center),
        ),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _variants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final variant = _variants[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.route_outlined)),
            title: Text(variant.title),
            trailing: variant.hasContent
                ? const Icon(Icons.chevron_right)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Yakında',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
            onTap: variant.hasContent
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PathDetailScreen(subjectKey: variant.subjectKey),
                      ),
                    );
                  }
                : null,
          ),
        );
      },
    );
  }
}
