import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/backup_manifest.dart';

void main() {
  final manifest = BackupManifest(
    app: BackupManifest.appId,
    formatVersion: BackupManifest.currentFormatVersion,
    schemaVersion: 1,
    exportedAt: DateTime(2026, 10, 12, 20, 15),
    decks: 3,
    cards: 87,
  );

  test('vai para JSON e volta igual', () {
    final json = jsonDecode(jsonEncode(manifest.toJson()));

    final back = BackupManifest.fromJson(json);

    expect(back.app, 'my_flashcards');
    expect(back.exportedAt, manifest.exportedAt);
    expect(back.decks, 3);
    expect(back.cards, 87);
  });

  test('JSON sem os campos certos lança FormatException', () {
    expect(
      () => BackupManifest.fromJson({'app': 'my_flashcards'}),
      throwsFormatException,
    );
    expect(() => BackupManifest.fromJson([1, 2]), throwsFormatException);
    expect(
      () => BackupManifest.fromJson({...manifest.toJson(), 'decks': 'três'}),
      throwsFormatException,
    );
  });
}
