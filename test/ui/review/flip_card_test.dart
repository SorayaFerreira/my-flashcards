import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/review/widgets/flip_card.dart';

void main() {
  late List<bool> flips;

  setUp(() => flips = []);

  // The card is 300 px wide, so half a turn takes a 150 px drag (plus the
  // touch slop the gesture spends before it starts).
  Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: FlipCard(
            front: const Text('frente'),
            back: const Text('verso'),
            onFlip: flips.add,
          ),
        ),
      ),
    ),
  );

  Future<void> slowDrag(WidgetTester tester, double dx) async {
    await tester.timedDrag(
      find.byType(FlipCard),
      Offset(dx, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('começa mostrando a frente', (tester) async {
    await pumpCard(tester);

    expect(find.text('frente'), findsOneWidget);
    expect(find.text('verso'), findsNothing);
  });

  testWidgets('arrastar além da metade vira para o verso', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, 220);

    expect(find.text('verso'), findsOneWidget);
    expect(find.text('frente'), findsNothing);
    expect(flips, [true]);
  });

  testWidgets('arrastar para a esquerda também vira', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, -220);

    expect(find.text('verso'), findsOneWidget);
    expect(flips, [true]);
  });

  testWidgets('arrasto curto e lento volta para a frente', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, 80);

    expect(find.text('frente'), findsOneWidget);
    expect(flips, isEmpty);
  });

  testWidgets('um peteleco rápido vira mesmo sendo curto', (tester) async {
    await pumpCard(tester);

    await tester.fling(find.byType(FlipCard), const Offset(60, 0), 1500);
    await tester.pumpAndSettle();

    expect(find.text('verso'), findsOneWidget);
    expect(flips, [true]);
  });

  testWidgets('arrastar de novo desvira', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, 220);
    await slowDrag(tester, 220);

    expect(find.text('frente'), findsOneWidget);
    expect(flips, [true, false]);
  });

  testWidgets('trocar a key recomeça pela frente', (tester) async {
    await pumpCard(tester);
    await slowDrag(tester, 220);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: FlipCard(
              key: const ValueKey('outro card'),
              front: const Text('frente'),
              back: const Text('verso'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('frente'), findsOneWidget);
  });

  testWidgets('um arrasto cancelado volta para a frente', (tester) async {
    await pumpCard(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlipCard)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(find.text('verso'), findsOneWidget); // mid-turn, past half

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(find.text('frente'), findsOneWidget);
    expect(flips, isEmpty);
  });

  testWidgets('tocar no card durante a animação não desfaz a virada', (
    tester,
  ) async {
    // Long scrollable faces, as CardSideView in the app: the vertical scroll
    // recognizer competes, so a tap becomes a rejected drag (drag cancel).
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: FlipCard(
              front: SingleChildScrollView(child: Text('frente\n' * 40)),
              back: SingleChildScrollView(child: Text('verso\n' * 40)),
              onFlip: flips.add,
            ),
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.byType(FlipCard),
      const Offset(220, 0),
      const Duration(seconds: 1),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();

    expect(find.textContaining('verso'), findsOneWidget);
    expect(find.textContaining('frente'), findsNothing);
    expect(flips, [true]);
  });

  testWidgets('depois de um arrasto cancelado, um arrasto normal vira', (
    tester,
  ) async {
    await pumpCard(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlipCard)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.text('frente'), findsOneWidget);

    await slowDrag(tester, 220);

    expect(find.text('verso'), findsOneWidget);
    expect(flips, [true]);
  });

  testWidgets('um peteleco no sentido contrário não vira', (tester) async {
    await pumpCard(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlipCard)),
    );
    // Well under half a turn, to the right.
    await gesture.moveBy(const Offset(100, 0), timeStamp: Duration.zero);
    // Then a fast flick back to the left, still ending right of the start.
    for (var i = 1; i <= 5; i++) {
      await gesture.moveBy(
        const Offset(-8, 0),
        timeStamp: Duration(milliseconds: 4 * i),
      );
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('frente'), findsOneWidget);
    expect(flips, isEmpty);
  });

  testWidgets('o verso não aparece espelhado', (tester) async {
    await pumpCard(tester);

    await slowDrag(tester, 220);

    final box = tester.renderObject<RenderBox>(find.text('verso'));
    final left = box.localToGlobal(Offset(0, box.size.height / 2));
    final right = box.localToGlobal(
      Offset(box.size.width, box.size.height / 2),
    );
    expect(left.dx, lessThan(right.dx));
  });
}
