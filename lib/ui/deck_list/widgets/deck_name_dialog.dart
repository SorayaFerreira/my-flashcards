import 'package:flutter/material.dart';

import '../../../domain/models/deck.dart';

/// Asks for a deck name. Completes with the trimmed name, or null when the
/// dialog is cancelled.
Future<String?> showDeckNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => DeckNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
    ),
  );
}

class DeckNameDialog extends StatefulWidget {
  const DeckNameDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
  });

  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<DeckNameDialog> createState() => _DeckNameDialogState();
}

class _DeckNameDialogState extends State<DeckNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  bool get _isValid => Deck.validateName(_controller.text) == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isValid) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: Deck.maxNameLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
