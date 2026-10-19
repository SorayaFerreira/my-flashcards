import 'package:flutter/material.dart';

import '../../../app_version.dart';
import '../../../domain/models/backup_manifest.dart';
import '../view_models/settings_view_model.dart';

String importConfirmationText(BackupManifest manifest) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = manifest.exportedAt;
  final when = '${two(date.day)}/${two(date.month)}/${date.year}';
  final decks = manifest.decks == 1 ? '1 deck' : '${manifest.decks} decks';
  final cards = manifest.cards == 1 ? '1 card' : '${manifest.cards} cards';
  return 'O backup de $when tem $decks e $cards. '
      'Seus decks atuais serão apagados.';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showMessage() {
    final message = _viewModel.message;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows a blocking progress dialog while [action] runs.
  ///
  /// The dialog route is created here and removed by reference, so it is
  /// exactly that route that closes, whatever else is on the navigator by
  /// then, and even if the screen was disposed meanwhile.
  Future<T> _withProgress<T>(String label, Future<T> Function() action) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    navigator.push(route);
    try {
      return await action();
    } finally {
      if (route.isActive) navigator.removeRoute(route);
    }
  }

  Future<void> _setReminder(bool enabled) async {
    if (!await _viewModel.setReminderEnabled(enabled)) _showMessage();
  }

  Future<void> _export() async {
    final ok = await _withProgress('Gerando backup…', _viewModel.exportBackup);
    if (!ok) _showMessage();
  }

  Future<void> _import() async {
    final manifest = await _withProgress(
      'Conferindo o arquivo…',
      _viewModel.pickAndPrepareImport,
    );
    if (!mounted) return;
    if (manifest == null) {
      _showMessage();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Substituir todos os dados?'),
        content: Text(importConfirmationText(manifest)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
    // Tapping outside or going back also lands here (null): cancel.
    if (confirmed != true) {
      await _viewModel.cancelImport();
      return;
    }

    final ok = await _withProgress('Importando…', _viewModel.confirmImport);
    if (!mounted) return;
    if (!ok) {
      _showMessage();
      return;
    }
    // The app-level messenger outlives this route, so the deck list can
    // show the notice after the screen is popped.
    final messenger = ScaffoldMessenger.of(context);
    final notice = _viewModel.notice;
    Navigator.of(context).pop();
    if (notice != null) messenger.showSnackBar(SnackBar(content: Text(notice)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => ListView(
          children: [
            const _SectionHeader('LEMBRETE'),
            SwitchListTile(
              title: const Text('Lembrete diário'),
              subtitle: const Text(
                'Um por dia, em horário aleatório entre 9h e 20h',
              ),
              value: _viewModel.reminderEnabled,
              onChanged: _viewModel.isBusy ? null : _setReminder,
            ),
            const Divider(),
            const _SectionHeader('BACKUP'),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Exportar backup'),
              subtitle: const Text('Gera um .zip com tudo'),
              enabled: !_viewModel.isBusy,
              onTap: _export,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Importar backup'),
              subtitle: const Text('Substitui todos os dados'),
              enabled: !_viewModel.isBusy,
              onTap: _import,
            ),
            const Divider(),
            const ListTile(title: Text('Versão $appVersion')),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
