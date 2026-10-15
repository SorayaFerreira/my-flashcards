import 'package:flutter/foundation.dart';

/// Lets a ViewModel finish async work after its screen is gone: once
/// disposed, [notifyListeners] does nothing instead of asserting.
mixin DisposeSafeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
