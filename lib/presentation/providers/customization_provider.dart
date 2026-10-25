import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/customization_models.dart';
import '../../core/utils/currency_formatter.dart';

import 'app_providers.dart';

// Shared Preferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.prefs;
});

// 1. TEMA SEÇİCİ (Aydınlık / Slate Gece / AMOLED Saf Siyah)
class ThemeModeNotifier extends Notifier<AppThemeType> {
  static const _key = 'evdas_theme_mode_v2';

  @override
  AppThemeType build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      return AppThemeType.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => AppThemeType.slateDark,
      );
    }
    return AppThemeType.slateDark;
  }

  Future<void> setTheme(AppThemeType type) async {
    state = type;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, type.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeType>(ThemeModeNotifier.new);

// 2. VURGU RENGİ (8 Canlı Renk)
class AccentColorNotifier extends Notifier<AccentColorOption> {
  static const _key = 'evdas_accent_color_v2';

  @override
  AccentColorOption build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      return AccentColorOption.values.firstWhere(
        (c) => c.name == raw,
        orElse: () => AccentColorOption.warmCoral,
      );
    }
    return AccentColorOption.warmCoral;
  }

  Future<void> setColor(AccentColorOption color) async {
    state = color;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, color.name);
  }
}

final accentColorProvider =
    NotifierProvider<AccentColorNotifier, AccentColorOption>(
        AccentColorNotifier.new);

// 3. GOOGLE FONTS TİPOGRAFİ
class FontFamilyNotifier extends Notifier<AppFontFamily> {
  static const _key = 'evdas_font_family_v2';

  @override
  AppFontFamily build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      return AppFontFamily.values.firstWhere(
        (f) => f.name == raw,
        orElse: () => AppFontFamily.plusJakartaSans,
      );
    }
    return AppFontFamily.plusJakartaSans;
  }

  Future<void> setFont(AppFontFamily font) async {
    state = font;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, font.name);
  }
}

final fontFamilyProvider =
    NotifierProvider<FontFamilyNotifier, AppFontFamily>(FontFamilyNotifier.new);

// 4. NUMPAD DÜZENİ (Telefon 1-2-3 vs ATM 7-8-9)
class NumpadLayoutNotifier extends Notifier<NumpadLayoutType> {
  static const _key = 'evdas_numpad_layout_v2';

  @override
  NumpadLayoutType build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      return NumpadLayoutType.values.firstWhere(
        (l) => l.name == raw,
        orElse: () => NumpadLayoutType.phone,
      );
    }
    return NumpadLayoutType.phone;
  }

  Future<void> setLayout(NumpadLayoutType layout) async {
    state = layout;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, layout.name);
  }
}

final numpadLayoutProvider =
    NotifierProvider<NumpadLayoutNotifier, NumpadLayoutType>(
        NumpadLayoutNotifier.new);

// 5. GİZLİ BAKİYE MODU (•••• ₺)
class PrivacyModeNotifier extends Notifier<bool> {
  static const _key = 'evdas_privacy_mode_v2';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isPrivate = prefs.getBool(_key) ?? false;
    CurrencyFormatter.isPrivacyMasked = isPrivate;
    return isPrivate;
  }

  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;
    CurrencyFormatter.isPrivacyMasked = newValue;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, newValue);
  }
}

final privacyModeProvider =
    NotifierProvider<PrivacyModeNotifier, bool>(PrivacyModeNotifier.new);

// 6. PARA BİRİMİ VE SEMBOL AYARLARI
class CurrencySymbolNotifier extends Notifier<CurrencySymbol> {
  static const _key = 'evdas_currency_symbol_v2';

  @override
  CurrencySymbol build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    final sym = raw != null
        ? CurrencySymbol.values.firstWhere(
            (s) => s.name == raw,
            orElse: () => CurrencySymbol.tryLira,
          )
        : CurrencySymbol.tryLira;
    CurrencyFormatter.activeSymbol = sym.symbol;
    return sym;
  }

  Future<void> setSymbol(CurrencySymbol symbol) async {
    state = symbol;
    CurrencyFormatter.activeSymbol = symbol.symbol;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, symbol.name);
  }
}

final currencySymbolProvider =
    NotifierProvider<CurrencySymbolNotifier, CurrencySymbol>(
        CurrencySymbolNotifier.new);

class CurrencyPlacementNotifier extends Notifier<CurrencyPlacement> {
  static const _key = 'evdas_currency_placement_v2';

  @override
  CurrencyPlacement build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    final placement = raw != null
        ? CurrencyPlacement.values.firstWhere(
            (p) => p.name == raw,
            orElse: () => CurrencyPlacement.after,
          )
        : CurrencyPlacement.after;
    CurrencyFormatter.activePlacement = placement;
    return placement;
  }

  Future<void> setPlacement(CurrencyPlacement placement) async {
    state = placement;
    CurrencyFormatter.activePlacement = placement;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, placement.name);
  }
}

final currencyPlacementProvider =
    NotifierProvider<CurrencyPlacementNotifier, CurrencyPlacement>(
        CurrencyPlacementNotifier.new);

class DecimalRuleNotifier extends Notifier<DecimalRule> {
  static const _key = 'evdas_decimal_rule_v2';

  @override
  DecimalRule build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    final rule = raw != null
        ? DecimalRule.values.firstWhere(
            (r) => r.name == raw,
            orElse: () => DecimalRule.clean,
          )
        : DecimalRule.clean;
    CurrencyFormatter.activeDecimalRule = rule;
    return rule;
  }

  Future<void> setRule(DecimalRule rule) async {
    state = rule;
    CurrencyFormatter.activeDecimalRule = rule;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, rule.name);
  }
}

final decimalRuleProvider =
    NotifierProvider<DecimalRuleNotifier, DecimalRule>(DecimalRuleNotifier.new);

// 7. HAPTİK GERİ BİLDİRİM ŞİDDETİ
class HapticLevelNotifier extends Notifier<HapticLevel> {
  @override
  HapticLevel build() {
    return HapticService.level;
  }

  Future<void> setLevel(HapticLevel level) async {
    state = level;
    final prefs = ref.read(sharedPreferencesProvider);
    await HapticService.setLevel(level, prefs);
  }
}

final hapticLevelProvider =
    NotifierProvider<HapticLevelNotifier, HapticLevel>(HapticLevelNotifier.new);

// 8. SES EFEKTLERİ AÇIK/KAPALI
class SoundEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return SoundService.isEnabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await SoundService.setEnabled(enabled, prefs);
  }
}

final soundEnabledProvider =
    NotifierProvider<SoundEnabledNotifier, bool>(SoundEnabledNotifier.new);

// 9. ARKA PLAN DESENİ (Düz / Grid / Noktalı / Mesh)
class BackgroundPatternNotifier extends Notifier<BackgroundPatternType> {
  static const _key = 'evdas_background_pattern_v2';

  @override
  BackgroundPatternType build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      return BackgroundPatternType.values.firstWhere(
        (p) => p.name == raw,
        orElse: () => BackgroundPatternType.none,
      );
    }
    return BackgroundPatternType.none;
  }

  Future<void> setPattern(BackgroundPatternType pattern) async {
    state = pattern;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, pattern.name);
  }
}

final backgroundPatternProvider =
    NotifierProvider<BackgroundPatternNotifier, BackgroundPatternType>(
        BackgroundPatternNotifier.new);
