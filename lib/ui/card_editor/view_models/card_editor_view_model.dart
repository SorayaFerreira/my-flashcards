import 'dart:async';

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
  }) {
    _mediaRepository.playingPath.addListener(notifyListeners);
  }

  static const maxRecording = Duration(seconds: 60);

  static const loadErrorMessage = 'Não foi possível abrir o card.';
  static const saveErrorMessage = 'Não foi possível salvar. Tente de novo.';
  static const deleteErrorMessage = 'Não foi possível excluir o card.';
  static const imageErrorMessage = 'Não foi possível carregar a imagem.';
  static const microphoneDeniedMessage =
      'Sem acesso ao microfone. Ative em Configurações › Apps › '
      'My Flashcards › Permissões.';
  static const recordErrorMessage = 'Não foi possível gravar o áudio.';
  static const playErrorMessage = 'Não foi possível tocar o áudio.';

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
  bool _isPicking = false;
  bool _isStartingRecording = false;

  Side? _recordingSide;
  String? _recordingName;
  Duration _recordingElapsed = Duration.zero;
  Timer? _ticker;
  Future<void>? _stopping;
  final Map<String, Duration> _durations = {};

  /// New files already moved to the media folder while a save is running.
  final Set<String> _committed = {};
  String? _loadError;
  String? _actionError;

  bool get isNew => cardId == null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;
  String? get actionError => _actionError;

  Side? get recordingSide => _recordingSide;

  /// True while recording and until the recording is fully stopped.
  bool get isRecording => _recordingSide != null;
  Duration get recordingElapsed => _recordingElapsed;

  bool get hasChanges => _front != _initialFront || _back != _initialBack;

  bool get canSave =>
      !_isLoading &&
      !_isSaving &&
      !isRecording &&
      _loadError == null &&
      !_front.isEmpty &&
      !_back.isEmpty;

  SideDraft draft(Side side) => switch (side) {
    Side.front => _front,
    Side.back => _back,
  };

  /// The full path of the side's image, wherever the file currently lives.
  String? imagePath(Side side) => _pathOf(draft(side).image);

  /// The full path of the side's audio, wherever the file currently lives.
  String? audioPath(Side side) => _pathOf(draft(side).audio);

  Duration? audioDuration(Side side) {
    final audio = draft(side).audio;
    return audio == null ? null : _durations[audio.name];
  }

  bool isPlaying(Side side) {
    final path = audioPath(side);
    return path != null && _mediaRepository.playingPath.value == path;
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
        for (final audio in [card.front.audio, card.back.audio]) {
          if (audio != null) _loadDuration(audio);
        }
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
    if (_isSaving || _isPicking) return true;
    _isPicking = true;
    final Result<String?> result;
    try {
      result = await _mediaRepository.pickImage(origin);
    } finally {
      _isPicking = false;
    }
    switch (result) {
      case Ok(value: final name?):
        if (_isSaving || isDisposed) {
          // The save already took its snapshot; this file would be lost.
          await _mediaRepository.discardDrafts([name]);
          return true;
        }
        await _dropIfNew(draft(side).image);
        _setDraft(side, draft(side).withImage(DraftFile(name, isNew: true)));
        return true;
      case Ok():
        return true;
      case Error():
        if (isDisposed) return true;
        _actionError = imageErrorMessage;
        notifyListeners();
        return false;
    }
  }

  Future<void> removeImage(Side side) async {
    if (_isSaving) return;
    await _dropIfNew(draft(side).image);
    _setDraft(side, draft(side).withImage(null));
  }

  /// Returns false when nothing started: another recording is on, a save is
  /// running, the microphone was denied or the recorder failed.
  Future<bool> startRecording(Side side) async {
    if (_isSaving || _isStartingRecording || isRecording) return false;
    _isStartingRecording = true;
    try {
      _actionError = null;
      switch (await _mediaRepository.requestMicrophone()) {
        case Ok(value: true):
          break;
        case Ok():
          return _fail(microphoneDeniedMessage);
        case Error():
          return _fail(recordErrorMessage);
      }

      if (_isSaving || isDisposed) return false;
      await _mediaRepository.stopPlayback();
      switch (await _mediaRepository.startRecording()) {
        case Ok(value: final name):
          if (_isSaving || isDisposed) {
            // The save already took its snapshot; this file would be lost.
            await _mediaRepository.stopRecording();
            await _mediaRepository.discardDrafts([name]);
            return false;
          }
          _recordingSide = side;
          _recordingName = name;
          _recordingElapsed = Duration.zero;
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
          notifyListeners();
          return true;
        case Error():
          return _fail(recordErrorMessage);
      }
    } finally {
      _isStartingRecording = false;
    }
  }

  /// Stops the recording and keeps what was recorded. Does nothing when no
  /// recording is going on. [isRecording] stays true until it is done.
  Future<void> stopRecording() {
    final pending = _stopping;
    if (pending != null) return pending;
    if (_recordingSide == null) return Future.value();
    final stopping = _stop();
    _stopping = stopping;
    return stopping.whenComplete(() => _stopping = null);
  }

  Future<void> _stop() async {
    final side = _recordingSide!;
    final name = _recordingName!;
    final elapsed = _recordingElapsed;
    _ticker?.cancel();
    _ticker = null;

    final failed = await _mediaRepository.stopRecording() is Error;
    if (failed || _isSaving || isDisposed) {
      await _mediaRepository.discardDrafts([name]);
      _recordingSide = null;
      _recordingName = null;
      if (failed && !isDisposed) _fail(recordErrorMessage);
      return;
    }
    await _dropIfNew(draft(side).audio);
    _durations[name] = elapsed;
    _recordingSide = null;
    _recordingName = null;
    _setDraft(side, draft(side).withAudio(DraftFile(name, isNew: true)));
  }

  Future<void> removeAudio(Side side) async {
    if (_isSaving) return;
    if (isPlaying(side)) await _mediaRepository.stopPlayback();
    await _dropIfNew(draft(side).audio);
    _setDraft(side, draft(side).withAudio(null));
  }

  /// Returns false only when the sound could not be played.
  Future<bool> togglePlay(Side side) async {
    if (_isSaving) return true;
    _actionError = null;
    if (isPlaying(side)) {
      await _mediaRepository.stopPlayback();
      return true;
    }
    final path = audioPath(side);
    if (path == null) return false;
    if (await _mediaRepository.play(path) is Error) {
      return _fail(playErrorMessage);
    }
    return true;
  }

  Future<bool> save() async {
    if (!canSave) return false;
    _isSaving = true;
    _actionError = null;
    notifyListeners();

    // Everything below uses this snapshot, never the live drafts.
    final frontDraft = _front, backDraft = _back;
    final newFiles = [...frontDraft.newFileNames, ...backDraft.newFileNames];
    final front = frontDraft.toCardSide();
    final back = backDraft.toCardSide();
    await _mediaRepository.stopPlayback();
    if (await _mediaRepository.commitDrafts(newFiles) is Error) {
      await _mediaRepository.revertCommit(newFiles);
      return _saveFailed();
    }
    _committed.addAll(newFiles);

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

    _committed.clear();
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
  Future<void> discard() async {
    await stopRecording();
    await _mediaRepository.stopPlayback();
    await _mediaRepository.discardDrafts([
      ..._front.newFileNames,
      ..._back.newFileNames,
    ]);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recordingSide != null && _stopping == null) {
      _mediaRepository.stopRecording();
    }
    _mediaRepository.playingPath.removeListener(notifyListeners);
    _mediaRepository.stopPlayback();
    super.dispose();
  }

  void _tick() {
    _recordingElapsed += const Duration(seconds: 1);
    if (_recordingElapsed >= maxRecording) {
      stopRecording();
    } else {
      notifyListeners();
    }
  }

  Future<void> _loadDuration(String name) async {
    final duration = await _mediaRepository.durationOf(
      _mediaRepository.mediaPath(name),
    );
    if (duration == null) return;
    _durations[name] = duration;
    notifyListeners();
  }

  String? _pathOf(DraftFile? file) {
    if (file == null) return null;
    return file.isNew && !_committed.contains(file.name)
        ? _mediaRepository.draftPath(file.name)
        : _mediaRepository.mediaPath(file.name);
  }

  bool _fail(String message) {
    _actionError = message;
    notifyListeners();
    return false;
  }

  bool _saveFailed() {
    _committed.clear();
    _isSaving = false;
    return _fail(saveErrorMessage);
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
