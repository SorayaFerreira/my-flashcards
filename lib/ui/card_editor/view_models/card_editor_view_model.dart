import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../domain/models/card_side.dart';
import '../../../utils/result.dart';
import '../../core/dispose_safe_notifier.dart';
import 'side_draft.dart';

class CardEditorViewModel extends ChangeNotifier with DisposeSafeNotifier {
  CardEditorViewModel({
    required this.deckId,
    this.cardId,
    required this._cardRepository,
  });

  static const loadErrorMessage = 'Não foi possível abrir o card.';
  static const saveErrorMessage = 'Não foi possível salvar. Tente de novo.';
  static const deleteErrorMessage = 'Não foi possível excluir o card.';

  final int deckId;
  final int? cardId;
  final CardRepository _cardRepository;

  SideDraft _front = const SideDraft();
  SideDraft _back = const SideDraft();
  SideDraft _initialFront = const SideDraft();
  SideDraft _initialBack = const SideDraft();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadError;
  String? _actionError;

  bool get isNew => cardId == null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  bool get hasChanges => _front != _initialFront || _back != _initialBack;

  bool get canSave =>
      !_isLoading &&
      !_isSaving &&
      _loadError == null &&
      !_front.isEmpty &&
      !_back.isEmpty;

  SideDraft draft(Side side) => switch (side) {
    Side.front => _front,
    Side.back => _back,
  };

  Future<void> load() async {
    final id = cardId;
    if (id == null) return;
    _isLoading = true;
    notifyListeners();

    switch (await _cardRepository.getCard(id)) {
      case Ok(value: final card):
        _front = _initialFront = SideDraft.fromCardSide(card.front);
        _back = _initialBack = SideDraft.fromCardSide(card.back);
      case Error():
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setText(Side side, String text) =>
      _setDraft(side, draft(side).withText(text));

  Future<bool> save() async {
    if (!canSave) return false;
    _isSaving = true;
    _actionError = null;
    notifyListeners();

    final front = _front.toCardSide();
    final back = _back.toCardSide();
    final id = cardId;
    final result = id == null
        ? await _cardRepository.createCard(
            deckId: deckId,
            front: front,
            back: back,
          )
        : await _cardRepository.updateCard(id: id, front: front, back: back);

    _isSaving = false;
    if (result is Error) {
      _actionError = saveErrorMessage;
      notifyListeners();
      return false;
    }
    _initialFront = _front;
    _initialBack = _back;
    notifyListeners();
    return true;
  }

  Future<bool> deleteCard() async {
    final id = cardId;
    if (id == null) return false;
    if (await _cardRepository.deleteCard(id) is Error) {
      _actionError = deleteErrorMessage;
      notifyListeners();
      return false;
    }
    return true;
  }

  void _setDraft(Side side, SideDraft value) {
    switch (side) {
      case Side.front:
        _front = value;
      case Side.back:
        _back = value;
    }
    notifyListeners();
  }
}
