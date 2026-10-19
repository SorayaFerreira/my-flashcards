import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/card_side.dart';
import '../../../domain/models/flashcard.dart';
import '../../core/widgets/card_side_view.dart';
import '../view_models/review_view_model.dart';
import 'flip_card.dart';
import 'review_card_face.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.deckName,
    required this.viewModel,
  });

  final String deckName;
  final ReviewViewModel viewModel;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _hasFlipped = false;

  ReviewViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _onFlip(bool showingBack) async {
    if (!_hasFlipped) setState(() => _hasFlipped = true);
    // Count first: nothing may await before the card is read, or a quick
    // "Próximo" would make this count the next card.
    final counted = showingBack ? _viewModel.markBackSeen() : null;
    unawaited(_viewModel.stopAudio());
    if (counted != null && !await counted && mounted) {
      _showMessage(ReviewViewModel.countErrorMessage);
    }
  }

  Future<void> _toggleAudio(CardSide side) async {
    if (!await _viewModel.toggleAudio(side) && mounted) {
      _showMessage(ReviewViewModel.audioErrorMessage);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  void _restart() {
    setState(() => _hasFlipped = false);
    _viewModel.restart();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final card = _viewModel.current;
        return Scaffold(
          appBar: AppBar(
            leading: const CloseButton(),
            title: Text(widget.deckName),
            actions: [
              if (card != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text('${_viewModel.position} / ${_viewModel.total}'),
                  ),
                ),
            ],
          ),
          body: SafeArea(child: _buildBody(card)),
        );
      },
    );
  }

  Widget _buildBody(Flashcard? card) {
    final loadError = _viewModel.loadError;
    if (loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loadError),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _viewModel.start,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (_viewModel.isFinished) {
      return _FinishedView(
        reviewed: _viewModel.reviewedCount,
        total: _viewModel.total,
        onRestart: _restart,
        onBack: () => Navigator.of(context).pop(),
      );
    }
    if (card == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final showHint = _viewModel.position == 1 && !_hasFlipped;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: FlipCard(
              key: ValueKey((_viewModel.session, card.id)),
              front: ReviewCardFace(
                label: 'Frente',
                reviewCount: card.reviewCount,
                child: CardSideView(
                  text: card.front.text,
                  imagePath: _viewModel.imagePathOf(card.front),
                  audioPath: _viewModel.audioPathOf(card.front),
                  isPlaying: _viewModel.isPlaying(card.front),
                  onToggleAudio: () => _toggleAudio(card.front),
                ),
              ),
              back: ReviewCardFace(
                label: 'Verso',
                reviewCount: card.reviewCount,
                child: CardSideView(
                  text: card.back.text,
                  imagePath: _viewModel.imagePathOf(card.back),
                  audioPath: _viewModel.audioPathOf(card.back),
                  isPlaying: _viewModel.isPlaying(card.back),
                  onToggleAudio: () => _toggleAudio(card.back),
                ),
              ),
              onFlip: _onFlip,
            ),
          ),
          SizedBox(
            height: 40,
            child: showHint
                ? Center(
                    child: Text(
                      '⟵ arraste para virar ⟶',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : null,
          ),
          Row(
            children: [
              TextButton(
                onPressed: _viewModel.isFirst ? null : _viewModel.previous,
                child: const Text('‹ Anterior'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _viewModel.next,
                child: Text(_viewModel.isLast ? 'Concluir' : 'Próximo ›'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinishedView extends StatelessWidget {
  const _FinishedView({
    required this.reviewed,
    required this.total,
    required this.onRestart,
    required this.onBack,
  });

  final int reviewed;
  final int total;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cards = total == 1 ? 'card' : 'cards';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Revisão concluída!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Você revisou $reviewed de $total $cards.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRestart,
              child: const Text('Revisar de novo'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onBack, child: const Text('Voltar ao deck')),
          ],
        ),
      ),
    );
  }
}
