import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/budget_service.dart';
import 'package:evdas_mobile/core/services/reminder_service.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_budget.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';

void main() {
  group('HouseholdBudget Model Tests', () {
    test('getHealth, ratio ve remaining doğru hesaplanmalıdır', () {
      final budget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 20000.0,
        updatedAt: DateTime.now(),
      );

      // 10.000 TL (%50) -> safe
      expect(budget.getHealth(10000.0), equals(BudgetHealth.safe));
      expect(budget.ratio(10000.0), equals(0.5));
      expect(budget.remaining(10000.0), equals(10000.0));

      // 16.000 TL (%80) -> warning
      expect(budget.getHealth(16000.0), equals(BudgetHealth.warning));
      expect(budget.ratio(16000.0), equals(0.8));
      expect(budget.remaining(16000.0), equals(4000.0));

      // 21.000 TL (%105) -> exceeded
      expect(budget.getHealth(21000.0), equals(BudgetHealth.exceeded));
      expect(budget.ratio(21000.0), equals(1.05));
      expect(budget.remaining(21000.0), equals(0.0));
    });

    test('toJson ve fromJson dönüşümü eksiksiz çalışmalıdır', () {
      final budget = HouseholdBudget(
        householdId: 'h-test',
        monthlyLimit: 30000.0,
        categoryLimits: const {ExpenseCategory.market: 12000.0},
        alertAt80Percent: true,
        alertAt100Percent: false,
        updatedAt: DateTime(2026, 10, 1),
      );

      final json = budget.toJson();
      final restored = HouseholdBudget.fromJson(json);

      expect(restored.householdId, equals(budget.householdId));
      expect(restored.monthlyLimit, equals(budget.monthlyLimit));
      expect(restored.categoryLimits[ExpenseCategory.market], equals(12000.0));
      expect(restored.alertAt80Percent, isTrue);
      expect(restored.alertAt100Percent, isFalse);
    });
  });

  group('BudgetNotifier & Reminder Integration Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Bütçe limiti güncelleme kalıcı olmalıdır', () async {
      final house = Partnership(
        id: 'h-1',
        name: 'Evim',
        inviteCode: 'EV123',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          householdProvider.overrideWith(() => _MockHouseholdNotifier(house)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(budgetProvider.notifier);
      expect(container.read(budgetProvider)?.monthlyLimit, equals(25000.0));

      await notifier.updateMonthlyLimit(40000.0);
      expect(container.read(budgetProvider)?.monthlyLimit, equals(40000.0));
    });

    test('Bütçe %100 aşıldığında ReminderService budgetAlert bildirimi üretmelidir', () {
      final member = HouseholdMember(id: 'm-1', householdId: 'h-1', displayName: 'Ali');
      final house = Partnership(
        id: 'h-1',
        name: 'Evim',
        inviteCode: 'EV123',
        members: [member],
      );

      final budget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 10000.0,
        updatedAt: DateTime.now(),
      );

      final now = DateTime(2026, 10, 20);
      final expense = Expense(
        id: 'e-1',
        householdId: 'h-1',
        title: 'Büyük Alışveriş',
        amount: 11000.0,
        paidByMemberId: 'm-1',
        expenseDate: now,
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

      final alert = reminders.where((r) => r.type == ReminderType.budgetAlert).firstOrNull;
      expect(alert, isNotNull);
      expect(alert!.title, contains('Aylık Ortak Bütçe Aşıldı'));
      expect(alert.actionRoute, equals('reports'));
    });
  });
}

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership? _mock;
  _MockHouseholdNotifier(this._mock);
  @override
  Partnership? build() => _mock;
}
