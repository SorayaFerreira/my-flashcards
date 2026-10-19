import 'package:my_flashcards/data/repositories/reminder_repository.dart';
import 'package:my_flashcards/utils/result.dart';

class FakeReminderRepository implements ReminderRepository {
  bool enabled = false;
  bool permissionAllowed = true;
  Exception? failWith;
  var enableCalls = 0;
  var topUpCalls = 0;
  var resetCalls = 0;

  /// Makes [resetAfterImport] turn the reminder off, as when the permission
  /// is missing.
  bool disableOnReset = false;

  Future<Result<T>> _answer<T>(T Function() compute) async {
    final error = failWith;
    if (error != null) return Result.error(error);
    return Result.ok(compute());
  }

  @override
  Future<Result<bool>> isEnabled() => _answer(() => enabled);

  @override
  Future<Result<bool>> enable() => _answer(() {
    enableCalls++;
    if (!permissionAllowed) return false;
    enabled = true;
    return true;
  });

  @override
  Future<Result<void>> disable() => _answer(() => enabled = false);

  @override
  Future<Result<void>> topUp() => _answer(() => topUpCalls++);

  @override
  Future<Result<void>> resetAfterImport() => _answer(() {
    resetCalls++;
    if (disableOnReset) enabled = false;
  });
}
