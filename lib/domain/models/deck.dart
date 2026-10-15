class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  static const maxNameLength = 50;

  final int id;
  final String name;
  final DateTime createdAt;
  final int cardCount;

  /// The message to show when [rawName] can't be used as a deck name, or null
  /// when it can. The name is checked after trimming.
  static String? validateName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return 'Dê um nome ao deck.';
    if (name.length > maxNameLength) {
      return 'Use no máximo $maxNameLength caracteres.';
    }
    return null;
  }

  /// Alphabetical order that ignores case and Portuguese accents, with [id]
  /// as the tiebreak.
  static int compareByName(Deck a, Deck b) {
    final byName = _fold(a.name).compareTo(_fold(b.name));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  static String _fold(String name) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final rune in name.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index == -1 ? char : to[index]);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Deck &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.cardCount == cardCount;

  @override
  int get hashCode => Object.hash(id, name, createdAt, cardCount);

  @override
  String toString() => 'Deck($id, $name, $cardCount cards)';
}
