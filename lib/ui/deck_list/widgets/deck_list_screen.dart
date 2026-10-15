import 'package:flutter/material.dart';

import '../../../domain/models/deck.dart';
import '../view_models/deck_list_view_model.dart';
import 'deck_name_dialog.dart';

String cardCountLabel(int count) => switch (count) {
  0 => 'Nenhum card',
  1 => '1 card',
  _ => '$count cards',
};

String deleteDeckMessage(Deck deck) {
  final cards = switch (deck.cardCount) {
    0 => '',
    1 => ' O único card dele será apagado.',
    final count => ' Os $count cards serão apagados.',
  };
  return 'Excluir “${deck.name}”?$cards Isso não pode ser desfeito.';
}

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key, required this.viewModel});

  final DeckListViewModel viewModel;

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

enum _DeckAction { rename, delete }

class _DeckListScreenState extends State<DeckListScreen> {
  DeckListViewModel get _viewModel => widget.viewModel;

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

  Future<void> _createDeck() async {
    final name = await showDeckNameDialog(
      context,
      title: 'Novo deck',
      confirmLabel: 'Criar',
    );
    if (name == null) return;
    if (!await _viewModel.createDeck(name)) _showActionError();
  }

  Future<void> _renameDeck(Deck deck) async {
    final name = await showDeckNameDialog(
      context,
      title: 'Renomear deck',
      confirmLabel: 'Salvar',
      initialName: deck.name,
    );
    if (name == null || name == deck.name) return;
    if (!await _viewModel.renameDeck(deck.id, name)) _showActionError();
  }

  Future<void> _deleteDeck(Deck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir deck'),
        content: Text(deleteDeckMessage(deck)),
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
    if (!await _viewModel.deleteDeck(deck.id)) _showActionError();
  }

  void _showActionError() {
    final message = _viewModel.actionError;
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Flashcards')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDeck,
        tooltip: 'Novo deck',
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final loadError = _viewModel.loadError;
    if (loadError != null) {
      return _LoadErrorView(message: loadError, onRetry: _viewModel.load);
    }
    if (_viewModel.isLoading && _viewModel.decks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_viewModel.decks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nenhum deck ainda. Toque em + para criar o primeiro.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _viewModel.decks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final deck = _viewModel.decks[index];
        return ListTile(
          title: Text(deck.name),
          subtitle: Text(cardCountLabel(deck.cardCount)),
          trailing: PopupMenuButton<_DeckAction>(
            tooltip: 'Opções do deck',
            onSelected: (action) => switch (action) {
              _DeckAction.rename => _renameDeck(deck),
              _DeckAction.delete => _deleteDeck(deck),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _DeckAction.rename, child: Text('Renomear')),
              PopupMenuItem(value: _DeckAction.delete, child: Text('Excluir')),
            ],
          ),
        );
      },
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}
