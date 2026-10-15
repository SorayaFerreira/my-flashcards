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

  group('Deck.compareByName', () {
    Deck deck(int id, String name) =>
        Deck(id: id, name: name, createdAt: DateTime(2026));

    test('ignora acentos e maiúsculas', () {
      final decks = [deck(1, 'banana'), deck(2, 'Água'), deck(3, 'abacate')]
        ..sort(Deck.compareByName);

      expect(decks.map((d) => d.name), ['abacate', 'Água', 'banana']);
    });

    test('nomes iguais depois de simplificados desempatam pelo id', () {
      expect(
        Deck.compareByName(deck(1, 'época'), deck(2, 'Epoca')),
        lessThan(0),
      );
      expect(
        Deck.compareByName(deck(2, 'época'), deck(1, 'Epoca')),
        greaterThan(0),
      );
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
