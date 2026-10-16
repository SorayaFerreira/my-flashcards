import 'dart:collection';
import 'dart:math';

import 'models/flashcard.dart';

/// The least reviewed cards come first; cards with the same count are
/// shuffled among themselves.
List<Flashcard> orderForReview(Iterable<Flashcard> cards, Random random) {
  final byCount = SplayTreeMap<int, List<Flashcard>>();
  for (final card in cards) {
    byCount.putIfAbsent(card.reviewCount, () => []).add(card);
  }
  return [for (final group in byCount.values) ...(group..shuffle(random))];
}
