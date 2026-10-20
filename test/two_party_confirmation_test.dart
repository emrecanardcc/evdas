import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/payment_request.dart';
import 'package:evdas_mobile/domain/debt_engine.dart';

void main() {
  group('Çift Taraflı Karşılıklı Onay & Kısmi Ödeme Testleri', () {
    final ahmet = HouseholdMember(
      id: 'ahmet',
      householdId: 'h1',
      displayName: 'Ahmet',
    );
    final mehmet = HouseholdMember(
      id: 'mehmet',
      householdId: 'h1',
      displayName: 'Mehmet',
    );

    // Mehmet 1000 TL ortak harcadı, Ahmet 0 TL harcadı.
    // Ahmet'in Mehmet'e net 500 TL borcu var.
    final baseExpenses = [
      Expense(
        id: '1',
        householdId: 'h1',
        title: 'Ortak Fatura',
        amount: 1000.0,
        type: ExpenseType.joint,
        paidByMemberId: 'mehmet',
      ),
    ];

    test('Onay bekleyen (Pending) ödeme borçtan düşülmemelidir', () {
      final pendingPayment = PaymentRequest(
        id: 'pay-1',
        partnershipId: 'h1',
        fromMemberId: 'ahmet',
        fromMemberName: 'Ahmet',
        toMemberId: 'mehmet',
        toMemberName: 'Mehmet',
        amount: 300.0,
        status: PaymentStatus.pending,
      );

      final result = DebtEngine.calculate(
        members: [ahmet, mehmet],
        expenses: baseExpenses,
        paymentRequests: [pendingPayment],
      );

      // Borç hala 500 TL kalmalıdır (güvenlik kuralı)
      expect(result.netBalanceByMember['ahmet'], closeTo(-500.0, 0.01));
      expect(result.netBalanceByMember['mehmet'], closeTo(500.0, 0.01));
      expect(result.pendingPayments.length, 1);
    });

    test('Alacaklı tarafından onaylanan (Confirmed) kısmi ödeme borcu tam olarak düşürmelidir', () {
      final confirmedPayment = PaymentRequest(
        id: 'pay-2',
        partnershipId: 'h1',
        fromMemberId: 'ahmet',
        fromMemberName: 'Ahmet',
        toMemberId: 'mehmet',
        toMemberName: 'Mehmet',
        amount: 300.0,
        status: PaymentStatus.confirmed, // Mehmet kabul etti
      );

      final result = DebtEngine.calculate(
        members: [ahmet, mehmet],
        expenses: baseExpenses,
        paymentRequests: [confirmedPayment],
      );

      // 500 - 300 = 200 TL borç kalmalıdır!
      expect(result.netBalanceByMember['ahmet'], closeTo(-200.0, 0.01));
      expect(result.netBalanceByMember['mehmet'], closeTo(200.0, 0.01));
      expect(result.settlements.first.amount, closeTo(200.0, 0.01));
    });

    test('Reddedilen (Rejected) ödeme borçtan düşülmemelidir', () {
      final rejectedPayment = PaymentRequest(
        id: 'pay-3',
        partnershipId: 'h1',
        fromMemberId: 'ahmet',
        fromMemberName: 'Ahmet',
        toMemberId: 'mehmet',
        toMemberName: 'Mehmet',
        amount: 500.0,
        status: PaymentStatus.rejected, // Para hesaba geçmedi, Mehmet reddetti
      );

      final result = DebtEngine.calculate(
        members: [ahmet, mehmet],
        expenses: baseExpenses,
        paymentRequests: [rejectedPayment],
      );

      // Borç hala 500 TL kalmalıdır
      expect(result.netBalanceByMember['ahmet'], closeTo(-500.0, 0.01));
      expect(result.netBalanceByMember['mehmet'], closeTo(500.0, 0.01));
    });
  });
}
