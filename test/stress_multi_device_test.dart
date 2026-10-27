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
    var house = await repo.createPartnership(
      name: 'Kadıköy Evi Çok Uzun Bir Ortaklık İsmi Testi',
      type: PartnershipType.home,
      creatorName: 'Ahmet Uzun İsimli Ortak',
    );
    await repo.addMemberToHousehold('Mehmet Ali İkinci Uzun İsim', iban: 'TR123456789012345678901234');
    await repo.addMemberToHousehold('Ayşe Üçüncü Kişi', iban: 'TR987654321098765432109876');
    house = repo.getActiveHousehold()!;
    await repo.addExpense(
      Expense(
        id: 'exp-1',
        householdId: house.id,
        title: 'Büyük Süpermarket ve Şarküteri Alışverişi Fiş No 123456789',
        amount: 350.75,
        type: ExpenseType.joint,
        category: ExpenseCategory.market,
        paidByMemberId: house.members.first.id,
        expenseDate: DateTime.now(),
      ),
    );
    await repo.addExpense(
      Expense(
        id: 'exp-2',
        householdId: house.id,
        title: 'Özel Sinema ve Yemek Borcu',
        amount: 150.0,
        type: ExpenseType.personalDebt,
        category: ExpenseCategory.diger,
        paidByMemberId: house.members.first.id,
        debtorMemberId: house.members[1].id,
        expenseDate: DateTime.now(),
      ),
    );
  });

  final viewports = [
    const Size(280, 480), // Ultra dar (Galaxy Fold cover)
    const Size(320, 568), // Compact (iPhone SE)
    const Size(360, 640), // Standart Android
    const Size(390, 844), // Modern iPhone
    const Size(412, 915), // Büyük Android
    const Size(768, 1024), // Tablet
    const Size(800, 400), // Yatay (Landscape)
  ];

  final textScales = [1.0, 1.4, 1.8]; // Erişilebilirlik yazı boyutu çarpanları

  for (final vp in viewports) {
    for (final scale in textScales) {
      testWidgets('Stress test QuickExpenseScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const QuickExpenseScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('Stress test HouseholdScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const HouseholdScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('Stress test SettlementScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const SettlementScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('Stress test ReportsScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const ReportsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('Stress test DecisionWheelScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const DecisionWheelScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('Stress test ExpensesScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const ExpensesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('Stress test HomeScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('Stress test AuthScreen ${vp.width}x${vp.height} scale:$scale', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [expenseRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const AuthScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });
    }
  }
}
