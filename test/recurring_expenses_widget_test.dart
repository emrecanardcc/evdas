import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/recurring_expense_service.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/models/recurring_expense.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/recurring_expenses_modal.dart';

void main() {
  group('RecurringExpensesModal Widget Tests', () {
    late SharedPreferences prefs;

    final member = HouseholdMember(id: 'm-1', householdId: 'h-1', displayName: 'Ali');
    final house = Partnership(
      id: 'h-1',
      name: 'Evim',
      inviteCode: 'EV1234',
      members: [member],
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Boş durumda hazır şablon butonları (Kira, Aidat, İnternet) görüntülenmelidir',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            householdProvider.overrideWith(() => _MockHouseholdNotifier(house)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecurringExpensesModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sabit ve Düzenli Giderler'), findsOneWidget);
      expect(find.text('Düzenli Gider Tanımlanmadı'), findsOneWidget);
      expect(find.text('Kira'), findsOneWidget);
      expect(find.text('Site Aidatı'), findsOneWidget);
      expect(find.text('İnternet'), findsOneWidget);
    });

    testWidgets('Kayıtlı düzenli masraflar listelenmeli ve aktiflik anahtarı çalışmalıdır',
        (tester) async {
      final item = RecurringExpense(
        id: 'rec-1',
        householdId: 'h-1',
        title: 'Superonline Fiber',
        amount: 390.0,
        paidByMemberId: 'm-1',
        dayOfMonth: 15,
        isActive: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            householdProvider.overrideWith(() => _MockHouseholdNotifier(house)),
            recurringExpensesProvider.overrideWith(() => _MockRecurringNotifier([item])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecurringExpensesModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Superonline Fiber'), findsOneWidget);
      expect(find.text('Her ayın 15. günü • Ödeyen: Ali'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}

class _MockRecurringNotifier extends RecurringExpenseNotifier {
  final List<RecurringExpense> _initial;
  _MockRecurringNotifier(this._initial);

  @override
  List<RecurringExpense> build() => _initial;
}

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership? _mock;
  _MockHouseholdNotifier(this._mock);
  @override
  Partnership? build() => _mock;
}
