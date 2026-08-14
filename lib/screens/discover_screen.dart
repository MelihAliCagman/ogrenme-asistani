import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/sample_lesson.dart';
import 'package:ogrenme_asistani/screens/discover_lesson_detail_screen.dart';
import 'package:ogrenme_asistani/services/sample_lesson_repository.dart';

/// The Keşfet content (search + sample lesson list), extracted so it can
/// be embedded inside the Dersler screen's "Keşfet" tab without its own
/// Scaffold/AppBar.
class DiscoverBody extends StatefulWidget {
  const DiscoverBody({super.key});

  @override
  State<DiscoverBody> createState() => _DiscoverBodyState();
}

class _DiscoverBodyState extends State<DiscoverBody> {
  final _repository = SampleLessonRepository();
  final _searchController = TextEditingController();
  List<SampleLesson> _lessons = [];
  String _query = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SampleLesson> get _filteredLessons {
    if (_query.isEmpty) return _lessons;
    return _lessons
        .where((lesson) => lesson.title.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _load() async {
    try {
      final lessons = await _repository.loadAll();
      if (!mounted) return;
      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Örnek dersler yüklenemedi. İnternet bağlantını kontrol et.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Ders veya sınav ara (ör. KPSS)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _searchController.clear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              setState(() => _isLoading = true);
              return _load();
            },
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }
    if (_lessons.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Henüz örnek ders yok.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }
    final lessons = _filteredLessons;
    if (lessons.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              '"$_query" ile eşleşen ders bulunamadı.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_query.isEmpty) ...[
          Text(
            'Hazır ders paketleriyle yeni bir konuyu hemen keşfetmeye başla — '
            'beğendiğini kendi derslerine ekleyip çalışmaya devam edebilirsin.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
        ],
        for (final lesson in lessons)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: lesson.color,
                child: Icon(SampleLesson.icon, color: Colors.white),
              ),
              title: Text(lesson.title),
              subtitle: Text(
                '${lesson.totalFlashcards} kart · ${lesson.totalQuizQuestions} soru · 3 zorluk seviyesi',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        DiscoverLessonDetailScreen(lesson: lesson),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
