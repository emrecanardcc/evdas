import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import 'expense.dart';

/// Tavsiye ve İçgörü Türü
enum AdviceType {
  savings, // Tasarruf potansiyeli
  trend,   // Ay bazında değişim trendi
  balance, // Ortaklar arası ödeme dengesi
  alert,   // Bütçe veya harcama uyarısı
}

extension AdviceTypeExt on AdviceType {
  IconData get icon {
    switch (this) {
      case AdviceType.savings:
        return Icons.savings_rounded;
      case AdviceType.trend:
        return Icons.trending_up_rounded;
      case AdviceType.balance:
        return Icons.balance_rounded;
      case AdviceType.alert:
        return Icons.notification_important_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AdviceType.savings:
        return AppColors.positive;
      case AdviceType.trend:
        return const Color(0xFF0284C7); // Sky Blue
      case AdviceType.balance:
        return const Color(0xFF8B5CF6); // Purple
      case AdviceType.alert:
        return const Color(0xFFD97706); // Amber
    }
  }
}

/// Kategori Bazında Geçen Aya Göre Trend
class CategoryTrend {
  final ExpenseCategory category;
  final double thisMonthAmount;
  final double lastMonthAmount;
  final double difference; // thisMonth - lastMonth
  final double percentageChange; // % değişim

  CategoryTrend({
    required this.category,
    required this.thisMonthAmount,
    required this.lastMonthAmount,
    required this.difference,
    required this.percentageChange,
  });

  bool get isIncrease => difference > 0.01;
  bool get isDecrease => difference < -0.01;
  bool get isUnchanged => !isIncrease && !isDecrease;

  String get formattedDifference {
    final prefix = isIncrease ? '+' : (isDecrease ? '-' : '');
    return '$prefix${CurrencyFormatter.formatClean(difference.abs())}';
  }

  String get formattedPercentage {
    final prefix = isIncrease ? '+' : (isDecrease ? '-' : '');
    return '$prefix%${percentageChange.abs().toStringAsFixed(1)}';
  }
}

/// Ev Finansal Uyumluluk ve Sağlık Skoru (0 - 100)
class FinancialHealthScore {
  final int score; // 0 - 100
  final String title;
  final String description;
  final Color color;

  FinancialHealthScore({
    required this.score,
    required this.title,
    required this.description,
    required this.color,
  });

  static FinancialHealthScore calculate({
    required double budgetComplianceFactor, // 0.0 - 1.0 (Bütçe sınırına uyum)
    required double expenseBalanceFactor,    // 0.0 - 1.0 (Ortaklar arası harcama eşitliği)
    required double debtSettlementFactor,    // 0.0 - 1.0 (Şahsi borçların makullüğü)
  }) {
    // 40 puan Bütçe + 35 puan Adalet/Denge + 25 puan Borç Ödeşme
    final total = (budgetComplianceFactor * 40.0) +
        (expenseBalanceFactor * 35.0) +
        (debtSettlementFactor * 25.0);
    final finalScore = total.round().clamp(0, 100);

    if (finalScore >= 80) {
      return FinancialHealthScore(
        score: finalScore,
        title: 'Mükemmel Uyum',
        description: 'Ortak bütçe kontrol altında ve harcamalar dengeli.',
        color: AppColors.positive,
      );
    } else if (finalScore >= 60) {
      return FinancialHealthScore(
        score: finalScore,
        title: 'Dengeli & Sağlıklı',
        description: 'Genel giderler makul, bazı kategorilerde tasarruf alanı var.',
        color: const Color(0xFF0284C7), // Blue
      );
    } else if (finalScore >= 40) {
      return FinancialHealthScore(
        score: finalScore,
        title: 'Dikkat Gerektirir',
        description: 'Bütçe sınırına yaklaşıldı veya ödeme yükü tek bir kişide.',
        color: const Color(0xFFD97706), // Amber
      );
    } else {
      return FinancialHealthScore(
        score: finalScore,
        title: 'Bütçe Aşımı Riski',
        description: 'Aylık bütçe aşıldı veya ortaklar arasında dengesizlik yüksek.',
        color: AppColors.negative,
      );
    }
  }
}

/// Yapay Tavsiye ve Aksiyon Öğesi
class FinancialAdvice {
  final String id;
  final String title;
  final String description;
  final AdviceType type;
  final int priority; // 1 (en yüksek) - 5 (en düşük)
  final double? potentialSavings;

  FinancialAdvice({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.priority = 3,
    this.potentialSavings,
  });
}

/// Ortaklığın Tüm Akıllı Finansal İçgörü Paketi
class HouseholdFinancialInsights {
  final FinancialHealthScore healthScore;
  final double totalJointThisMonth;
  final double totalJointLastMonth;
  final double overallDifference;
  final double overallPercentageChange;
  final List<CategoryTrend> categoryTrends;
  final List<FinancialAdvice> advices;

  HouseholdFinancialInsights({
    required this.healthScore,
    required this.totalJointThisMonth,
    required this.totalJointLastMonth,
    required this.overallDifference,
    required this.overallPercentageChange,
    required this.categoryTrends,
    required this.advices,
  });

  bool get hasPreviousMonthData => totalJointLastMonth > 0;
  bool get hasSavedOverall => overallDifference < -0.01;
  bool get hasIncreasedOverall => overallDifference > 0.01;
}
