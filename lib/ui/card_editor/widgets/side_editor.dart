import 'package:flutter/material.dart';

import '../../core/widgets/media_image.dart';

class SideEditor extends StatelessWidget {
  const SideEditor({
    super.key,
    required this.label,
    required this.controller,
    required this.isEmpty,
    required this.onTextChanged,
    required this.imagePath,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.onRemoveImage,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final bool isEmpty;
  final ValueChanged<String> onTextChanged;
  final String? imagePath;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final VoidCallback onRemoveImage;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imagePath = this.imagePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onTextChanged,
          autofocus: autofocus,
          minLines: 1,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Texto',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (imagePath == null)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onTakePhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Câmera'),
              ),
              OutlinedButton.icon(
                onPressed: onPickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MediaImage(
                  path: imagePath,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              IconButton(
                onPressed: onRemoveImage,
                tooltip: 'Remover imagem',
                icon: const Icon(Icons.close),
              ),
            ],
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
