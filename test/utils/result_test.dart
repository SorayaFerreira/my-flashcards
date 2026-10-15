import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/utils/result.dart';

void main() {
  test('guard devolve Ok com o valor da ação', () async {
    final result = await guard(() async => 42);

    expect(result, isA<Ok<int>>().having((r) => r.value, 'value', 42));
  });

  test('guard devolve Error quando a ação lança uma Exception', () async {
    final result = await guard<int>(
      () async => throw const FormatException('arquivo ruim'),
    );

    expect(
      result,
      isA<Error<int>>().having((r) => r.error, 'error', isA<FormatException>()),
    );
  });

  test('guard deixa passar erros de programação', () {
    expect(guard<int>(() async => throw StateError('bug')), throwsStateError);
  });
}
