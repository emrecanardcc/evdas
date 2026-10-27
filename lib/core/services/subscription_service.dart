import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../presentation/providers/customization_provider.dart';

/// Evdaş Üyelik Paketleri
enum SubscriptionTier {
  free,
  proMonthly,
  proYearly,
  lifetime,
}

extension SubscriptionTierExtension on SubscriptionTier {
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Standart';
      case SubscriptionTier.proMonthly:
        return 'Pro Aylık';
      case SubscriptionTier.proYearly:
        return 'Pro Yıllık';
      case SubscriptionTier.lifetime:
        return 'Pro Ömür Boyu';
    }
  }

  String get priceDisplay {
    switch (this) {
      case SubscriptionTier.free:
        return 'Ücretsiz';
      case SubscriptionTier.proMonthly:
        return '₺300,00 / ay (Kişi başı ₺100)';
      case SubscriptionTier.proYearly:
        return '₺2.400,00 / yıl (Kişi başı ₺67/ay)';
      case SubscriptionTier.lifetime:
        return '₺4.999,99';
    }
  }
}

/// Evdaş Abonelik Durumu Modeli (Immutable State)
@immutable
class SubscriptionState {
  final bool isPro;
  final SubscriptionTier tier;
  final DateTime? expiresAt;

  const SubscriptionState({
    required this.isPro,
    required this.tier,
    this.expiresAt,
  });

  /// Ücretsiz planda izin verilen maksimum aktif ortaklık/ev sayısı
  static const int freeTierMaxHouseholds = 2;

  /// Ücretsiz planda izin verilen maksimum aktif düzenli masraf sayısı
  static const int freeTierMaxRecurringExpenses = 2;

  bool canCreateHousehold(int currentActiveCount) {
    if (isPro) return true;
    return currentActiveCount < freeTierMaxHouseholds;
  }

  bool canCreateRecurringExpense(int currentActiveCount) {
    if (isPro) return true;
    return currentActiveCount < freeTierMaxRecurringExpenses;
  }

  bool canExportDetailedReports() => isPro;
  bool canUseProThemes() => isPro;
}

/// Evdaş Abonelik ve Gelir Yönetim Notifier'ı (Riverpod 3.x Uyumlu Freemium Engine)
class SubscriptionNotifier extends Notifier<SubscriptionState> {
  static const String _prefKeyIsPro = 'evdas_sub_is_pro';
  static const String _prefKeyTier = 'evdas_sub_tier';
  static const String _prefKeyExpiry = 'evdas_sub_expiry';

  late SharedPreferences _prefs;

  @override
  SubscriptionState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _loadState();
  }

  SubscriptionState _loadState() {
    bool isPro = _prefs.getBool(_prefKeyIsPro) ?? false;
    SubscriptionTier tier = SubscriptionTier.free;
    DateTime? expiresAt;

    final tierName = _prefs.getString(_prefKeyTier);
    if (tierName != null) {
      tier = SubscriptionTier.values.firstWhere(
        (t) => t.name == tierName,
        orElse: () => SubscriptionTier.free,
      );
    }
    final expiryMillis = _prefs.getInt(_prefKeyExpiry);
    if (expiryMillis != null) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      if (expiresAt.isBefore(DateTime.now()) && tier != SubscriptionTier.lifetime) {
        isPro = false;
        tier = SubscriptionTier.free;
      }
    }
    return SubscriptionState(isPro: isPro, tier: tier, expiresAt: expiresAt);
  }

  Future<void> _persist(SubscriptionState s) async {
    await _prefs.setBool(_prefKeyIsPro, s.isPro);
    await _prefs.setString(_prefKeyTier, s.tier.name);
    if (s.expiresAt != null) {
      await _prefs.setInt(_prefKeyExpiry, s.expiresAt!.millisecondsSinceEpoch);
    } else {
      await _prefs.remove(_prefKeyExpiry);
    }
    state = s;
  }

  /// Pro Satın Alma Simülasyonu
  Future<bool> purchase(SubscriptionTier tier) async {
    try {
      DateTime? expiresAt;
      if (tier == SubscriptionTier.proMonthly) {
        expiresAt = DateTime.now().add(const Duration(days: 30));
      } else if (tier == SubscriptionTier.proYearly) {
        expiresAt = DateTime.now().add(const Duration(days: 365));
      } else {
        expiresAt = null;
      }
      final newState = SubscriptionState(isPro: true, tier: tier, expiresAt: expiresAt);
      await _persist(newState);
      return true;
    } catch (e) {
      debugPrint('[SubscriptionService] Satın alma işlemi sırasında hata: $e');
      return false;
    }
  }

  /// Satın Alımları Geri Yükle (Restore Purchases)
  Future<bool> restorePurchases() async {
    final s = _loadState();
    state = s;
    return s.isPro;
  }

  /// Test ve geliştirme için abonelik sıfırlama
  Future<void> resetToFree() async {
    const newState = SubscriptionState(
      isPro: false,
      tier: SubscriptionTier.free,
      expiresAt: null,
    );
    await _persist(newState);
  }
}

/// Global Subscription Provider
final subscriptionProvider = NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);
