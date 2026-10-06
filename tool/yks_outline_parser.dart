// Parser for tool/yks_outline.txt (ders > ünite > konu), shared by the
// outline seeder and the content generator.
//
// Format:
//   @anahtar|Ders adı        starts a ders path (key starts with tyt_/ayt_/ydt_)
//   # Ünite adı              starts a unit
//   Konu 1|Konu 2|Konu 3     the topics of the unit above
// Lines starting with "#" before the first "@" are comments.

class OutlinePath {
  OutlinePath(this.key, this.subject);

  final String key;
  final String subject;
  final List<({String title, List<String> topics})> units = [];

  /// "TYT", "AYT" or "YDT".
  String get stage => key.split('_').first.toUpperCase();
  String get title => '$stage $subject';
  int get nodeCount => units.fold(0, (sum, u) => sum + u.topics.length);
}

List<OutlinePath> parseOutline(String text) {
  final paths = <OutlinePath>[];
  String? pendingUnit;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('@')) {
      final parts = line.substring(1).split('|');
      paths.add(OutlinePath(parts[0].trim(), parts[1].trim()));
      pendingUnit = null;
    } else if (line.startsWith('#')) {
      if (paths.isEmpty) continue; // header comment
      pendingUnit = line.substring(1).trim();
    } else if (pendingUnit != null && paths.isNotEmpty) {
      final topics = line
          .split('|')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      paths.last.units.add((title: pendingUnit, topics: topics));
      pendingUnit = null;
    }
  }
  return paths;
}
