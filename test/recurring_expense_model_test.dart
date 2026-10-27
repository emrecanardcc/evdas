import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/recurring_expense.dart';

void main() {
  group('RecurringExpense Model Unit Tests', () {
    test('isDue: Gün geldiğinde ve bu ay işlenmediğinde true dönmelidir', () {
      final item = RecurringExpense(
        id: 'rec-1',
        householdId: 'h-1',
        title: 'Kira',
        amount: 15000.0,
        paidByMemberId: 'm-1',
        dayOfMonth: 10,
        cadence: RecurringCadence.monthly,
      );

      // Ayın 10'u -> Vadesi geldi
      expect(item.isDue(DateTime(2026, 10, 10)), isTrue);
      // Ayın 15'i -> Vadesi geçti ama bu ay işlenmedi, halen true dönmeli
      expect(item.isDue(DateTime(2026, 10, 15)), isTrue);
      // Ayın 5'i -> Henüz günü gelmedi
      expect(item.isDue(DateTime(2026, 10, 5)), isFalse);
    });

    test('isDue: Bu ay zaten işlendiyse tekrar true dönmemelidir (Çift çekim koruması)', () {
      final item = RecurringExpense(
        id: 'rec-1',
        householdId: 'h-1',
        title: 'Kira',
        amount: 15000.0,
        paidByMemberId: 'm-1',
        dayOfMonth: 1,
        lastExecutedDate: DateTime(2026, 10, 1),
      );

      // 10 Ekim'de kontrol edilirse, 1 Ekim'de zaten işlendiği için false dönmeli
      expect(item.isDue(DateTime(2026, 10, 10)), isFalse);

      // 1 Kasım olduğunda yeni ay başladığı için true dönmeli
      expect(item.isDue(DateTime(2026, 11, 1)), isTrue);
    });

    test('isDue: Pasif yapılmış masraflar asla due olmamalıdır', () {
      final item = RecurringExpense(
        id: 'rec-1',
        householdId: 'h-1',
        title: 'Netflix',
        amount: 250.0,
        paidByMemberId: 'm-1',
        dayOfMonth: 1,
        isActive: false,
      );

      expect(item.isDue(DateTime(2026, 10, 5)), isFalse);
    });

    test('nextDueDate: Doğru bir sonraki vade tarihini hesaplamalıdır', () {
      final item = RecurringExpense(
        id: 'rec-1',
        householdId: 'h-1',
        title: 'İnternet',
        amount: 450.0,
        paidByMemberId: 'm-1',
        dayOfMonth: 15,
      );

      // 10 Ekim'de kontrol edilirse -> 15 Ekim
      final next1 = item.nextDueDate(DateTime(2026, 10, 10));
      expect(next1, equals(DateTime(2026, 10, 15)));

      // 20 Ekim'de kontrol edilirse -> 15 Kasım
      final next2 = item.nextDueDate(DateTime(2026, 10, 20));
      expect(next2, equals(DateTime(2026, 11, 15)));
    });

    test('toJson ve fromJson serialization döngüsü eksiksiz çalışmalıdır', () {
      final item = RecurringExpense(
        id: 'rec-test',
        householdId: 'h-test',
        title: 'Aidat',
        amount: 1200.0,
        category: ExpenseCategory.kira,
        paidByMemberId: 'm-test',
        dayOfMonth: 5,
        cadence: RecurringCadence.monthly,
        autoPost: true,
        isActive: true,
        lastExecutedDate: DateTime(2026, 9, 5),
      );

      final json = item.toJson();
      final restored = RecurringExpense.fromJson(json);

      expect(restored.id, equals(item.id));
      expect(restored.title, equals(item.title));
      expect(restored.amount, equals(item.amount));
      expect(restored.category, equals(item.category));
      expect(restored.dayOfMonth, equals(item.dayOfMonth));
      expect(restored.lastExecutedDate, equals(item.lastExecutedDate));
    });
  });
}
