import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/backup_repository.dart';
import '../../../data/repositories/reminder_repository.dart';
import '../../../domain/models/backup_manifest.dart';
import '../../../utils/result.dart';
import '../../core/dispose_safe_notifier.dart';

class SettingsViewModel extends ChangeNotifier with DisposeSafeNotifier {
  SettingsViewModel({
    required this._reminderRepository,
    required this._backupRepository,
  });

  static const permissionDeniedMessage =
      'Sem permissão para notificações. Ative em Configurações › Apps › '
      'My Flashcards › Notificações.';
  static const reminderErrorMessage = 'Não foi possível mudar o lembrete.';
  static const exportErrorMessage = 'Não foi possível gerar o backup.';
  static const openFileErrorMessage = 'Não foi possível abrir o arquivo.';
  static const invalidBackupMessage =
      'Este arquivo não é um backup do My Flashcards.';
  static const importErrorMessage =
      'Não foi possível importar. Seus dados não foram alterados.';
  static const reminderOffAfterImportNotice =
      'O lembrete foi desligado porque o app não tem permissão para '
      'notificações.';

  final ReminderRepository _reminderRepository;
  final BackupRepository _backupRepository;

  bool _reminderEnabled = false;
  bool _isBusy = false;
  String? _message;
  String? _notice;

  bool get reminderEnabled => _reminderEnabled;
  bool get isBusy => _isBusy;

  /// The message for the last action that failed.
  String? get message => _message;

  /// Informational text for the last action, which did not fail.
  String? get notice => _notice;

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
    _notice = null;
    notifyListeners();

    // An unexpected error still propagates, but must not leave the switch
    // disabled for good.
    try {
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
    } finally {
      _isBusy = false;
      notifyListeners();
    }
    return _message == null;
  }

  /// Builds the backup and opens the share menu with it. Returns false while
  /// another action is in progress, without a message.
  Future<bool> exportBackup() async {
    if (_isBusy) return false;
    _start();
    try {
      switch (await _backupRepository.exportBackup()) {
        case Ok(value: final zipPath):
          if (await _backupRepository.shareBackup(zipPath) is Error) {
            _message = exportErrorMessage;
          }
        case Error():
          _message = exportErrorMessage;
      }
    } finally {
      _finish();
    }
    return _message == null;
  }

  /// Lets the user choose a backup and checks it. Returns its manifest, to
  /// ask for confirmation, or null when the user cancelled, another action is
  /// in progress, or the file is not a valid backup (then [message] says so).
  Future<BackupManifest?> pickAndPrepareImport() async {
    if (_isBusy) return null;
    _start();
    BackupManifest? manifest;
    try {
      switch (await _backupRepository.pickBackupFile()) {
        case Ok(value: final zipPath?):
          switch (await _backupRepository.prepareImport(zipPath)) {
            case Ok(:final value):
              manifest = value;
            case Error(:final error):
              // Out of space or an unreadable file is not a bad backup.
              _message = error is FileSystemException
                  ? openFileErrorMessage
                  : invalidBackupMessage;
          }
        case Ok():
          break;
        case Error():
          _message = openFileErrorMessage;
      }
    } finally {
      _finish();
    }
    return manifest;
  }

  /// Replaces all data with the prepared backup, then restarts the reminder,
  /// whose schedule belonged to the old data. If that turns the reminder off
  /// (no notification permission), [notice] says so.
  Future<bool> confirmImport() async {
    if (_isBusy) return false;
    _start();
    try {
      if (await _backupRepository.applyImport() is Error) {
        _message = importErrorMessage;
      } else {
        // The database was just swapped, so this is the imported setting.
        // The data was already replaced, so a failure here is not a failed
        // import.
        try {
          final wasEnabled = switch (await _reminderRepository.isEnabled()) {
            Ok(:final value) => value,
            Error() => false,
          };
          await _reminderRepository.resetAfterImport();
          await _syncStoredState();
          if (wasEnabled && !_reminderEnabled) {
            _notice = reminderOffAfterImportNotice;
          }
        } catch (error, stackTrace) {
          debugPrint('$error\n$stackTrace');
        }
      }
    } finally {
      _finish();
    }
    return _message == null;
  }

  Future<void> cancelImport() => _backupRepository.cancelImport();

  void _start() {
    _isBusy = true;
    _message = null;
    _notice = null;
    notifyListeners();
  }

  void _finish() {
    _isBusy = false;
    notifyListeners();
  }

  /// A failure can happen after the stored flag was already changed, so the
  /// switch shows what is actually saved. Keeps the old value if unreadable.
  Future<void> _syncStoredState() async {
    if (await _reminderRepository.isEnabled() case Ok(:final value)) {
      _reminderEnabled = value;
    }
  }
}
