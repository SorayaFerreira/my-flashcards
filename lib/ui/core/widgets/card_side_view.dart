import 'package:flutter/material.dart';

import 'media_image.dart';

/// The content of one side of a card, centred, scrolling when it is long.
class CardSideView extends StatelessWidget {
  const CardSideView({super.key, this.text, this.imagePath});

  final String? text;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final imagePath = this.imagePath;
    final parts = <Widget>[
      if (text != null)
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      if (imagePath != null)
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
          ),
          child: MediaImage(path: imagePath),
        ),
    ];
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              parts[i],
            ],
          ],
        ),
      ),
    );
  }
}
