class DateFormats {
  DateFormats._();

  /// `YYYY-MM-DD`
  static String fecha(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// `YYYYMMDDhhmmss`
  static String timestamp(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$year$month$day$hour$minute$second';
  }

  /// `dd/MM/yyyy`
  static String displayDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// `dd/MM/yyyy - HH:mm:ss` a partir de `YYYYMMDDhhmmss`.
  static String displayTimestamp(String timestamp) {
    if (timestamp.length != 14) return timestamp;
    final year = timestamp.substring(0, 4);
    final month = timestamp.substring(4, 6);
    final day = timestamp.substring(6, 8);
    final hour = timestamp.substring(8, 10);
    final minute = timestamp.substring(10, 12);
    final second = timestamp.substring(12, 14);
    return '$day/$month/$year - $hour:$minute:$second';
  }
}
