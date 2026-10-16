import 'package:flutter/material.dart';

/// The content of one side of a card, centred, scrolling when it is long.
class CardSideView extends StatelessWidget {
  const CardSideView({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text != null)
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
          ],
        ),
      ),
    );
  }
}
