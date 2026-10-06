import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/config/subject_style.dart';
import 'package:ogrenme_asistani/screens/path_detail_screen.dart';
import 'package:ogrenme_asistani/services/curriculum_path_repository.dart';

/// The YKS müfredat: pick TYT / AYT / YDT, then a ders — every ders opens
/// its unit/topic map ([PathDetailScreen]). Dersler whose questions are not
/// written yet still list their units and topics, marked "Yakında".
///
/// Purely data-derived from [CurriculumPathRepository.loadAvailablePaths],
/// so a newly seeded path shows up here with no app code change.
class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  static const _stages = ['TYT', 'AYT', 'YDT'];

  /// Display order of dersler inside a stage (ders without content comes
  /// after the ones that have it, in this order too).
  static const _subjectOrder = [
    'Türkçe',
    'Matematik',
    'Geometri',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Edebiyat',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'Mantık',
    'Psikoloji',
    'Sosyoloji',
    'Din Kültürü',
    'İngilizce',
  ];

  final _repository = CurriculumPathRepository();
  List<CurriculumPathSummary> _paths = [];
  String _stage = 'TYT';
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
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Müfredat yüklenemedi. İnternet bağlantını kontrol et.';
        _isLoading = false;
      });
    }
  }

  List<CurriculumPathSummary> get _stagePaths {
    final list = _paths.where((p) => p.stage == _stage).toList();
    int rank(CurriculumPathSummary p) {
      final i = _subjectOrder.indexOf(p.subject);
      return i == -1 ? _subjectOrder.length : i;
    }

    list.sort((a, b) {
      if (a.hasContent != b.hasContent) return a.hasContent ? -1 : 1;
      return rank(a).compareTo(rank(b));
    });
    return list;
  }

  void _open(CurriculumPathSummary path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PathDetailScreen(subjectKey: path.subjectKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Müfredat')),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _load();
                },
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    final paths = _stagePaths;
    final units = paths.fold<int>(0, (s, p) => s + p.unitCount);
    final nodes = paths.fold<int>(0, (s, p) => s + p.nodeCount);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'YKS konularını sınav, ders ve ünite ünite takip et.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final s in _stages)
                  ButtonSegment(value: s, label: Text(s)),
              ],
              selected: {_stage},
              onSelectionChanged: (v) => setState(() => _stage = v.first),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatPill(value: '${paths.length}', label: 'Ders')),
              const SizedBox(width: 10),
              Expanded(child: _StatPill(value: '$units', label: 'Ünite')),
              const SizedBox(width: 10),
              Expanded(child: _StatPill(value: '$nodes', label: 'Konu')),
            ],
          ),
          const SizedBox(height: 16),
          if (paths.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Bu sınav için henüz ders eklenmedi.')),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemCount: paths.length,
              itemBuilder: (context, index) => _SubjectCard(
                path: paths[index],
                onTap: () => _open(paths[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.path, required this.onTap});

  final CurriculumPathSummary path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = subjectStyleFor(path.subject);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                style.color.withValues(alpha: isDark ? 0.34 : 0.22),
                style.color.withValues(alpha: isDark ? 0.10 : 0.06),
              ],
            ),
            border: Border.all(color: style.color.withValues(alpha: 0.45)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(style.icon, color: Colors.white, size: 26),
                  ),
                  _StatusDot(ready: path.hasContent),
                ],
              ),
              const Spacer(),
              Text(
                path.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${path.unitCount} ünite · ${path.nodeCount} konu',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ready ? Colors.greenAccent.shade400 : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ready ? 'Hazır' : 'Yakında',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
