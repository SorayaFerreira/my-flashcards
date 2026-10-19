DateTime dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// `AAAA-MM-DD`, as stored in settings and used in backup file names.
String formatDate(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
}

final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses `AAAA-MM-DD` into a local date. Returns null for any other text,
/// including impossible dates such as 2026-02-31.
DateTime? tryParseDate(String text) {
  final match = _datePattern.firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

DateTime parseDate(String text) {
  final date = tryParseDate(text);
  if (date == null) throw FormatException('Data inválida', text);
  return date;
}
