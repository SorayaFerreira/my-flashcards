import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../domain/models/card_side.dart';
import '../../../domain/models/image_origin.dart';
import '../../../utils/result.dart';
import '../../core/dispose_safe_notifier.dart';
import 'side_draft.dart';

class CardEditorViewModel extends ChangeNotifier with DisposeSafeNotifier {
  CardEditorViewModel({
    required this.deckId,
    this.cardId,
    required this._cardRepository,
    required this._mediaRepository,
  });

  static const loadErrorMessage = 'Não foi possível abrir o card.';
  static const saveErrorMessage = 'Não foi possível salvar. Tente de novo.';
  static const deleteErrorMessage = 'Não foi possível excluir o card.';
  static const imageErrorMessage = 'Não foi possível carregar a imagem.';

  final int deckId;
  final int? cardId;
  final CardRepository _cardRepository;
  final MediaRepository _mediaRepository;

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

  /// The full path of the side's image, wherever the file currently lives.
  String? imagePath(Side side) {
    final image = draft(side).image;
    if (image == null) return null;
    return image.isNew
        ? _mediaRepository.draftPath(image.name)
        : _mediaRepository.mediaPath(image.name);
  }

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

  /// Returns false only when the picker failed; cancelling is not a failure.
  Future<bool> pickImage(Side side, ImageOrigin origin) async {
    switch (await _mediaRepository.pickImage(origin)) {
      case Ok(value: final name?):
        await _dropIfNew(draft(side).image);
        _setDraft(side, draft(side).withImage(DraftFile(name, isNew: true)));
        return true;
      case Ok():
        return true;
      case Error():
        _actionError = imageErrorMessage;
        notifyListeners();
        return false;
    }
  }

  Future<void> removeImage(Side side) async {
    await _dropIfNew(draft(side).image);
    _setDraft(side, draft(side).withImage(null));
  }

  Future<bool> save() async {
    if (!canSave) return false;
    _isSaving = true;
    _actionError = null;
    notifyListeners();

    final newFiles = [..._front.newFileNames, ..._back.newFileNames];
    if (await _mediaRepository.commitDrafts(newFiles) is Error) {
      await _mediaRepository.revertCommit(newFiles);
      return _saveFailed();
    }

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
    if (result is Error) {
      await _mediaRepository.revertCommit(newFiles);
      return _saveFailed();
    }

    _isSaving = false;
    _front = _initialFront = SideDraft.fromCardSide(front);
    _back = _initialBack = SideDraft.fromCardSide(back);
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
    await discard();
    return true;
  }

  /// Throws away the files created while editing. Call it when leaving
  /// without saving.
  Future<void> discard() => _mediaRepository.discardDrafts([
    ..._front.newFileNames,
    ..._back.newFileNames,
  ]);

  bool _saveFailed() {
    _isSaving = false;
    _actionError = saveErrorMessage;
    notifyListeners();
    return false;
  }

  /// Deletes a file created in this session. Files that were already saved
  /// stay until the card is saved without them.
  Future<void> _dropIfNew(DraftFile? file) async {
    if (file != null && file.isNew) {
      await _mediaRepository.discardDrafts([file.name]);
    }
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
