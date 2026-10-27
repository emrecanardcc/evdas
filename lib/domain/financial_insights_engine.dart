import '../core/utils/currency_formatter.dart';
import '../data/models/expense.dart';
import '../data/models/financial_insights.dart';
import '../data/models/household_budget.dart';
import '../data/models/household_member.dart';

/// Evdaş Akıllı Finansal Tasarruf ve Trend Analiz Motoru
class FinancialInsightsEngine {
  /// Harcamaları, üyeleri ve bütçe hedefini analiz ederek içgörüleri üretir ($O(N)$ Tek Geçiş)
  static HouseholdFinancialInsights analyze({
    required List<Expense> expenses,
    required List<HouseholdMember> members,
    HouseholdBudget? budget,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final thisYear = now.year;
    final thisMonth = now.month;

    final lastMonthYear = thisMonth == 1 ? thisYear - 1 : thisYear;
    final lastMonth = thisMonth == 1 ? 12 : thisMonth - 1;

    double totalJointThisMonth = 0.0;
    double totalJointLastMonth = 0.0;
    double totalPersonalDebtThisMonth = 0.0;

    final thisMonthCatSpend = <ExpenseCategory, double>{};
    final lastMonthCatSpend = <ExpenseCategory, double>{};
    final memberThisMonthSpend = <String, double>{for (final m in members) m.id: 0.0};

    // TEK GEÇİŞTE (O(N)) AYRIŞTIRMA VE TOPLAMA
    for (final exp in expenses) {
      final expYear = exp.expenseDate.year;
      final expMonth = exp.expenseDate.month;

      final isThisMonth = (expYear == thisYear && expMonth == thisMonth);
      final isLastMonth = (expYear == lastMonthYear && expMonth == lastMonth);

      if (isThisMonth) {
        if (exp.type == ExpenseType.joint) {
          totalJointThisMonth += exp.amount;
          thisMonthCatSpend[exp.category] =
              (thisMonthCatSpend[exp.category] ?? 0.0) + exp.amount;
          memberThisMonthSpend[exp.paidByMemberId] =
              (memberThisMonthSpend[exp.paidByMemberId] ?? 0.0) + exp.amount;
        } else if (exp.type == ExpenseType.personalDebt) {
          totalPersonalDebtThisMonth += exp.amount;
        }
      } else if (isLastMonth) {
        if (exp.type == ExpenseType.joint) {
          totalJointLastMonth += exp.amount;
          lastMonthCatSpend[exp.category] =
              (lastMonthCatSpend[exp.category] ?? 0.0) + exp.amount;
        }
      }
    }

    // 1. GENEL DEĞİŞİM FARKI VE YÜZDESİ
    final overallDifference = totalJointThisMonth - totalJointLastMonth;
    double overallPercentageChange = 0.0;
    if (totalJointLastMonth > 0) {
      overallPercentageChange =
          ((totalJointThisMonth - totalJointLastMonth) / totalJointLastMonth) * 100.0;
    } else if (totalJointThisMonth > 0) {
      overallPercentageChange = 100.0;
    }

    // 2. KATEGORİ TRENDLERİ HESAPLAMA
    final allCategories = <ExpenseCategory>{
      ...thisMonthCatSpend.keys,
      ...lastMonthCatSpend.keys,
    };

    final categoryTrends = <CategoryTrend>[];
    for (final cat in allCategories) {
      final thisAmount = thisMonthCatSpend[cat] ?? 0.0;
      final lastAmount = lastMonthCatSpend[cat] ?? 0.0;
      final diff = thisAmount - lastAmount;

      double pctChange = 0.0;
      if (lastAmount > 0) {
        pctChange = (diff / lastAmount) * 100.0;
      } else if (thisAmount > 0) {
        pctChange = 100.0;
      }

      categoryTrends.add(
        CategoryTrend(
          category: cat,
          thisMonthAmount: thisAmount,
          lastMonthAmount: lastAmount,
          difference: diff,
          percentageChange: pctChange,
        ),
      );
    }
    // En yüksek harcama veya en büyük farka göre sırala
    categoryTrends.sort((a, b) => b.thisMonthAmount.compareTo(a.thisMonthAmount));

    // 3. FİNANSAL SAĞLIK SKORU HESAPLAMA (0 - 100)
    // A) Bütçe uyumu faktörü (0.0 - 1.0)
    double budgetCompliance = 0.85; // Varsayılan iyi niyet puanı
    if (budget != null && budget.monthlyLimit > 0) {
      final ratio = budget.ratio(totalJointThisMonth);
      if (ratio <= 0.8) {
        budgetCompliance = 1.0;
      } else if (ratio <= 1.0) {
        budgetCompliance = 1.0 - ((ratio - 0.8) * 2.0); // 1.0 -> 0.6
      } else {
        budgetCompliance = (1.2 - ratio).clamp(0.0, 0.4);
      }
    }

    // B) Ortaklar arası harcama eşitliği faktörü (0.0 - 1.0)
    double expenseBalance = 1.0;
    String? mostPaidMemberName;
    double mostPaidMemberShare = 0.0;

    if (members.length > 1 && totalJointThisMonth > 0) {
      final idealShare = 1.0 / members.length;
      double maxShare = 0.0;
      String maxMemberId = '';

      for (final m in members) {
        final spent = memberThisMonthSpend[m.id] ?? 0.0;
        final share = spent / totalJointThisMonth;
        if (share > maxShare) {
          maxShare = share;
          maxMemberId = m.id;
        }
      }

      mostPaidMemberShare = maxShare;
      mostPaidMemberName = members
          .firstWhere((m) => m.id == maxMemberId, orElse: () => members.first)
          .displayName;

      // Eşitlik faktörü: idealden sapma payı
      final deviation = (maxShare - idealShare).clamp(0.0, 1.0);
      expenseBalance = (1.0 - (deviation * 1.5)).clamp(0.2, 1.0);
    }

    // C) Borçlanma faktörü (0.0 - 1.0)
    double debtSettlement = 1.0;
    if (totalPersonalDebtThisMonth > 0 && totalJointThisMonth > 0) {
      final debtRatio = totalPersonalDebtThisMonth / totalJointThisMonth;
      debtSettlement = (1.0 - (debtRatio * 0.4)).clamp(0.3, 1.0);
    }

    final healthScore = FinancialHealthScore.calculate(
      budgetComplianceFactor: budgetCompliance,
      expenseBalanceFactor: expenseBalance,
      debtSettlementFactor: debtSettlement,
    );

    // 4. EYLEME DÖKÜLEBİLİR AKILLI TAVSİYELER (SMART ADVICES)
    final advices = <FinancialAdvice>[];

    // Tavsiye 1: Genel Tasarruf veya Aşım Durumu
    if (totalJointLastMonth > 0) {
      if (overallDifference < -100) {
        advices.add(
          FinancialAdvice(
            id: 'overall_savings',
            title: 'Geçen Aya Göre Tasarruf',
            description:
                'Harika! Ortak harcamalarınız geçen aya göre %${overallPercentageChange.abs().toStringAsFixed(1)} (${CurrencyFormatter.formatClean(overallDifference.abs())}) azaldı.',
            type: AdviceType.savings,
            priority: 1,
            potentialSavings: overallDifference.abs(),
          ),
        );
      } else if (overallDifference > 150) {
        advices.add(
          FinancialAdvice(
            id: 'overall_increase',
            title: 'Gider Artış Bildirimi',
            description:
                'Bu ayki ortak giderleriniz geçen aya göre %${overallPercentageChange.toStringAsFixed(1)} (${CurrencyFormatter.formatClean(overallDifference)}) arttı.',
            type: AdviceType.trend,
            priority: 2,
          ),
        );
      }
    }

    // Tavsiye 2: Kategori Yoğunlaşması ve Tasarruf Fırsatı
    if (totalJointThisMonth > 200 && categoryTrends.isNotEmpty) {
      final topCat = categoryTrends.first;
      final topCatShare = (topCat.thisMonthAmount / totalJointThisMonth) * 100;

      if (topCatShare >= 40.0) {
        final estimatedSavings = topCat.thisMonthAmount * 0.12; // %12 tasarruf potansiyeli
        advices.add(
          FinancialAdvice(
            id: 'category_dominance',
            title: '${topCat.category.displayName} Gider Yoğunluğu',
            description:
                'Bu ayki ortak bütçenizin %${topCatShare.toStringAsFixed(1)}\'i ${topCat.category.displayName} kalemine harcandı. Toplu veya planlı alımlarla yaklaşık ${CurrencyFormatter.formatClean(estimatedSavings)} tasarruf sağlayabilirsiniz.',
            type: AdviceType.savings,
            priority: 2,
            potentialSavings: estimatedSavings,
          ),
        );
      }
    }

    // Tavsiye 3: Tekil Kategoride Ani Sıçrama
    for (final trend in categoryTrends) {
      if (trend.lastMonthAmount > 100 && trend.percentageChange >= 35.0 && trend.difference >= 200) {
        advices.add(
          FinancialAdvice(
            id: 'category_surge_${trend.category.name}',
            title: '${trend.category.displayName} Kaleminde Hızlı Yükseliş',
            description:
                '${trend.category.displayName} giderleri geçen aya göre %${trend.percentageChange.toStringAsFixed(1)} (+${CurrencyFormatter.formatClean(trend.difference)}) yükseldi.',
            type: AdviceType.trend,
            priority: 3,
          ),
        );
        break; // En belirgin tek bir kategori uyarısı yeterlidir
      }
    }

    // Tavsiye 4: Ortaklar Arası Ödeme Yükü Dengesizliği
    if (members.length > 1 &&
        mostPaidMemberShare >= 0.70 &&
        totalJointThisMonth >= 500 &&
        mostPaidMemberName != null) {
      advices.add(
        FinancialAdvice(
          id: 'roommate_imbalance',
          title: 'Harcama Yükü Dağılımı',
          description:
              'Bu ayki ortak masrafların %${(mostPaidMemberShare * 100).toStringAsFixed(0)}\'i $mostPaidMemberName tarafından ödendi. Nakit akışı dengesi için sonraki ortak fişleri diğer ev arkadaşları üstlenebilir.',
          type: AdviceType.balance,
          priority: 4,
        ),
      );
    }

    // Tavsiye 5: Harcama Kaydı Olmadığında Nazik Bilgilendirme
    if (advices.isEmpty) {
      advices.add(
        FinancialAdvice(
          id: 'initial_state',
          title: 'Finansal Nabız Analizi Aktif',
          description:
              'Ortak giderler kaydedildikçe geçmiş ay karşılaştırmaları, kategori trendleri ve yapay tasarruf tavsiyeleri burada listelenecektir.',
          type: AdviceType.savings,
          priority: 5,
        ),
      );
    }

    // Önceliğe göre sırala (1 en yüksek)
    advices.sort((a, b) => a.priority.compareTo(b.priority));

    return HouseholdFinancialInsights(
      healthScore: healthScore,
      totalJointThisMonth: totalJointThisMonth,
      totalJointLastMonth: totalJointLastMonth,
      overallDifference: overallDifference,
      overallPercentageChange: overallPercentageChange,
      categoryTrends: categoryTrends,
      advices: advices,
    );
  }
}
