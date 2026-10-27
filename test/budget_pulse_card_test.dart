import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/budget_service.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_budget.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/budget_pulse_card.dart';

void main() {
  group('BudgetPulseCard Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Bütçe kartı ve yüzdelik ilerleme çubuğu doğru render edilmelidir',
        (tester) async {
      final mockBudget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 20000.0,
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            budgetProvider.overrideWith(() => _MockBudgetNotifier(mockBudget)),
            currentMonthJointSpendProvider.overrideWithValue(10000.0), // %50
            currentMonthCategorySpendsProvider.overrideWithValue({}),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BudgetPulseCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aylık Ortak Bütçe'), findsOneWidget);
      expect(find.text('Bütçe Dengede'), findsOneWidget);
      expect(find.text('%50.0'), findsOneWidget);
      expect(find.textContaining('10.000'), findsWidgets);
      expect(find.textContaining('20.000'), findsWidgets);
    });

    testWidgets('Aşılmış bütçede "Limit Aşıldı" kırmızı durumu gösterilmelidir',
        (tester) async {
      final mockBudget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 10000.0,
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            budgetProvider.overrideWith(() => _MockBudgetNotifier(mockBudget)),
            currentMonthJointSpendProvider.overrideWithValue(12500.0), // %125
            currentMonthCategorySpendsProvider.overrideWithValue({}),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BudgetPulseCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Limit Aşıldı'), findsOneWidget);
      expect(find.text('%125.0'), findsOneWidget);
      expect(find.textContaining('aşıldı'), findsOneWidget);
    });

    testWidgets('Kategori tavanları tanımlandığında detay butonu ve çubuklar açılmalıdır',
        (tester) async {
      final mockBudget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 25000.0,
        categoryLimits: {
          ExpenseCategory.market: 8000.0,
          ExpenseCategory.fatura: 3000.0,
        },
        updatedAt: DateTime.now(),
      );

      final mockCatSpends = {
        ExpenseCategory.market: 4000.0, // %50
        ExpenseCategory.fatura: 3200.0, // %106.6
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            budgetProvider.overrideWith(() => _MockBudgetNotifier(mockBudget)),
            currentMonthJointSpendProvider.overrideWithValue(7200.0),
            currentMonthCategorySpendsProvider.overrideWithValue(mockCatSpends),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: BudgetPulseCard()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kategori Detayları butonu görünür olmalı
      final toggleButton = find.textContaining('Kategori Limitleri');
      expect(toggleButton, findsOneWidget);

      // Tıklanıp kategori detayları açılmalı
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('Market'), findsOneWidget);
      expect(find.text('Fatura'), findsOneWidget);
    });
  });
}

class _MockBudgetNotifier extends BudgetNotifier {
  final HouseholdBudget? _initial;
  _MockBudgetNotifier(this._initial);

  @override
  HouseholdBudget? build() => _initial;
}
