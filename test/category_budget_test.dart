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
  group('Category Budget Model & Calculation Tests', () {
    test('getCategoryHealth, categoryRatio ve categoryRemaining doğru hesaplanmalıdır', () {
      final budget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 20000.0,
        categoryLimits: {
          ExpenseCategory.market: 5000.0,
          ExpenseCategory.fatura: 2000.0,
        },
        updatedAt: DateTime.now(),
      );

      // Market: 3000 / 5000 = %60 -> safe
      expect(budget.getCategoryHealth(ExpenseCategory.market, 3000.0), equals(BudgetHealth.safe));
      expect(budget.categoryRatio(ExpenseCategory.market, 3000.0), equals(0.6));
      expect(budget.categoryRemaining(ExpenseCategory.market, 3000.0), equals(2000.0));

      // Market: 4000 / 5000 = %80 -> warning
      expect(budget.getCategoryHealth(ExpenseCategory.market, 4000.0), equals(BudgetHealth.warning));
      expect(budget.categoryRatio(ExpenseCategory.market, 4000.0), equals(0.8));
      expect(budget.categoryRemaining(ExpenseCategory.market, 4000.0), equals(1000.0));

      // Fatura: 2500 / 2000 = %125 -> exceeded
      expect(budget.getCategoryHealth(ExpenseCategory.fatura, 2500.0), equals(BudgetHealth.exceeded));
      expect(budget.categoryRatio(ExpenseCategory.fatura, 2500.0), equals(1.25));
      expect(budget.categoryRemaining(ExpenseCategory.fatura, 2500.0), equals(0.0));

      // Tanımlanmamış kategori için varsayılan safe ve 0 dönmeli
      expect(budget.getCategoryHealth(ExpenseCategory.kira, 5000.0), equals(BudgetHealth.safe));
      expect(budget.categoryRatio(ExpenseCategory.kira, 5000.0), equals(0.0));
      expect(budget.categoryRemaining(ExpenseCategory.kira, 5000.0), equals(0.0));
    });
  });

  group('Category Budget Reminder & Service Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Kategori tavanı aşıldığında ReminderService kategoriye özel budgetAlert üretmelidir', () {
      final member = HouseholdMember(id: 'm-1', householdId: 'h-1', displayName: 'Ahmet');
      final house = Partnership(
        id: 'h-1',
        name: 'Ortak Ev',
        inviteCode: 'EV456',
        members: [member],
      );

      final now = DateTime(2026, 10, 25);
      final budget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 30000.0,
        categoryLimits: {
          ExpenseCategory.market: 4000.0,
        },
        alertAt100Percent: true,
        updatedAt: now,
      );

      final expense = Expense(
        id: 'e-1',
        householdId: 'h-1',
        title: 'Haftalık Market',
        amount: 4500.0,
        category: ExpenseCategory.market,
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

      final catAlert = reminders.firstWhere(
        (r) => r.id.contains('cat-budget-exceeded'),
      );
      expect(catAlert.type, equals(ReminderType.budgetAlert));
      expect(catAlert.title, contains('Market Bütçesi Aşıldı'));
      expect(catAlert.message, contains('4.000'));
      expect(catAlert.actionRoute, equals('reports'));
    });

    test('updateCategoryLimit kalıcı olarak güncellenmelidir', () async {
      final house = Partnership(
        id: 'h-1',
        name: 'Ortak Ev',
        inviteCode: 'EV456',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          householdProvider.overrideWith(() => _MockHouseholdNotifier(house)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(budgetProvider.notifier);
      await notifier.updateCategoryLimit(ExpenseCategory.market, 7500.0);

      final currentBudget = container.read(budgetProvider);
      expect(currentBudget?.categoryLimits[ExpenseCategory.market], equals(7500.0));
    });
  });
}

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership? _mock;
  _MockHouseholdNotifier(this._mock);
  @override
  Partnership? build() => _mock;
}
