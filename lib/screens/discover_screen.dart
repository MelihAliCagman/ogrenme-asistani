import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/sample_lesson.dart';
import 'package:ogrenme_asistani/screens/discover_lesson_detail_screen.dart';
import 'package:ogrenme_asistani/services/sample_lesson_repository.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _repository = SampleLessonRepository();
  List<SampleLesson> _lessons = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Keşfet')),
      body: RefreshIndicator(
        onRefresh: () {
          setState(() => _isLoading = true);
          return _load();
        },
        child: _buildBody(),
      ),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hazır ders paketleriyle yeni bir konuyu hemen keşfetmeye başla — '
          'beğendiğini kendi derslerine ekleyip çalışmaya devam edebilirsin.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        for (final lesson in _lessons)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: lesson.color,
                child: Icon(SampleLesson.icon, color: Colors.white),
              ),
              title: Text(lesson.title),
              subtitle: Text(
                '${lesson.flashcards.length} kart · ${lesson.quizQuestions.length} soru',
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
