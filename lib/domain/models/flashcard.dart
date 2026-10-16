import 'card_side.dart';

class Flashcard {
  const Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    this.reviewCount = 0,
  });

  final int id;
  final int deckId;
  final CardSide front;
  final CardSide back;
  final int reviewCount;
  final DateTime createdAt;

  CardSide side(Side side) => switch (side) {
    Side.front => front,
    Side.back => back,
  };

  List<String> get fileNames => [...front.fileNames, ...back.fileNames];

  Flashcard copyWith({int? reviewCount}) => Flashcard(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    createdAt: createdAt,
    reviewCount: reviewCount ?? this.reviewCount,
  );

  @override
  bool operator ==(Object other) =>
      other is Flashcard &&
      other.id == id &&
      other.deckId == deckId &&
      other.front == front &&
      other.back == back &&
      other.reviewCount == reviewCount &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, deckId, front, back, reviewCount, createdAt);

  @override
  String toString() => 'Flashcard($id, deck $deckId, $reviewCount revisões)';
}
