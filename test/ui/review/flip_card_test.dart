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
}
