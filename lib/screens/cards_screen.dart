import 'package:flutter/material.dart';
import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/screens/card_set_detail_screen.dart';
import 'package:ogrenme_asistani/services/card_set_repository.dart';
import 'package:ogrenme_asistani/services/gemini_service.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final CardSetRepository _repository = CardSetRepository();
  List<FlashcardSet> _cardSets = [];
  bool _isLoading = false;
  bool _isLoadingSets = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    final sets = await _repository.loadAll();
    if (!mounted) return;
    setState(() {
      _cardSets = sets;
      _isLoadingSets = false;
    });
  }

  Future<void> _generateCards() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _geminiService.generateFlashcards(text);
      final newSet = FlashcardSet(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: result.title,
        createdAt: DateTime.now(),
        cards: result.cards,
      );
      if (!mounted) return;
      setState(() {
        _cardSets = [newSet, ..._cardSets];
        _controller.clear();
      });
      await _repository.saveAll(_cardSets);
    } catch (e) {
      debugPrint('[CardsScreen] Kart oluşturma başarısız: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Kartlar oluşturulamadı. Lütfen internet bağlantını kontrol edip tekrar dener misin?';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteSet(FlashcardSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seti sil'),
        content: Text('"${set.title}" setini silmek istediğine emin misin?'),
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

    setState(() {
      _cardSets = _cardSets.where((s) => s.id != set.id).toList();
    });
    await _repository.saveAll(_cardSets);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kartlarım')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ders notunu veya metni buraya yapıştır...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isLoading ? null : _generateCards,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isLoading ? 'Kartlar oluşturuluyor...' : 'Kart Oluştur',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(child: _buildSetList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSetList() {
    if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cardSets.isEmpty) {
      return Center(
        child: Text(
          'Henüz kart seti yok. Bir metin yapıştırıp "Kart Oluştur"a bas.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      itemCount: _cardSets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final set = _cardSets[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.style),
            title: Text('${set.title} - ${set.cards.length} kart'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Seti sil',
              onPressed: () => _deleteSet(set),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CardSetDetailScreen(cardSet: set),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
