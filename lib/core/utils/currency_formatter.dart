import 'package:intl/intl.dart';
import '../theme/customization_models.dart';

class CurrencyFormatter {
  static String activeSymbol = '₺';
  static CurrencyPlacement activePlacement = CurrencyPlacement.after;
  static DecimalRule activeDecimalRule = DecimalRule.clean;
  static bool isPrivacyMasked = false;

  static void updateConfig({
    String? symbol,
    CurrencyPlacement? placement,
    DecimalRule? decimalRule,
    bool? privacyMasked,
  }) {
    if (symbol != null) activeSymbol = symbol;
    if (placement != null) activePlacement = placement;
    if (decimalRule != null) activeDecimalRule = decimalRule;
    if (privacyMasked != null) isPrivacyMasked = privacyMasked;
  }

  /// 1034.75 -> "1.034,75 ₺" (veya gizli ise "•••• ₺")
  static String format(double amount, {bool showSymbol = true, bool checkPrivacy = false}) {
    if (checkPrivacy && isPrivacyMasked) {
      return formatMasked(showSymbol: showSymbol);
    }

    final numFormat = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: showSymbol ? activeSymbol : '',
      decimalDigits: 2,
    );

    final formatted = numFormat.format(amount).trim();

    if (!showSymbol) {
      return formatted.replaceAll(activeSymbol, '').trim();
    }

    // Sembol yerleşimi
    if (activePlacement == CurrencyPlacement.before) {
      final cleanNum = formatted.replaceAll(activeSymbol, '').trim();
      return '$activeSymbol $cleanNum';
    }

    return formatted;
  }

  /// Ondalık 00 ise düz göster: 1240.0 -> "1.240 ₺", 1034.75 -> "1.034,75 ₺"
  static String formatClean(double amount, {bool checkPrivacy = false}) {
    if (checkPrivacy && isPrivacyMasked) {
      return formatMasked();
    }

    if (activeDecimalRule == DecimalRule.none) {
      final wholeFormat = NumberFormat.currency(
        locale: 'tr_TR',
        symbol: '',
        decimalDigits: 0,
      );
      final numStr = wholeFormat.format(amount.round()).trim();
      return _applyPlacement(numStr);
    }

    if (activeDecimalRule == DecimalRule.always) {
      return format(amount, showSymbol: true);
    }

    // Default: clean (kuruş varsa göster)
    if (amount % 1 == 0) {
      final wholeFormatter = NumberFormat.currency(
        locale: 'tr_TR',
        symbol: '',
        decimalDigits: 0,
      );
      final numStr = wholeFormatter.format(amount).trim();
      return _applyPlacement(numStr);
    }

    final doubleFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '',
      decimalDigits: 2,
    );
    final numStr = doubleFormatter.format(amount).trim();
    return _applyPlacement(numStr);
  }

  /// 8515 -> "8.5K ₺"
  static String formatCompact(double amount) {
    final compactFormatter = NumberFormat.compactCurrency(
      locale: 'tr_TR',
      symbol: activeSymbol,
      decimalDigits: 1,
    );
    return compactFormatter.format(amount);
  }

  /// Maskelenmiş gizli bakiye: "•••• ₺"
  static String formatMasked({bool showSymbol = true}) {
    if (!showSymbol) return '••••';
    if (activePlacement == CurrencyPlacement.before) {
      return '$activeSymbol ••••';
    }
    return '•••• $activeSymbol';
  }

  static String _applyPlacement(String numStr) {
    if (activePlacement == CurrencyPlacement.before) {
      return '$activeSymbol $numStr';
    }
    return '$numStr $activeSymbol';
  }
}
