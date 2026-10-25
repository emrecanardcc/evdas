import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/screens/auth_screen.dart';
import 'package:evdas_mobile/presentation/screens/decision_wheel_screen.dart';
import 'package:evdas_mobile/presentation/screens/expenses_screen.dart';
import 'package:evdas_mobile/presentation/screens/home_screen.dart';
import 'package:evdas_mobile/presentation/screens/household_screen.dart';
import 'package:evdas_mobile/presentation/screens/quick_expense_screen.dart';
import 'package:evdas_mobile/presentation/screens/reports_screen.dart';
import 'package:evdas_mobile/presentation/screens/settlement_screen.dart';

void main() {
  late ExpenseRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = await ExpenseRepository.init();
    final house = await repo.createPartnership(
      name: 'Kadıköy Evi',
      type: PartnershipType.home,
      creatorName: 'Ahmet',
    );
    await repo.addMemberToHousehold('Mehmet', iban: 'TR123456789012345678901234');
    await repo.addExpense(
      Expense(
        id: 'exp-1',
        householdId: house.id,
        title: 'Büyük Market Alışverişi',
        amount: 350.0,
        type: ExpenseType.joint,
        category: ExpenseCategory.market,
        paidByMemberId: house.members.first.id,
        expenseDate: DateTime.now(),
      ),
    );
  });

  testWidgets('QuickExpenseScreen test at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: QuickExpenseScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('ExpensesScreen test at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('ReportsScreen test at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('SettlementScreen test at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: SettlementScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('DecisionWheelScreen test at 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: DecisionWheelScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('AuthScreen test at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('HouseholdScreen test at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HouseholdScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('HouseholdScreen test at 320x568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HouseholdScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('HomeScreen test at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  });
}
