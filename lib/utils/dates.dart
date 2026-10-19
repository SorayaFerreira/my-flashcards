DateTime dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// `AAAA-MM-DD`, as stored in settings and used in backup file names.
String formatDate(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
}

DateTime parseDate(String text) => DateTime.parse(text);
