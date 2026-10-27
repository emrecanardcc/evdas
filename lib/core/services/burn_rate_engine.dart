import 'dart:math';
import '../../data/models/burn_rate_analysis.dart';
import '../utils/currency_formatter.dart';

/// Ay Sonu Harcama Temposu ve Projeksiyon Hesaplama Motoru (Predictive Burn Rate Engine)
///
/// Ayın geçen günleri ve kümülatif harcama hızı üzerinden deterministik O(1)
/// kapalı formüllerle ay sonu toplam harcamayı, sapma miktarını ve bütçe tükenme gününü modeller.
class BurnRateEngine {
  BurnRateEngine._();

  /// Harcama verilerinden projeksiyon analizini üretir
  static BurnRateAnalysis calculate({
    required double monthlyLimit,
    required double currentSpent,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    // İçinde bulunulan ayın toplam gün sayısı (Şubat ve artık yıllar dahil doğru gün sayısı)
    final daysInMonth = DateTime(currentTime.year, currentTime.month + 1, 0).day;
    final daysElapsed = currentTime.day.clamp(1, daysInMonth);
    final daysRemaining = max(0, daysInMonth - daysElapsed);

    if (monthlyLimit <= 0) {
      return BurnRateAnalysis(
        monthlyLimit: 0.0,
        currentSpent: currentSpent,
        daysElapsed: daysElapsed,
        daysInMonth: daysInMonth,
        daysRemaining: daysRemaining,
        dailyVelocity: daysElapsed > 0 ? (currentSpent / daysElapsed) : 0.0,
        projectedMonthEndSpend: currentSpent,
        projectedVariance: 0.0,
        projectedRatio: 0.0,
        status: BurnRateStatus.onTrack,
        budgetDepletionDay: null,
        safeDailyRemainingBudget: 0.0,
        smartRecommendation:
            'Aylık bütçe hedefi belirlendiğinde harcama temposu ve ay sonu projeksiyonu aktifleşecektir.',
      );
    }

    // Günlük ortalama harcama hızı (TL/gün)
    final dailyVelocity = currentSpent / daysElapsed;

    // Mevcut hızla ay sonu beklenen kümülatif harcama
    final projectedMonthEndSpend = dailyVelocity * daysInMonth;
    final projectedVariance = projectedMonthEndSpend - monthlyLimit;
    final projectedRatio = projectedMonthEndSpend / monthlyLimit;

    // Durum sınıflandırması
    BurnRateStatus status;
    if (projectedRatio <= 1.0) {
      status = BurnRateStatus.onTrack;
    } else if (projectedRatio <= 1.15) {
      status = BurnRateStatus.warning;
    } else {
      status = BurnRateStatus.critical;
    }

    // Bütçenin tükeneceği öngörülen gün
    int? budgetDepletionDay;
    if (dailyVelocity > 0 && projectedMonthEndSpend > monthlyLimit) {
      final calculatedDay = (monthlyLimit / dailyVelocity).floor();
      budgetDepletionDay = calculatedDay.clamp(1, daysInMonth);
    }

    // Kalan günlerde bütçe içinde kalmak için güvenli günlük limit
    final remainingBudget = (monthlyLimit - currentSpent).clamp(0.0, double.infinity);
    final remDays = daysRemaining > 0 ? daysRemaining : 1;
    final safeDailyRemainingBudget = remainingBudget / remDays;

    // Duruma özel eyleme dönüştürülebilir tavsiye metni (Sıfır emoji, finansal netlik)
    String smartRecommendation;
    if (status == BurnRateStatus.onTrack) {
      if (daysRemaining == 0) {
        smartRecommendation =
            'Ay sonu başarıyla tamamlandı. Bütçe tavanı korunarak hedefe ulaşıldı.';
      } else {
        final diff = projectedVariance.abs();
        smartRecommendation =
            'Harcama temponuz dengeli. Mevcut hızla ay sonunu bütçenin ${CurrencyFormatter.formatClean(diff)} altında kapatmanız öngörülüyor.';
      }
    } else if (status == BurnRateStatus.warning) {
      smartRecommendation =
          'Hafif bütçe aşım riski: Mevcut hızla ay sonunda bütçenizi ${CurrencyFormatter.formatClean(projectedVariance)} aşabilirsiniz. Kalan $daysRemaining gün için günlük harcamanızı ${CurrencyFormatter.formatClean(safeDailyRemainingBudget)} altında tutmanız önerilir.';
    } else {
      if (currentSpent >= monthlyLimit) {
        smartRecommendation =
            'Aylık bütçe tavanı tamamen aşıldı. Kalan $daysRemaining günde acil olmayan ortak masrafların ertelenmesi tavsiye edilir.';
      } else {
        smartRecommendation =
            'Yüksek aşım riski: Mevcut temponuzla bütçeniz ayın ${budgetDepletionDay ?? 20}. gününde tükenecektir. Bütçe içinde kalmak için günlük harcama hızınızı ${CurrencyFormatter.formatClean(safeDailyRemainingBudget)} seviyesine çekmelisiniz.';
      }
    }

    return BurnRateAnalysis(
      monthlyLimit: monthlyLimit,
      currentSpent: currentSpent,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
      daysRemaining: daysRemaining,
      dailyVelocity: dailyVelocity,
      projectedMonthEndSpend: projectedMonthEndSpend,
      projectedVariance: projectedVariance,
      projectedRatio: projectedRatio,
      status: status,
      budgetDepletionDay: budgetDepletionDay,
      safeDailyRemainingBudget: safeDailyRemainingBudget,
      smartRecommendation: smartRecommendation,
    );
  }
}
