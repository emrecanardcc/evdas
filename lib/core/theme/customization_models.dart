import 'package:flutter/material.dart';

enum AppThemeType {
  light('Aydınlık', Icons.light_mode_rounded),
  slateDark('Slate Gece', Icons.dark_mode_rounded),
  amoledDark('AMOLED Saf Siyah', Icons.brightness_2_rounded);

  final String label;
  final IconData icon;
  const AppThemeType(this.label, this.icon);
  String get displayName => label;
}

enum AccentColorOption {
  warmCoral('Warm Coral', Color(0xFFF97316)),
  emerald('Emerald', Color(0xFF10B981)),
  oceanBlue('Ocean Blue', Color(0xFF0284C7)),
  purple('Purple', Color(0xFF8B5CF6)),
  amber('Amber', Color(0xFFF59E0B)),
  rose('Rose', Color(0xFFF43F5E)),
  cyan('Cyan', Color(0xFF06B6D4)),
  slate('Slate', Color(0xFF64748B));

  final String label;
  final Color color;
  const AccentColorOption(this.label, this.color);
  String get displayName => label;
}

enum AppFontFamily {
  plusJakartaSans('Plus Jakarta Sans'),
  inter('Inter'),
  poppins('Poppins'),
  outfit('Outfit');

  final String displayName;
  const AppFontFamily(this.displayName);
  String get label => displayName;
}

enum NumpadLayoutType {
  phone('Telefon (1-2-3 Üstte)', Icons.phone_android_rounded),
  atm('ATM / Kasa (7-8-9 Üstte)', Icons.dialpad_rounded);

  final String label;
  final IconData icon;
  const NumpadLayoutType(this.label, this.icon);
  String get displayName => label;
}

enum CurrencySymbol {
  tryLira('₺', 'Türk Lirası (₺)'),
  usdDollar(r'$', r'Amerikan Doları ($)'),
  eurEuro('€', 'Euro (€)'),
  gbpPound('£', 'İngiliz Sterlini (£)');

  final String symbol;
  final String label;
  const CurrencySymbol(this.symbol, this.label);
  String get displayName => label;
}

enum CurrencyPlacement {
  after('Sonda (100 ₺)'),
  before('Önde (₺ 100)');

  final String label;
  const CurrencyPlacement(this.label);
  String get displayName => label;
}

enum DecimalRule {
  clean('Akıllı (Varsa kuruş, yoksa tam)'),
  always('Daima 2 Basamak (.00)'),
  none('Yalnızca Tam Sayı');

  final String label;
  const DecimalRule(this.label);
  String get displayName => label;
}

enum HapticLevel {
  off('Kapalı'),
  light('Hafif'),
  medium('Orta'),
  strong('Güçlü');

  final String label;
  const HapticLevel(this.label);
  String get displayName => label;
}
