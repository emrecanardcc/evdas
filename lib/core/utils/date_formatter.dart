import 'package:intl/intl.dart';

class DateFormatter {
  static DateFormat? _cachedDayMonth;
  static DateFormat? _cachedFull;
  static DateFormat? _cachedTime;

  static DateFormat get _dayMonthFormat =>
      _cachedDayMonth ??= DateFormat('d MMMM', 'tr_TR');
  static DateFormat get _fullFormat =>
      _cachedFull ??= DateFormat('d MMMM yyyy', 'tr_TR');
  static DateFormat get _timeFormat =>
      _cachedTime ??= DateFormat('HH:mm', 'tr_TR');

  static String formatSmart(DateTime date) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final itemDate = DateTime(date.year, date.month, date.day);

      if (itemDate == today) {
        return 'Bugün, ${_timeFormat.format(date)}';
      } else if (itemDate == today.subtract(const Duration(days: 1))) {
        return 'Dün, ${_timeFormat.format(date)}';
      } else if (now.year == date.year) {
        return _dayMonthFormat.format(date);
      } else {
        return _fullFormat.format(date);
      }
    } catch (_) {
      // Fallback if locale data is not loaded yet
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  static String formatFull(DateTime date) {
    try {
      return _fullFormat.format(date);
    } catch (_) {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}
