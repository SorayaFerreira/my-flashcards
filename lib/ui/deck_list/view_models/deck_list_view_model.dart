import 'package:flutter/foundation.dart';

import '../../../data/repositories/deck_repository.dart';
import '../../../domain/models/deck.dart';
import '../../../utils/result.dart';

class DeckListViewModel extends ChangeNotifier {
  DeckListViewModel({required this._deckRepository});

  static const loadErrorMessage = 'Não foi possível carregar os decks.';
  static const createErrorMessage = 'Não foi possível criar o deck.';
  static const renameErrorMessage = 'Não foi possível renomear o deck.';
  static const deleteErrorMessage = 'Não foi possível excluir o deck.';

  final DeckRepository _deckRepository;

  List<Deck> _decks = const [];
  bool _isLoading = false;
  String? _loadError;
  String? _actionError;

  List<Deck> get decks => _decks;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// The message for the last action (create, rename or delete) that failed.
  String? get actionError => _actionError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    switch (await _deckRepository.getDecks()) {
      case Ok(:final value):
        _decks = value;
      case Error():
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createDeck(String name) =>
      _run(() => _deckRepository.createDeck(name), createErrorMessage);

  Future<bool> renameDeck(int id, String name) =>
      _run(() => _deckRepository.renameDeck(id, name), renameErrorMessage);

  Future<bool> deleteDeck(int id) =>
      _run(() => _deckRepository.deleteDeck(id), deleteErrorMessage);

  Future<bool> _run(
    Future<Result<Object?>> Function() action,
    String errorMessage,
  ) async {
    _actionError = null;
    final result = await action();
    if (result is Error) {
      _actionError = errorMessage;
      notifyListeners();
      return false;
    }
    await load();
    return true;
  }
}
