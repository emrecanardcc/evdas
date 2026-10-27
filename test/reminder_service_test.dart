import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/core/services/reminder_service.dart';
import 'package:evdas_mobile/data/models/approval_request.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/models/payment_request.dart';

void main() {
  group('ReminderService Unit Tests', () {
    final member1 = HouseholdMember(id: 'm1', householdId: 'house-1', displayName: 'Ahmet');
    final member2 = HouseholdMember(id: 'm2', householdId: 'house-1', displayName: 'Mehmet');

    final testHouse = Partnership(
      id: 'house-1',
      name: 'Öğrenci Evi',
      inviteCode: 'TEST12',
      settlementDay: 15,
      members: [member1, member2],
    );

    test('Bugün hesaplaşma günü ise settlementDay hatırlatıcısı üretilmelidir', () {
      final now = DateTime(2026, 10, 15); // Ayın 15'i

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [],
        approvals: [],
        payments: [],
        currentMember: member1,
        now: now,
      );

      final settlementReminder = reminders
          .where((r) => r.type == ReminderType.settlementDay)
          .firstOrNull;

      expect(settlementReminder, isNotNull);
      expect(settlementReminder!.title, contains('Hesaplaşma Vakti Geldi'));
      expect(settlementReminder.actionRoute, equals('settlement'));
    });

    test('Hesaplaşmaya 2 gün kala settlementApproaching hatırlatıcısı üretilmelidir', () {
      final now = DateTime(2026, 10, 13); // 15 - 13 = 2 gün

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [],
        approvals: [],
        payments: [],
        currentMember: member1,
        now: now,
      );

      final approachingReminder = reminders
          .where((r) => r.type == ReminderType.settlementApproaching)
          .firstOrNull;

      expect(approachingReminder, isNotNull);
      expect(approachingReminder!.message, contains('2 gün kaldı'));
    });

    test('Bekleyen onay talebi varsa pendingApproval hatırlatıcısı üretilmelidir', () {
      final approval = ApprovalRequest(
        id: 'req-1',
        partnershipId: 'house-1',
        type: ApprovalType.expenseDelete,
        targetId: 'exp-1',
        title: 'Kira Ödemesi',
        requestedByMemberId: 'm2',
        requestedByName: 'Mehmet',
        requiredCount: 2,
      );

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [],
        approvals: [approval],
        payments: [],
        currentMember: member1,
      );

      final reqReminder = reminders
          .where((r) => r.type == ReminderType.pendingApproval)
          .firstOrNull;

      expect(reqReminder, isNotNull);
      expect(reqReminder!.title, contains('Oyunuzu Bekleyen'));
      expect(reqReminder.actionRoute, equals('approvals'));
    });

    test('Kullanıcıya ödeme bildirildiğinde pendingPayment hatırlatıcısı üretilmelidir', () {
      final payment = PaymentRequest(
        id: 'pay-1',
        partnershipId: 'house-1',
        fromMemberId: 'm2',
        fromMemberName: 'Mehmet',
        toMemberId: 'm1',
        toMemberName: 'Ahmet',
        amount: 350.0,
      );

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [],
        approvals: [],
        payments: [payment],
        currentMember: member1,
      );

      final payReminder = reminders
          .where((r) => r.type == ReminderType.pendingPayment)
          .firstOrNull;

      expect(payReminder, isNotNull);
      expect(payReminder!.title, contains('Ödeme Doğrulaması'));
      expect(payReminder.message, contains('350'));
    });

    test('Ortak borç 250 TL üzerindeyse highDebt uyarısı üretilmelidir', () {
      // Mehmet 800 TL ortak harcama yaptı (Ahmet'in payı 400 TL, borçlu)
      final expense = Expense(
        id: 'e1',
        householdId: 'house-1',
        title: 'Büyük Market',
        amount: 800.0,
        paidByMemberId: 'm2',
        expenseDate: DateTime.now(),
      );

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [expense],
        approvals: [],
        payments: [],
        currentMember: member1, // Ahmet borçlu
      );

      final debtReminder = reminders
          .where((r) => r.type == ReminderType.highDebt)
          .firstOrNull;

      expect(debtReminder, isNotNull);
      expect(debtReminder!.title, contains('Borç Bakiyesi'));
      expect(debtReminder.message, contains('Mehmet'));
    });

    test('Son harcama 5 gün önceyse expenseInactivity uyarısı üretilmelidir', () {
      final oldExpense = Expense(
        id: 'e-old',
        householdId: 'house-1',
        title: 'Eski Market',
        amount: 100.0,
        paidByMemberId: 'm1',
        expenseDate: DateTime(2026, 10, 1),
      );

      final now = DateTime(2026, 10, 7); // 6 gün sonra

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [oldExpense],
        approvals: [],
        payments: [],
        currentMember: member1,
        now: now,
      );

      final inactivityReminder = reminders
          .where((r) => r.type == ReminderType.expenseInactivity)
          .firstOrNull;

      expect(inactivityReminder, isNotNull);
      expect(inactivityReminder!.title, contains('Unutulan Masraf Var mı?'));
    });

    test('Kaldırılan (dismissed) hatırlatıcılar listelenmemelidir', () {
      final now = DateTime(2026, 10, 15);
      final settlementId = 'settlement-today-house-1-2026-10-15';

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [],
        approvals: [],
        payments: [],
        currentMember: member1,
        now: now,
        dismissedIds: {settlementId},
      );

      expect(reminders.any((r) => r.id == settlementId), isFalse);
    });

    test('Okunmuş (read) hatırlatıcıların isRead durumu doğru yansıtılmalıdır', () {
      final now = DateTime(2026, 10, 15);
      final settlementId = 'settlement-today-house-1-2026-10-15';

      final reminders = ReminderService.evaluate(
        house: testHouse,
        expenses: [],
        approvals: [],
        payments: [],
        currentMember: member1,
        now: now,
        readIds: {settlementId},
      );

      final settlementReminder = reminders.firstWhere((r) => r.id == settlementId);
      expect(settlementReminder.isRead, isTrue);
    });
  });
}
