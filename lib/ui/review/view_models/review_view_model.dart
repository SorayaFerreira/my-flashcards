import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../domain/models/card_side.dart';
import '../../../domain/models/flashcard.dart';
import '../../../domain/review_order.dart';
import '../../../utils/result.dart';
import '../../core/dispose_safe_notifier.dart';

class ReviewViewModel extends ChangeNotifier with DisposeSafeNotifier {
  ReviewViewModel({
    required this.deckId,
    required this._cardRepository,
    required this._mediaRepository,
    Random? random,
  }) : _random = random ?? Random() {
    _mediaRepository.playingPath.addListener(notifyListeners);
  }

  static const loadErrorMessage = 'Não foi possível carregar os cards.';
  static const countErrorMessage = 'Não foi possível salvar a revisão.';
  static const audioErrorMessage = 'Não foi possível tocar o áudio.';

  final int deckId;
  final CardRepository _cardRepository;
  final MediaRepository _mediaRepository;
  final Random _random;

  List<Flashcard> _queue = const [];
  int _index = 0;
  int _session = 0;
  final Set<int> _backSeen = {};
  bool _isLoading = false;
  bool _isFinished = false;
  int _playGeneration = 0;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isFinished => _isFinished;

  /// Grows every time a session starts, so the view can reset what it keeps
  /// per session.
  int get session => _session;

  int get total => _queue.length;
  int get position => _index + 1;
  bool get isFirst => _index == 0;
  bool get isLast => _index == _queue.length - 1;

  /// How many cards had their back seen in this session.
  int get reviewedCount => _backSeen.length;

  Flashcard? get current =>
      _isFinished || _queue.isEmpty ? null : _queue[_index];

  String? imagePathOf(CardSide side) {
    final image = side.image;
    return image == null ? null : _mediaRepository.mediaPath(image);
  }

  String? audioPathOf(CardSide side) {
    final audio = side.audio;
    return audio == null ? null : _mediaRepository.mediaPath(audio);
  }

  bool isPlaying(CardSide side) {
    final path = audioPathOf(side);
    return path != null && _mediaRepository.playingPath.value == path;
  }

  Future<void> start() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    switch (await _cardRepository.getCards(deckId)) {
      case Ok(value: final cards):
        _queue = orderForReview(cards, _random);
        _index = 0;
        _backSeen.clear();
        _isFinished = _queue.isEmpty;
        _session++;
      case Error():
        _loadError = loadErrorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> restart() => start();

  void next() {
    if (current == null) return;
    unawaited(stopAudio());
    if (isLast) {
      _isFinished = true;
    } else {
      _index++;
    }
    notifyListeners();
  }

  void previous() {
    if (current == null || isFirst) return;
    unawaited(stopAudio());
    _index--;
    notifyListeners();
  }

  /// Counts one review for the current card the first time its back is seen
  /// in this session. Returns false when the count could not be saved.
  Future<bool> markBackSeen() async {
    final card = current;
    if (card == null || !_backSeen.add(card.id)) return true;
    notifyListeners();

    switch (await _cardRepository.incrementReviewCount(card.id)) {
      case Ok(value: final count):
        _queue = [
          for (final queued in _queue)
            queued.id == card.id ? queued.copyWith(reviewCount: count) : queued,
        ];
        notifyListeners();
        return true;
      case Error():
        _backSeen.remove(card.id);
        notifyListeners();
        return false;
    }
  }

  /// Plays the side's audio, or stops it when it is already playing.
  /// Returns false when it could not be played.
  Future<bool> toggleAudio(CardSide side) async {
    if (isPlaying(side)) {
      await stopAudio();
      return true;
    }
    final path = audioPathOf(side);
    if (path == null) return false;
    final generation = ++_playGeneration;
    if (await _mediaRepository.play(path) is Ok) return true;
    // A later play or stop made this failure irrelevant.
    return generation != _playGeneration;
  }

  Future<void> stopAudio() {
    _playGeneration++;
    return _mediaRepository.stopPlayback();
  }

  @override
  void dispose() {
    _mediaRepository.playingPath.removeListener(notifyListeners);
    unawaited(stopAudio());
    super.dispose();
  }
}
