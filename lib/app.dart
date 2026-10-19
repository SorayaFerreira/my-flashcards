import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'routes.dart';
import 'ui/core/theme.dart';
import 'ui/deck_list/view_models/deck_list_view_model.dart';
import 'ui/deck_list/widgets/deck_list_screen.dart';

class App extends StatefulWidget {
  const App({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final _routes = AppRoutes(widget.dependencies);
  late final _deckListViewModel = DeckListViewModel(
    deckRepository: widget.dependencies.decks,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Flashcards',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) => DeckListScreen(
          viewModel: _deckListViewModel,
          onOpenDeck: (deck) =>
              Navigator.of(context).push(_routes.deckDetail(deck.id)),
          onOpenSettings: () => Navigator.of(context).push(_routes.settings()),
        ),
      ),
    );
  }
}
