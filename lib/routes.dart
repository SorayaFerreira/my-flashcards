import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'ui/card_editor/view_models/card_editor_view_model.dart';
import 'ui/card_editor/widgets/card_editor_screen.dart';
import 'ui/deck_detail/view_models/deck_detail_view_model.dart';
import 'ui/deck_detail/widgets/deck_detail_screen.dart';
import 'ui/review/view_models/review_view_model.dart';
import 'ui/review/widgets/review_screen.dart';

/// Builds every route of the app. Each ViewModel is created here, once per
/// route, and handed to its screen, which disposes it.
class AppRoutes {
  const AppRoutes(this._dependencies);

  final AppDependencies _dependencies;

  Route<void> deckDetail(int deckId) {
    final viewModel = DeckDetailViewModel(
      deckId: deckId,
      deckRepository: _dependencies.decks,
      cardRepository: _dependencies.cards,
    );
    return MaterialPageRoute(
      builder: (context) => DeckDetailScreen(
        viewModel: viewModel,
        onOpenEditor: (cardId) =>
            Navigator.of(context)
                .push(cardEditor(deckId: deckId, cardId: cardId)),
        onStartReview: () => Navigator.of(context)
            .push(review(deckId: deckId, deckName: viewModel.deck?.name ?? '')),
      ),
    );
  }

  Route<void> review({required int deckId, required String deckName}) {
    final viewModel = ReviewViewModel(
      deckId: deckId,
      cardRepository: _dependencies.cards,
      mediaRepository: _dependencies.media,
    );
    return MaterialPageRoute(
      builder: (_) => ReviewScreen(deckName: deckName, viewModel: viewModel),
    );
  }

  Route<bool> cardEditor({required int deckId, int? cardId}) {
    final viewModel = CardEditorViewModel(
      deckId: deckId,
      cardId: cardId,
      cardRepository: _dependencies.cards,
      mediaRepository: _dependencies.media,
    );
    return MaterialPageRoute(
      builder: (_) => CardEditorScreen(viewModel: viewModel),
    );
  }
}
