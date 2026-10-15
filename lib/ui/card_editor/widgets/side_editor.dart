import 'package:flutter/material.dart';

class SideEditor extends StatelessWidget {
  const SideEditor({
    super.key,
    required this.label,
    required this.controller,
    required this.isEmpty,
    required this.onTextChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool isEmpty;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onTextChanged,
          minLines: 1,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Texto',
            border: OutlineInputBorder(),
          ),
        ),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Adicione texto, imagem ou áudio',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
