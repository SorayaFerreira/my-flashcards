import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/core/dispose_safe_notifier.dart';

class _Notifier extends ChangeNotifier with DisposeSafeNotifier {}

void main() {
  test('depois do dispose, notifyListeners não faz nada nem lança erro', () {
    final notifier = _Notifier();
    expect(notifier.isDisposed, isFalse);

    notifier.dispose();

    expect(notifier.isDisposed, isTrue);
    expect(notifier.notifyListeners, returnsNormally);
  });
}
