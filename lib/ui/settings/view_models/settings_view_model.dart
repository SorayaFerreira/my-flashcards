import 'package:flutter/foundation.dart';

import '../../../data/repositories/reminder_repository.dart';
import '../../../utils/result.dart';
import '../../core/dispose_safe_notifier.dart';

class SettingsViewModel extends ChangeNotifier with DisposeSafeNotifier {
  SettingsViewModel({required this._reminderRepository});

  static const permissionDeniedMessage =
      'Sem permissão para notificações. Ative em Configurações › Apps › '
      'My Flashcards › Notificações.';
  static const reminderErrorMessage = 'Não foi possível mudar o lembrete.';

  final ReminderRepository _reminderRepository;

  bool _reminderEnabled = false;
  bool _isBusy = false;
  String? _message;

  bool get reminderEnabled => _reminderEnabled;
  bool get isBusy => _isBusy;

  /// The message for the last action that failed.
  String? get message => _message;

  Future<void> load() async {
    if (await _reminderRepository.isEnabled() case Ok(:final value)) {
      _reminderEnabled = value;
    }
    notifyListeners();
  }

  /// Returns false while another change is in progress, without a message.
  Future<bool> setReminderEnabled(bool enabled) async {
    if (_isBusy) return false;
    _isBusy = true;
    _message = null;
    notifyListeners();

    if (enabled) {
      switch (await _reminderRepository.enable()) {
        case Ok(value: true):
          _reminderEnabled = true;
        case Ok():
          _message = permissionDeniedMessage;
        case Error():
          _message = reminderErrorMessage;
          await _syncStoredState();
      }
    } else {
      switch (await _reminderRepository.disable()) {
        case Ok():
          _reminderEnabled = false;
        case Error():
          _message = reminderErrorMessage;
          await _syncStoredState();
      }
    }

    _isBusy = false;
    notifyListeners();
    return _message == null;
  }

  /// A failure can happen after the stored flag was already changed, so the
  /// switch shows what is actually saved. Keeps the old value if unreadable.
  Future<void> _syncStoredState() async {
    if (await _reminderRepository.isEnabled() case Ok(:final value)) {
      _reminderEnabled = value;
    }
  }
}
