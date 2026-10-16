import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../domain/models/deck.dart';
import '../../../domain/models/flashcard.dart';
import '../../../utils/result.dart';
import '../../core/dispose_safe_notifier.dart';

class DeckDetailViewModel extends ChangeNotifier with DisposeSafeNotifier {
  DeckDetailViewModel({
    required this.deckId,
    required this._deckRepository,
    required this._cardRepository,
  });

  static const loadErrorMessage = 'Não foi possível carregar o deck.';

  final int deckId;
  final DeckRepository _deckRepository;
  final CardRepository _cardRepository;

  Deck? _deck;
  List<Flashcard> _cards = const [];
  bool _isLoading = false;
  String? _loadError;

  Deck? get deck => _deck;
  List<Flashcard> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    final deckResult = await _deckRepository.getDeck(deckId);
    final cardsResult = await _cardRepository.getCards(deckId);
    switch ((deckResult, cardsResult)) {
      case (Ok(value: final deck), Ok(value: final cards)):
        _deck = deck;
        _cards = cards;
      default:
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }
}
