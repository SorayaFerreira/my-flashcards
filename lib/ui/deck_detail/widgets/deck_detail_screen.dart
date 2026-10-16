import 'package:flutter/material.dart';

import '../../../domain/models/card_side.dart';
import '../../../domain/models/flashcard.dart';
import '../view_models/deck_detail_view_model.dart';

String cardPreview(CardSide side) {
  if (side.hasText) return side.text!.trim().split('\n').first;
  if (side.image != null) return '(só imagem)';
  return '(só áudio)';
}

class DeckDetailScreen extends StatefulWidget {
  const DeckDetailScreen({
    super.key,
    required this.viewModel,
    required this.onOpenEditor,
    required this.onStartReview,
  });

  final DeckDetailViewModel viewModel;

  /// Opens the card editor for a card, or for a new card when given null.
  final Future<void> Function(int? cardId) onOpenEditor;

  /// Opens the review. The list reloads afterwards to show the new counts.
  final Future<void> Function() onStartReview;

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  DeckDetailViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openEditor(int? cardId) async {
    await widget.onOpenEditor(cardId);
    if (mounted) await _viewModel.load();
  }

  Future<void> _startReview() async {
    await widget.onStartReview();
    if (mounted) await _viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(_viewModel.deck?.name ?? '')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openEditor(null),
          tooltip: 'Novo card',
          child: const Icon(Icons.add),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final loadError = _viewModel.loadError;
    if (loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loadError),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _viewModel.load,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (_viewModel.isLoading && _viewModel.deck == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final cards = _viewModel.cards;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: cards.isEmpty ? null : _startReview,
              icon: const Icon(Icons.style_outlined),
              label: Text('Revisar (${cards.length})'),
            ),
          ),
        ),
        Expanded(
          child: cards.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhum card ainda. Toque em + para criar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _CardTile(card: cards[index], onTap: _openEditor),
                ),
        ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onTap});

  final Flashcard card;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        cardPreview(card.front),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.front.image != null)
            const Icon(Icons.image_outlined, size: 18, semanticLabel: 'Imagem'),
          if (card.front.audio != null)
            const Icon(
              Icons.volume_up_outlined,
              size: 18,
              semanticLabel: 'Áudio',
            ),
          const SizedBox(width: 12),
          Text('${card.reviewCount}'),
        ],
      ),
      onTap: () => onTap(card.id),
    );
  }
}
