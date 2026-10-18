import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_flashcards/data/repositories/media_repository.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/utils/result.dart';

/// [MediaRepository] that records calls. Paths are `$root/drafts/<name>`
/// and `$root/media/<name>`; point [root] at a real folder when a test
/// needs the files to exist.
class FakeMediaRepository implements MediaRepository {
  String root = '';

  /// What the next [pickImage] returns: a file name, null for "cancelled",
  /// or an [Exception] for a failure.
  Object? nextPick;
  Exception? commitError;
  bool microphoneAllowed = true;
  Exception? recordError;
  Exception? microphoneError;
  Exception? stopError;
  Exception? playError;
  Duration? duration = const Duration(seconds: 4);

  /// When set, [pickImage] / [commitDrafts] wait for it before answering.
  Completer<void>? pickGate;
  Completer<void>? commitGate;

  /// When set, [stopRecording] waits for it before answering.
  Completer<void>? stopGate;

  final picks = <ImageOrigin>[];
  final committed = <String>[];
  final reverted = <String>[];
  final discarded = <String>[];
  final recordings = <String>[];
  final played = <String>[];
  var clearedDrafts = 0;
  var stopRecordingCalls = 0;

  final _playingPath = _ProbeNotifier();

  /// Whether anything still listens to [playingPath].
  bool get hasPlayingListeners => _playingPath.isListened;

  /// Simulates the audio reaching its end.
  void finishPlayback() => _playingPath.value = null;

  @override
  Future<Result<String?>> pickImage(ImageOrigin origin) async {
    picks.add(origin);
    await pickGate?.future;
    final next = nextPick;
    if (next is Exception) return Result.error(next);
    return Result.ok(next as String?);
  }

  @override
  String draftPath(String name) => '$root/drafts/$name';

  @override
  String mediaPath(String name) => '$root/media/$name';

  @override
  Future<Result<void>> commitDrafts(Iterable<String> names) async {
    await commitGate?.future;
    final error = commitError;
    if (error != null) return Result.error(error);
    committed.addAll(names);
    return const Result.ok(null);
  }

  @override
  Future<void> revertCommit(Iterable<String> names) async =>
      reverted.addAll(names);

  @override
  Future<void> discardDrafts(Iterable<String> names) async =>
      discarded.addAll(names);

  @override
  Future<void> clearDrafts() async => clearedDrafts++;

  @override
  Future<Result<bool>> requestMicrophone() async {
    final error = microphoneError;
    if (error != null) return Result.error(error);
    return Result.ok(microphoneAllowed);
  }

  @override
  Future<Result<String>> startRecording() async {
    final error = recordError;
    if (error != null) return Result.error(error);
    final name = 'aud_${recordings.length + 1}.m4a';
    recordings.add(name);
    return Result.ok(name);
  }

  @override
  Future<Result<void>> stopRecording() async {
    stopRecordingCalls++;
    await stopGate?.future;
    final error = stopError;
    if (error != null) return Result.error(error);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> play(String path) async {
    final error = playError;
    if (error != null) return Result.error(error);
    played.add(path);
    _playingPath.value = path;
    return const Result.ok(null);
  }

  @override
  Future<void> stopPlayback() async => _playingPath.value = null;

  @override
  ValueListenable<String?> get playingPath => _playingPath;

  @override
  Future<Duration?> durationOf(String path) async => duration;
}

class _ProbeNotifier extends ValueNotifier<String?> {
  _ProbeNotifier() : super(null);

  bool get isListened => hasListeners;
}
