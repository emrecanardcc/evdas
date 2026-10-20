import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _tryFormatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormatter = NumberFormat.compactCurrency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 1,
  );

  /// 1034.75 -> "1.034,75 ₺"
  static String format(double amount, {bool showSymbol = true}) {
    final formatted = _tryFormatter.format(amount);
    if (!showSymbol) {
      return formatted.replaceAll('₺', '').trim();
    }
    return formatted;
  }

  /// Ondalık 00 ise düz göster: 1240.0 -> "1.240 ₺", 1034.75 -> "1.034,75 ₺"
  static String formatClean(double amount) {
    if (amount % 1 == 0) {
      final wholeFormatter = NumberFormat.currency(
        locale: 'tr_TR',
        symbol: '₺',
        decimalDigits: 0,
      );
      return wholeFormatter.format(amount);
    }
    return format(amount);
  }

  /// 8515 -> "8.5K ₺"
  static String formatCompact(double amount) {
    return _compactFormatter.format(amount);
  }
}
