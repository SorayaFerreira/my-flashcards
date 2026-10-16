import 'package:flutter/material.dart';

/// The frame of a card in the review: label on top, review count in the
/// bottom-right like a page number.
class ReviewCardFace extends StatelessWidget {
  const ReviewCardFace({
    super.key,
    required this.label,
    required this.reviewCount,
    required this.child,
  });

  final String label;
  final int reviewCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: muted),
              Expanded(child: child),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$reviewCount',
                    key: const Key('review-count'),
                    style: muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
