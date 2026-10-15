import 'package:flutter/material.dart';

import '../../../domain/models/card_side.dart';
import '../view_models/card_editor_view_model.dart';
import 'side_editor.dart';

class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, required this.viewModel});

  final CardEditorViewModel viewModel;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _frontText = TextEditingController();
  final _backText = TextEditingController();

  CardEditorViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _viewModel.load();
    if (!mounted) return;
    _frontText.text = _viewModel.draft(Side.front).text;
    _backText.text = _viewModel.draft(Side.back).text;
  }

  @override
  void dispose() {
    _frontText.dispose();
    _backText.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showActionError() {
    final message = _viewModel.actionError;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (await _viewModel.save()) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _showActionError();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir este card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (await _viewModel.deleteCard()) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _showActionError();
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => PopScope<bool>(
        canPop: !_viewModel.hasChanges && !_viewModel.isSaving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_viewModel.isSaving) _confirmDiscard();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_viewModel.isNew ? 'Novo card' : 'Editar card'),
            actions: [
              if (!_viewModel.isNew)
                IconButton(
                  onPressed: _viewModel.isSaving ? null : _delete,
                  tooltip: 'Excluir card',
                  icon: const Icon(Icons.delete_outline),
                ),
              TextButton(
                onPressed: _viewModel.canSave ? _save : null,
                child: const Text('SALVAR'),
              ),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final loadError = _viewModel.loadError;
    if (loadError != null) return Center(child: Text(loadError));
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sideEditor(Side.front, 'FRENTE', _frontText),
        const Divider(height: 32),
        _sideEditor(Side.back, 'VERSO', _backText),
      ],
    );
  }

  Widget _sideEditor(
    Side side,
    String label,
    TextEditingController controller,
  ) {
    return SideEditor(
      label: label,
      controller: controller,
      isEmpty: _viewModel.draft(side).isEmpty,
      autofocus: side == Side.front && _viewModel.isNew,
      onTextChanged: (text) => _viewModel.setText(side, text),
    );
  }
}
