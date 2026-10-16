import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/ui/core/widgets/card_side_view.dart';
import 'package:my_flashcards/ui/core/widgets/media_image.dart';
import 'package:path/path.dart' as p;

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('arquivo inexistente mostra "Imagem não encontrada"', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const MediaImage(path: '/nao/existe.jpg', width: 120, height: 120)),
    );

    expect(find.text('Imagem não encontrada'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('arquivo existente vira um Image.file', (tester) async {
    final dir = Directory.systemTemp.createTempSync('media_image_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'img.jpg'))..writeAsBytesSync([0]);

    await tester.pumpWidget(host(MediaImage(path: file.path, width: 120)));

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('CardSideView mostra o texto e a imagem', (tester) async {
    await tester.pumpWidget(
      host(
        const CardSideView(text: 'to give up', imagePath: '/nao/existe.jpg'),
      ),
    );

    expect(find.text('to give up'), findsOneWidget);
    expect(find.text('Imagem não encontrada'), findsOneWidget);
  });
}
