import 'package:flutter/foundation.dart';
import 'expense.dart';

/// Bütçe Sağlık Durumu
enum BudgetHealth {
  safe, // %0 - %74 (Yeşil)
  warning, // %75 - %99 (Amber / Dikkat)
  exceeded, // %100+ (Kırmızı / Limit Aşıldı)
}

/// Ortak Bütçe Modeli
@immutable
class HouseholdBudget {
  final String householdId;
  final double monthlyLimit;
  final Map<ExpenseCategory, double> categoryLimits;
  final bool alertAt80Percent;
  final bool alertAt100Percent;
  final DateTime updatedAt;

  const HouseholdBudget({
    required this.householdId,
    required this.monthlyLimit,
    this.categoryLimits = const {},
    this.alertAt80Percent = true,
    this.alertAt100Percent = true,
    required this.updatedAt,
  });

  /// Varsayılan başlangıç bütçesi (Örn: 25.000 TL)
  factory HouseholdBudget.initial(String householdId) {
    return HouseholdBudget(
      householdId: householdId,
      monthlyLimit: 25000.0,
      categoryLimits: const {
        ExpenseCategory.market: 8000.0,
        ExpenseCategory.fatura: 4000.0,
        ExpenseCategory.kira: 10000.0,
      },
      alertAt80Percent: true,
      alertAt100Percent: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Verilen toplam harcamaya göre bütçe sağlık durumunu döner
  BudgetHealth getHealth(double currentSpent) {
    if (monthlyLimit <= 0) return BudgetHealth.safe;
    final ratio = currentSpent / monthlyLimit;
    if (ratio >= 1.0) return BudgetHealth.exceeded;
    if (ratio >= 0.75) return BudgetHealth.warning;
    return BudgetHealth.safe;
  }

  /// Kalan bütçe tutarı
  double remaining(double currentSpent) {
    return (monthlyLimit - currentSpent).clamp(0.0, double.infinity);
  }

  /// Harcama oranı (0.0 - 1.0+)
  double ratio(double currentSpent) {
    if (monthlyLimit <= 0) return 0.0;
    return currentSpent / monthlyLimit;
  }

  factory HouseholdBudget.fromJson(Map<String, dynamic> json) {
    final catMap = <ExpenseCategory, double>{};
    if (json['category_limits'] != null) {
      final rawMap = json['category_limits'] as Map<String, dynamic>;
      for (final entry in rawMap.entries) {
        final cat = _parseCategory(entry.key);
        if (cat != null) {
          catMap[cat] = (entry.value as num).toDouble();
        }
      }
    }

    return HouseholdBudget(
      householdId: json['household_id'] as String,
      monthlyLimit: (json['monthly_limit'] as num).toDouble(),
      categoryLimits: catMap,
      alertAt80Percent: json['alert_at_80'] as bool? ?? true,
      alertAt100Percent: json['alert_at_100'] as bool? ?? true,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'household_id': householdId,
      'monthly_limit': monthlyLimit,
      'category_limits': {
        for (final entry in categoryLimits.entries)
          entry.key.name: entry.value,
      },
      'alert_at_80': alertAt80Percent,
      'alert_at_100': alertAt100Percent,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static ExpenseCategory? _parseCategory(String key) {
    for (final c in ExpenseCategory.values) {
      if (c.name.toLowerCase() == key.toLowerCase()) return c;
    }
    return null;
  }

  HouseholdBudget copyWith({
    String? householdId,
    double? monthlyLimit,
    Map<ExpenseCategory, double>? categoryLimits,
    bool? alertAt80Percent,
    bool? alertAt100Percent,
    DateTime? updatedAt,
  }) {
    return HouseholdBudget(
      householdId: householdId ?? this.householdId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      categoryLimits: categoryLimits ?? this.categoryLimits,
      alertAt80Percent: alertAt80Percent ?? this.alertAt80Percent,
      alertAt100Percent: alertAt100Percent ?? this.alertAt100Percent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
