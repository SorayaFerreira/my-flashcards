import 'dart:io';

import 'package:flutter/material.dart';

/// An image file from the app's storage, decoded at the size it is shown.
/// Shows a grey box saying the image wasn't found when the file is missing
/// or can't be read.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return _MissingImage(width: width, height: height);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final shownWidth = width ?? (maxWidth.isFinite ? maxWidth : null);
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: shownWidth == null
              ? null
              : (shownWidth * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, _, _) =>
              _MissingImage(width: width, height: height),
        );
      },
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height ?? 120,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Imagem não encontrada',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
