import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/domain/models/card_side.dart';
import 'package:my_flashcards/domain/models/flashcard.dart';

void main() {
  group('CardSide', () {
    test('um lado sem nada está vazio', () {
      expect(CardSide.empty.isEmpty, isTrue);
    });

    test('texto só com espaços e quebras de linha conta como vazio', () {
      expect(const CardSide(text: '  \n ').isEmpty, isTrue);
      expect(const CardSide(text: '  \n ').hasText, isFalse);
    });

    test('texto, imagem ou áudio sozinhos já preenchem o lado', () {
      expect(const CardSide(text: 'oi').isEmpty, isFalse);
      expect(const CardSide(image: 'img_1.jpg').isEmpty, isFalse);
      expect(const CardSide(audio: 'aud_1.m4a').isEmpty, isFalse);
    });

    test('fileNames lista só os arquivos que existem', () {
      expect(const CardSide(text: 'oi').fileNames, isEmpty);
      expect(const CardSide(image: 'img_1.jpg', audio: 'aud_1.m4a').fileNames, [
        'img_1.jpg',
        'aud_1.m4a',
      ]);
    });
  });

  group('Flashcard', () {
    final card = Flashcard(
      id: 1,
      deckId: 2,
      front: const CardSide(text: 'to give up', image: 'img_1.jpg'),
      back: const CardSide(text: 'desistir', audio: 'aud_1.m4a'),
      createdAt: DateTime(2026, 10, 12),
    );

    test('side devolve a frente ou o verso', () {
      expect(card.side(Side.front).text, 'to give up');
      expect(card.side(Side.back).text, 'desistir');
    });

    test('fileNames junta os arquivos dos dois lados', () {
      expect(card.fileNames, ['img_1.jpg', 'aud_1.m4a']);
    });

    test('copyWith troca só o contador', () {
      final reviewed = card.copyWith(reviewCount: 5);

      expect(reviewed.reviewCount, 5);
      expect(reviewed.front, card.front);
      expect(reviewed.id, card.id);
    });
  });
}
