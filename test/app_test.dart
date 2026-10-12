import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/app.dart';

void main() {
  testWidgets('mostra o nome do app na barra superior', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('My Flashcards'), findsOneWidget);
  });
}
