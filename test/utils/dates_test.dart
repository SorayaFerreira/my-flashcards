import 'package:flutter_test/flutter_test.dart';
import 'package:my_flashcards/utils/dates.dart';

void main() {
  test('tryParseDate aceita só AAAA-MM-DD válido', () {
    expect(tryParseDate('2026-03-07'), DateTime(2026, 3, 7));
    expect(tryParseDate('2026-03-07T00:00:00Z'), isNull);
    expect(tryParseDate('20260307'), isNull);
    expect(tryParseDate('2026-02-31'), isNull);
    expect(tryParseDate('lixo'), isNull);
  });

  test('parseDate lança FormatException para texto inválido', () {
    expect(() => parseDate('lixo'), throwsFormatException);
  });

  test('formatDateTime e tryParseDateTime fazem o caminho de ida e volta', () {
    final time = DateTime(2026, 10, 12, 9, 5);

    expect(formatDateTime(time), '2026-10-12T09:05');
    expect(tryParseDateTime('2026-10-12T09:05'), time);
  });

  test('tryParseDateTime recusa texto inválido', () {
    expect(tryParseDateTime('2026-10-12'), isNull);
    expect(tryParseDateTime('2026-10-12T24:00'), isNull);
    expect(tryParseDateTime('2026-10-12T10:60'), isNull);
    expect(tryParseDateTime('2026-02-31T10:00'), isNull);
  });
}
