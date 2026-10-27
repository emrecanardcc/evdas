import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_budget.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/domain/financial_insights_engine.dart';

void main() {
  group('FinancialInsightsEngine Unit Tests', () {
    final member1 = HouseholdMember(id: 'm-1', householdId: 'h-1', displayName: 'Ahmet');
    final member2 = HouseholdMember(id: 'm-2', householdId: 'h-1', displayName: 'Mehmet');
    final members = [member1, member2];

    final refDate = DateTime(2026, 10, 15); // Ekim 2026

    test('Geçen aya göre harcama farkı ve yüzde değişimi doğru hesaplanmalıdır', () {
      final expenses = [
        // Bu Ay (Ekim 2026): Market = 3.000 TL
        Expense(
          id: 'e-1',
          householdId: 'h-1',
          title: 'Market Alışverişi',
          amount: 3000.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.market,
          paidByMemberId: 'm-1',
          expenseDate: DateTime(2026, 10, 5),
        ),
        // Geçen Ay (Eylül 2026): Market = 2.000 TL
        Expense(
          id: 'e-2',
          householdId: 'h-1',
          title: 'Geçen Ay Market',
          amount: 2000.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.market,
          paidByMemberId: 'm-1',
          expenseDate: DateTime(2026, 9, 20),
        ),
      ];

      final insights = FinancialInsightsEngine.analyze(
        expenses: expenses,
        members: members,
        referenceDate: refDate,
      );

      expect(insights.totalJointThisMonth, equals(3000.0));
      expect(insights.totalJointLastMonth, equals(2000.0));
      expect(insights.overallDifference, equals(1000.0));
      expect(insights.overallPercentageChange, equals(50.0));
      expect(insights.hasPreviousMonthData, isTrue);
      expect(insights.hasIncreasedOverall, isTrue);
      expect(insights.hasSavedOverall, isFalse);

      final marketTrend = insights.categoryTrends.firstWhere((t) => t.category == ExpenseCategory.market);
      expect(marketTrend.thisMonthAmount, equals(3000.0));
      expect(marketTrend.lastMonthAmount, equals(2000.0));
      expect(marketTrend.difference, equals(1000.0));
      expect(marketTrend.percentageChange, equals(50.0));
      expect(marketTrend.formattedDifference, equals('+1.000 ₺'));
    });

    test('Geçen ay veri olmadığında sıfıra bölme hatası vermemeli ve güvenli değer dönmelidir', () {
      final expenses = [
        Expense(
          id: 'e-1',
          householdId: 'h-1',
          title: 'İlk Harcama',
          amount: 1500.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.fatura,
          paidByMemberId: 'm-1',
          expenseDate: DateTime(2026, 10, 10),
        ),
      ];

      final insights = FinancialInsightsEngine.analyze(
        expenses: expenses,
        members: members,
        referenceDate: refDate,
      );

      expect(insights.totalJointThisMonth, equals(1500.0));
      expect(insights.totalJointLastMonth, equals(0.0));
      expect(insights.hasPreviousMonthData, isFalse);
      expect(insights.overallPercentageChange, equals(100.0));
      expect(insights.advices.isNotEmpty, isTrue);
    });

    test('Finansal sağlık skoru bütçeye ve harcama dengesine göre dinamik puanlanmalıdır', () {
      final budget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 10000.0,
        updatedAt: DateTime.now(),
      );

      // Durum A: 4.000 TL harcama (%40 bütçe) ve her iki ortak eşit 2.000 TL ödedi
      final balancedExpenses = [
        Expense(
          id: 'e-1',
          householdId: 'h-1',
          title: 'Harcama 1',
          amount: 2000.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.market,
          paidByMemberId: 'm-1',
          expenseDate: DateTime(2026, 10, 2),
        ),
        Expense(
          id: 'e-2',
          householdId: 'h-1',
          title: 'Harcama 2',
          amount: 2000.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.fatura,
          paidByMemberId: 'm-2',
          expenseDate: DateTime(2026, 10, 3),
        ),
      ];

      final healthyInsights = FinancialInsightsEngine.analyze(
        expenses: balancedExpenses,
        members: members,
        budget: budget,
        referenceDate: refDate,
      );

      expect(healthyInsights.healthScore.score, greaterThanOrEqualTo(80));
      expect(healthyInsights.healthScore.title, equals('Mükemmel Uyum'));

      // Durum B: Bütçe aşıldı (12.000 TL)
      final exceededExpenses = [
        Expense(
          id: 'e-3',
          householdId: 'h-1',
          title: 'Büyük Harcama',
          amount: 12000.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.kira,
          paidByMemberId: 'm-1',
          expenseDate: DateTime(2026, 10, 4),
        ),
      ];

      final exceededInsights = FinancialInsightsEngine.analyze(
        expenses: exceededExpenses,
        members: members,
        budget: budget,
        referenceDate: refDate,
      );

      expect(exceededInsights.healthScore.score, lessThan(60));
    });

    test('Tek bir ortak üzerinde yoğunlaşan ödemelerde harcama dengesi tavsiyesi üretilmelidir', () {
      final imbalancedExpenses = [
        Expense(
          id: 'e-1',
          householdId: 'h-1',
          title: 'Kira ve Masraflar',
          amount: 10000.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.kira,
          paidByMemberId: 'm-1', // Ahmet tek başına %100 ödedi
          expenseDate: DateTime(2026, 10, 1),
        ),
      ];

      final insights = FinancialInsightsEngine.analyze(
        expenses: imbalancedExpenses,
        members: members,
        referenceDate: refDate,
      );

      final balanceAdvice = insights.advices.where((a) => a.id == 'roommate_imbalance').firstOrNull;
      expect(balanceAdvice, isNotNull);
      expect(balanceAdvice!.title, equals('Harcama Yükü Dağılımı'));
      expect(balanceAdvice.description, contains('Ahmet'));
    });

    test('Belirgin bir kategoride yoğunlaşma olduğunda tasarruf tavsiyesi hesaplanmalıdır', () {
      final dominantCategoryExpenses = [
        Expense(
          id: 'e-1',
          householdId: 'h-1',
          title: 'Haftalık Market',
          amount: 4000.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.market,
          paidByMemberId: 'm-1',
          expenseDate: DateTime(2026, 10, 1),
        ),
        Expense(
          id: 'e-2',
          householdId: 'h-1',
          title: 'Küçük Kahve',
          amount: 200.0,
          type: ExpenseType.joint,
          category: ExpenseCategory.diger,
          paidByMemberId: 'm-2',
          expenseDate: DateTime(2026, 10, 2),
        ),
      ];

      final insights = FinancialInsightsEngine.analyze(
        expenses: dominantCategoryExpenses,
        members: members,
        referenceDate: refDate,
      );

      final dominanceAdvice = insights.advices.where((a) => a.id == 'category_dominance').firstOrNull;
      expect(dominanceAdvice, isNotNull);
      expect(dominanceAdvice!.title, contains('Market'));
      expect(dominanceAdvice.potentialSavings, isNotNull);
      expect(dominanceAdvice.potentialSavings!, greaterThan(0));
    });
  });
}
