import 'package:flutter/material.dart';

import '../../../domain/models/card_side.dart';
import '../../../domain/models/image_origin.dart';
import '../view_models/card_editor_view_model.dart';
import 'audio_recorder_field.dart';
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
  late final AppLifecycleListener _lifecycle;

  // True while the app is out of sight; a recording that finishes starting
  // in that window must be stopped right away.
  bool _isHidden = false;

  CardEditorViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    // A recording must not go on while the app is out of sight.
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _isHidden = true;
        _viewModel.stopRecording();
      },
      onShow: () => _isHidden = false,
    );
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
    _lifecycle.dispose();
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
    if (discard != true) return;
    await _viewModel.discard();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => PopScope<bool>(
        canPop:
            !_viewModel.hasChanges &&
            !_viewModel.isSaving &&
            !_viewModel.isRecording,
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
      mediaEnabled: !_viewModel.isSaving,
      onTextChanged: (text) => _viewModel.setText(side, text),
      imagePath: _viewModel.imagePath(side),
      onTakePhoto: () => _pickImage(side, ImageOrigin.camera),
      onPickFromGallery: () => _pickImage(side, ImageOrigin.gallery),
      onRemoveImage: () => _viewModel.removeImage(side),
      audioField: AudioRecorderField(
        isRecording: _viewModel.recordingSide == side,
        recordingElapsed: _viewModel.recordingElapsed,
        audioPath: _viewModel.audioPath(side),
        duration: _viewModel.audioDuration(side),
        isPlaying: _viewModel.isPlaying(side),
        canRecord: !_viewModel.isRecording && !_viewModel.isSaving,
        enabled: !_viewModel.isSaving,
        canPlay: !_viewModel.isRecording,
        onRecord: () => _startRecording(side),
        onStop: _stopRecording,
        onTogglePlay: () => _togglePlay(side),
        onRemove: () => _viewModel.removeAudio(side),
      ),
    );
  }

  Future<void> _pickImage(Side side, ImageOrigin origin) async {
    if (!await _viewModel.pickImage(side, origin)) _showActionError();
  }

  Future<void> _startRecording(Side side) async {
    if (!await _viewModel.startRecording(side)) {
      _showActionError();
    } else if (_isHidden && mounted) {
      await _stopRecording();
    }
  }

  Future<void> _stopRecording() async {
    if (!await _viewModel.stopRecording()) _showActionError();
  }

  Future<void> _togglePlay(Side side) async {
    if (!await _viewModel.togglePlay(side)) _showActionError();
  }
}
