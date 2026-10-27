import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/core/services/burn_rate_engine.dart';
import 'package:evdas_mobile/core/services/reminder_service.dart';
import 'package:evdas_mobile/data/models/burn_rate_analysis.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_budget.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';

void main() {
  group('BurnRateEngine Calculation Tests', () {
    test('Dengeli tempo (onTrack): Bütçe altında kalan harcama hızı', () {
      // 30 günlük ayın 10. günündeyiz. Bütçe 30.000 TL, harcanan 6.000 TL (600 TL/gün)
      // Ay sonu tahmini = 600 * 30 = 18.000 TL (%60 -> onTrack)
      final now = DateTime(2026, 4, 10); // Nisan 30 gündür
      final result = BurnRateEngine.calculate(
        monthlyLimit: 30000.0,
        currentSpent: 6000.0,
        now: now,
      );

      expect(result.daysElapsed, equals(10));
      expect(result.daysInMonth, equals(30));
      expect(result.daysRemaining, equals(20));
      expect(result.dailyVelocity, equals(600.0));
      expect(result.projectedMonthEndSpend, equals(18000.0));
      expect(result.projectedVariance, equals(-12000.0));
      expect(result.status, equals(BurnRateStatus.onTrack));
      expect(result.budgetDepletionDay, isNull);
      expect(result.safeDailyRemainingBudget, equals(1200.0)); // (30.000 - 6.000) / 20 = 1.200 TL/gün
      expect(result.smartRecommendation, contains('Harcama temponuz dengeli'));
    });

    test('Hafif aşım riski (warning): %100 - %115 arası öngörü', () {
      // 31 günlük ayın 10. günündeyiz. Bütçe 31.000 TL, harcanan 11.000 TL (1.100 TL/gün)
      // Ay sonu tahmini = 1.100 * 31 = 34.100 TL (%110 -> warning)
      final now = DateTime(2026, 10, 10); // Ekim 31 gündür
      final result = BurnRateEngine.calculate(
        monthlyLimit: 31000.0,
        currentSpent: 11000.0,
        now: now,
      );

      expect(result.daysElapsed, equals(10));
      expect(result.daysInMonth, equals(31));
      expect(result.daysRemaining, equals(21));
      expect(result.dailyVelocity, equals(1100.0));
      expect(result.projectedMonthEndSpend, equals(34100.0));
      expect(result.projectedVariance, equals(3100.0));
      expect(result.status, equals(BurnRateStatus.warning));
      expect(result.budgetDepletionDay, equals(28)); // 31.000 / 1.100 = 28. gün
      expect(result.smartRecommendation, contains('Hafif bütçe aşım riski'));
    });

    test('Kritik aşım riski (critical): %115 üzeri öngörü ve tükenme günü', () {
      // 31 günlük ayın 10. günündeyiz. Bütçe 20.000 TL, harcanan 10.000 TL (1.000 TL/gün)
      // Ay sonu tahmini = 1.000 * 31 = 31.000 TL (%155 -> critical)
      final now = DateTime(2026, 10, 10);
      final result = BurnRateEngine.calculate(
        monthlyLimit: 20000.0,
        currentSpent: 10000.0,
        now: now,
      );

      expect(result.status, equals(BurnRateStatus.critical));
      expect(result.projectedMonthEndSpend, equals(31000.0));
      expect(result.projectedVariance, equals(11000.0));
      expect(result.budgetDepletionDay, equals(20)); // 20.000 / 1.000 = 20. gün
      expect(result.safeDailyRemainingBudget, equals(10000.0 / 21));
      expect(result.smartRecommendation, contains('Yüksek aşım riski'));
      expect(result.smartRecommendation, contains('20. gününde'));
    });

    test('Bütçe tavanı şimdiden aşıldığında özel tavsiye sunulmalıdır', () {
      final now = DateTime(2026, 10, 15);
      final result = BurnRateEngine.calculate(
        monthlyLimit: 15000.0,
        currentSpent: 16000.0,
        now: now,
      );

      expect(result.status, equals(BurnRateStatus.critical));
      expect(result.safeDailyRemainingBudget, equals(0.0));
      expect(result.smartRecommendation, contains('Aylık bütçe tavanı tamamen aşıldı'));
    });

    test('Artık yıl (29 Şubat) ve sınır durumlar deterministik hesaplanmalıdır', () {
      // 2028 artık yıldır, Şubat 29 gündür
      final leapNow = DateTime(2028, 2, 1);
      final leapResult = BurnRateEngine.calculate(
        monthlyLimit: 29000.0,
        currentSpent: 1000.0,
        now: leapNow,
      );

      expect(leapResult.daysInMonth, equals(29));
      expect(leapResult.daysElapsed, equals(1));
      expect(leapResult.daysRemaining, equals(28));
      expect(leapResult.projectedMonthEndSpend, equals(29000.0));
      expect(leapResult.status, equals(BurnRateStatus.onTrack));

      // Bütçe 0 tanımlı olduğunda güvenli fallback
      final zeroResult = BurnRateEngine.calculate(
        monthlyLimit: 0.0,
        currentSpent: 500.0,
        now: leapNow,
      );
      expect(zeroResult.monthlyLimit, equals(0.0));
      expect(zeroResult.status, equals(BurnRateStatus.onTrack));
    });

    test('toJson ve fromJson serileştirmesi eksiksiz olmalıdır', () {
      final now = DateTime(2026, 10, 15);
      final original = BurnRateEngine.calculate(
        monthlyLimit: 25000.0,
        currentSpent: 12500.0,
        now: now,
      );

      final json = original.toJson();
      final restored = BurnRateAnalysis.fromJson(json);

      expect(restored.monthlyLimit, equals(original.monthlyLimit));
      expect(restored.currentSpent, equals(original.currentSpent));
      expect(restored.dailyVelocity, equals(original.dailyVelocity));
      expect(restored.status, equals(original.status));
      expect(restored.smartRecommendation, equals(original.smartRecommendation));
    });
  });

  group('BurnRate Warning Reminder Integration Tests', () {
    test('Harcama hızı kritik olduğunda ReminderService burnRateWarning üretmelidir', () {
      final member = HouseholdMember(id: 'm-1', householdId: 'h-1', displayName: 'Mehmet');
      final house = Partnership(
        id: 'h-1',
        name: 'Kadıköy Evi',
        inviteCode: 'EV789',
        members: [member],
      );

      // Ayın 10'unda 20.000 TL bütçe var, harcanan 12.000 TL (%60 ama günün 10. gününde hız çok yüksek)
      final now = DateTime(2026, 10, 10);
      final budget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 20000.0,
        alertAt80Percent: true,
        updatedAt: now,
      );

      final expense = Expense(
        id: 'e-speed-1',
        householdId: 'h-1',
        title: 'Hızlı Masraf',
        amount: 12000.0,
        paidByMemberId: 'm-1',
        expenseDate: now,
        type: ExpenseType.joint,
      );

      final reminders = ReminderService.evaluate(
        house: house,
        expenses: [expense],
        approvals: [],
        payments: [],
        currentMember: member,
        budget: budget,
        now: now,
      );

      final burnReminder =
          reminders.where((r) => r.type == ReminderType.burnRateWarning).firstOrNull;
      expect(burnReminder, isNotNull);
      expect(burnReminder!.title, contains('Harcama Temposu Kritik Seviyede'));
      expect(burnReminder.actionRoute, equals('reports'));
      expect(burnReminder.actionLabel, equals('Analizi Gör'));
    });
  });
}
