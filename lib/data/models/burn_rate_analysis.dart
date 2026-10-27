import 'package:flutter/foundation.dart';

/// Harcama Temposu ve Bütçe Durumu Sınıflandırması
enum BurnRateStatus {
  /// Bütçe tavanı içinde güvenli ilerleme (< %100)
  onTrack,

  /// Bütçeyi hafif aşma eğilimi (%100 - %115)
  warning,

  /// Ciddi bütçe aşımı veya erken tükenme riski (> %115)
  critical,
}

/// Ay Sonu Harcama Temposu ve Projeksiyon Analiz Modeli
@immutable
class BurnRateAnalysis {
  /// Tanımlı aylık tavan bütçe (TL)
  final double monthlyLimit;

  /// Bu ay şimdiye kadar yapılan toplam ortak harcama (TL)
  final double currentSpent;

  /// Ayın geçen gün sayısı (1..31)
  final int daysElapsed;

  /// İçinde bulunulan ayın toplam gün sayısı (28..31)
  final int daysInMonth;

  /// Ayın kalan gün sayısı (daysInMonth - daysElapsed)
  final int daysRemaining;

  /// Günlük ortalama harcama hızı (currentSpent / daysElapsed)
  final double dailyVelocity;

  /// Mevcut hızla ay sonu beklenen toplam harcama
  final double projectedMonthEndSpend;

  /// Bütçeye göre öngörülen fark (pozitif = aşım, negatif = tasarruf)
  final double projectedVariance;

  /// Öngörülen harcamanın bütçeye oranı (1.0 = tam bütçe)
  final double projectedRatio;

  /// Temponun durum sınıfı
  final BurnRateStatus status;

  /// Mevcut hızla bütçenin biteceği öngörülen ayın günü (null ise bütçe aşılmıyor)
  final int? budgetDepletionDay;

  /// Kalan günlerde bütçe içinde kalmak için harcanabilecek güvenli günlük limit
  final double safeDailyRemainingBudget;

  /// Eyleme dönüştürülebilir akıllı tavsiye metni
  final String smartRecommendation;

  const BurnRateAnalysis({
    required this.monthlyLimit,
    required this.currentSpent,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.daysRemaining,
    required this.dailyVelocity,
    required this.projectedMonthEndSpend,
    required this.projectedVariance,
    required this.projectedRatio,
    required this.status,
    required this.budgetDepletionDay,
    required this.safeDailyRemainingBudget,
    required this.smartRecommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'monthly_limit': monthlyLimit,
      'current_spent': currentSpent,
      'days_elapsed': daysElapsed,
      'days_in_month': daysInMonth,
      'days_remaining': daysRemaining,
      'daily_velocity': dailyVelocity,
      'projected_month_end_spend': projectedMonthEndSpend,
      'projected_variance': projectedVariance,
      'projected_ratio': projectedRatio,
      'status': status.name,
      'budget_depletion_day': budgetDepletionDay,
      'safe_daily_remaining_budget': safeDailyRemainingBudget,
      'smart_recommendation': smartRecommendation,
    };
  }

  factory BurnRateAnalysis.fromJson(Map<String, dynamic> json) {
    return BurnRateAnalysis(
      monthlyLimit: (json['monthly_limit'] as num?)?.toDouble() ?? 0.0,
      currentSpent: (json['current_spent'] as num?)?.toDouble() ?? 0.0,
      daysElapsed: (json['days_elapsed'] as num?)?.toInt() ?? 1,
      daysInMonth: (json['days_in_month'] as num?)?.toInt() ?? 30,
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      dailyVelocity: (json['daily_velocity'] as num?)?.toDouble() ?? 0.0,
      projectedMonthEndSpend:
          (json['projected_month_end_spend'] as num?)?.toDouble() ?? 0.0,
      projectedVariance:
          (json['projected_variance'] as num?)?.toDouble() ?? 0.0,
      projectedRatio: (json['projected_ratio'] as num?)?.toDouble() ?? 0.0,
      status: BurnRateStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BurnRateStatus.onTrack,
      ),
      budgetDepletionDay: (json['budget_depletion_day'] as num?)?.toInt(),
      safeDailyRemainingBudget:
          (json['safe_daily_remaining_budget'] as num?)?.toDouble() ?? 0.0,
      smartRecommendation: json['smart_recommendation'] as String? ?? '',
    );
  }
}
