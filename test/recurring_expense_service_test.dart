import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/recurring_expense_service.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/models/recurring_expense.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';

void main() {
  group('RecurringExpenseService Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('addRecurring, toggleActive ve deleteRecurring akışı', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recurringExpensesProvider.notifier);

      final item = RecurringExpense(
        id: 'rec-1',
        householdId: 'h-1',
        title: 'Fiber İnternet',
        amount: 350.0,
        paidByMemberId: 'm-1',
        dayOfMonth: 1,
      );

      await notifier.addRecurring(item);

      var list = container.read(recurringExpensesProvider);
      expect(list.length, equals(1));
      expect(list.first.title, equals('Fiber İnternet'));
      expect(list.first.isActive, isTrue);

      // Pasife al
      await notifier.toggleActive('rec-1');
      list = container.read(recurringExpensesProvider);
      expect(list.first.isActive, isFalse);

      // Sil
      await notifier.deleteRecurring('rec-1');
      list = container.read(recurringExpensesProvider);
      expect(list.isEmpty, isTrue);
    });

    test('processDueExpenses: Vadesi gelen masrafları Expense olarak eklemeli ve lastExecutedDate güncellemelidir', () async {
      final member = HouseholdMember(id: 'm-1', householdId: 'h-1', displayName: 'Ali');
      final house = Partnership(
        id: 'h-1',
        name: 'Evim',
        inviteCode: 'EV1234',
        members: [member],
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          expenseRepositoryProvider.overrideWithValue(ExpenseRepository(prefs)),
          householdProvider.overrideWith(() => _MockHouseholdNotifier(house)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recurringExpensesProvider.notifier);

      final item = RecurringExpense(
        id: 'rec-kira',
        householdId: 'h-1',
        title: 'Kira',
        amount: 20000.0,
        category: ExpenseCategory.kira,
        paidByMemberId: 'm-1',
        dayOfMonth: 5,
        autoPost: true,
      );

      await notifier.addRecurring(item);

      // 10 Ekim'de çalıştır (Vadesi gelmiş)
      final generated = await notifier.processDueExpenses(
        'h-1',
        now: DateTime(2026, 10, 10),
      );

      expect(generated.length, equals(1));
      expect(generated.first.title, equals('Kira'));
      expect(generated.first.amount, equals(20000.0));
      expect(generated.first.category, equals(ExpenseCategory.kira));

      // Kontrol et: lastExecutedDate güncellenmiş olmalı
      final updatedList = container.read(recurringExpensesProvider);
      expect(updatedList.first.lastExecutedDate, isNotNull);

      // Aynı ay tekrar çalıştırıldığında tekrar harcama üretmemeli
      final secondRun = await notifier.processDueExpenses(
        'h-1',
        now: DateTime(2026, 10, 11),
      );
      expect(secondRun.isEmpty, isTrue);
    });
  });
}

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership? _mock;
  _MockHouseholdNotifier(this._mock);
  @override
  Partnership? build() => _mock;
}

