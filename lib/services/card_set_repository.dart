import 'package:ogrenme_asistani/models/flashcard_set.dart';
import 'package:ogrenme_asistani/services/json_list_storage.dart';

class CardSetRepository {
  final _storage = JsonListStorage<FlashcardSet>(
    storageKey: 'flashcard_sets',
    fromJson: FlashcardSet.fromJson,
    toJson: (set) => set.toJson(),
    logTag: 'CardSetRepository',
  );

  Future<List<FlashcardSet>> loadAll() => _storage.loadAll();

  Future<void> saveAll(List<FlashcardSet> sets) => _storage.saveAll(sets);
}
