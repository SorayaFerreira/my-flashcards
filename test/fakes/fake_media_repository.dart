import 'package:my_flashcards/data/repositories/media_repository.dart';
import 'package:my_flashcards/domain/models/image_origin.dart';
import 'package:my_flashcards/utils/result.dart';

/// [MediaRepository] that records calls. Paths start with /drafts or /media
/// and point nowhere.
class FakeMediaRepository implements MediaRepository {
  /// What the next [pickImage] returns: a file name, null for "cancelled",
  /// or an [Exception] for a failure.
  Object? nextPick;
  Exception? commitError;

  final picks = <ImageOrigin>[];
  final committed = <String>[];
  final reverted = <String>[];
  final discarded = <String>[];
  var clearedDrafts = 0;

  @override
  Future<Result<String?>> pickImage(ImageOrigin origin) async {
    picks.add(origin);
    final next = nextPick;
    if (next is Exception) return Result.error(next);
    return Result.ok(next as String?);
  }

  @override
  String draftPath(String name) => '/drafts/$name';

  @override
  String mediaPath(String name) => '/media/$name';

  @override
  Future<Result<void>> commitDrafts(Iterable<String> names) async {
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
}
