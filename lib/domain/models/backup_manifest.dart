/// The `manifest.json` inside a backup, describing what it holds.
class BackupManifest {
  const BackupManifest({
    required this.app,
    required this.formatVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.decks,
    required this.cards,
  });

  static const appId = 'my_flashcards';
  static const currentFormatVersion = 1;

  /// Throws a [FormatException] when [json] is not a manifest.
  factory BackupManifest.fromJson(Object? json) {
    if (json case {
      'app': final String app,
      'formatVersion': final int formatVersion,
      'schemaVersion': final int schemaVersion,
      'exportedAt': final String exportedAt,
      'decks': final int decks,
      'cards': final int cards,
    }) {
      return BackupManifest(
        app: app,
        formatVersion: formatVersion,
        schemaVersion: schemaVersion,
        exportedAt: DateTime.parse(exportedAt),
        decks: decks,
        cards: cards,
      );
    }
    throw const FormatException('Manifesto de backup inválido.');
  }

  final String app;
  final int formatVersion;
  final int schemaVersion;
  final DateTime exportedAt;
  final int decks;
  final int cards;

  Map<String, Object?> toJson() => {
    'app': app,
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'decks': decks,
    'cards': cards,
  };
}
