import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/deck.dart';

void main() {
  group('Deck.validateName', () {
    test('aceita um nome comum', () {
      expect(Deck.validateName('Inglês'), isNull);
    });

    test('aceita espaços nas pontas, porque o nome é aparado', () {
      expect(Deck.validateName('  Inglês  '), isNull);
    });

    test('recusa nome vazio ou só com espaços', () {
      expect(Deck.validateName(''), 'Dê um nome ao deck.');
      expect(Deck.validateName('   '), 'Dê um nome ao deck.');
    });

    test('aceita 50 caracteres e recusa 51', () {
      expect(Deck.validateName('a' * 50), isNull);
      expect(Deck.validateName('a' * 51), 'Use no máximo 50 caracteres.');
    });
  });

  test('dois decks com os mesmos dados são iguais', () {
    final createdAt = DateTime(2026, 10, 12);
    expect(
      Deck(id: 1, name: 'A', createdAt: createdAt, cardCount: 2),
      Deck(id: 1, name: 'A', createdAt: createdAt, cardCount: 2),
    );
  });
}
