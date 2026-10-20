import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/domain/debt_engine.dart';

void main() {
  group('DebtEngine Tests', () {
    final ahmet = HouseholdMember(
      id: 'ahmet-id',
      householdId: 'house-1',
      displayName: 'Ahmet',
    );

    final mehmet = HouseholdMember(
      id: 'mehmet-id',
      householdId: 'house-1',
      displayName: 'Mehmet',
    );

    test('Çoklu Dönem Kapsamlı Masraf ve Borç Mahsuplaşma Testi', () {
      final expenses = <Expense>[
        // 1. Dönem Ortak Harcamalar
        Expense(
          id: '1',
          householdId: 'house-1',
          title: 'Market ve Mutfak Harcamaları',
          amount: 2726.0,
          type: ExpenseType.joint,
          paidByMemberId: 'ahmet-id',
        ),
        Expense(
          id: '2',
          householdId: 'house-1',
          title: 'Kira ve Aidat Ödemesi',
          amount: 5789.0,
          type: ExpenseType.joint,
          paidByMemberId: 'mehmet-id',
        ),

        // 2. Dönem Ortak Harcamalar
        Expense(
          id: '3',
          householdId: 'house-1',
          title: 'Elektrik ve Doğalgaz Faturası',
          amount: 1240.0,
          type: ExpenseType.joint,
          paidByMemberId: 'ahmet-id',
        ),
        Expense(
          id: '4',
          householdId: 'house-1',
          title: 'İnternet ve Su Dolumu',
          amount: 200.0,
          type: ExpenseType.joint,
          paidByMemberId: 'mehmet-id',
        ),

        // Şahsi Borçlar
        Expense(
          id: '5',
          householdId: 'house-1',
          title: 'Şahsi İlaç Alımı Borcu',
          amount: 85.0,
          type: ExpenseType.personalDebt,
          paidByMemberId: 'ahmet-id', // Ahmet ödedi
          debtorMemberId: 'mehmet-id', // Mehmet borçlandı
        ),
        Expense(
          id: '6',
          householdId: 'house-1',
          title: 'Şahsi Yemek Siparişi Borcu',
          amount: 80.0,
          type: ExpenseType.personalDebt,
          paidByMemberId: 'ahmet-id',
          debtorMemberId: 'mehmet-id',
        ),

        // 3. Dönem Ortak Harcamalar
        Expense(
          id: '7',
          householdId: 'house-1',
          title: 'Temizlik ve Ortak İhtiyaçlar',
          amount: 1396.0,
          type: ExpenseType.joint,
          paidByMemberId: 'mehmet-id',
        ),
        Expense(
          id: '8',
          householdId: 'house-1',
          title: 'Haftalık Manav Alışverişi',
          amount: 918.50,
          type: ExpenseType.joint,
          paidByMemberId: 'ahmet-id',
        ),

        // Ek Şahsi Borç
        Expense(
          id: '9',
          householdId: 'house-1',
          title: 'Şahsi Taksi Masrafı',
          amount: 50.0,
          type: ExpenseType.personalDebt,
          paidByMemberId: 'ahmet-id',
          debtorMemberId: 'mehmet-id',
        ),
      ];

      final result = DebtEngine.calculate(
        members: [ahmet, mehmet],
        expenses: expenses,
      );

      // Toplam ortak harcama = 2726 + 5789 + 1240 + 200 + 1396 + 918.50 = 12269.50
      expect(result.totalJointExpenses, 12269.50);
      // Kişi başı = 12269.50 / 2 = 6134.75
      expect(result.perPersonJointShare, 6134.75);

      // Şahsi borçlar: Mehmet Ahmet'e 85 + 80 + 50 = 215 TL borçlu
      expect(result.directPersonalDebts.length, 3);

      // Ortak harcama farkı: Ahmet 4884.50 ödedi, payı 6134.75 -> 1250.25 TL ortak borcu var
      // Şahsi alacağı: 215 TL
      // Net bakiye: -1250.25 + 215 = -1035.25 TL (Ahmet Mehmet'e 1035.25 TL borçlu)
      expect(result.netBalanceByMember['ahmet-id'], closeTo(-1035.25, 0.01));
      expect(result.netBalanceByMember['mehmet-id'], closeTo(1035.25, 0.01));

      // Tek bir transfer önerilmeli: Ahmet ➔ Mehmet 1035.25 TL
      expect(result.settlements.length, 1);
      final settlement = result.settlements.first;
      expect(settlement.fromMemberId, 'ahmet-id');
      expect(settlement.toMemberId, 'mehmet-id');
      expect(settlement.amount, closeTo(1035.25, 0.01));
    });

    test('3 Kişilik Ortaklıkta Minimum Transfer Algoritması Testi', () {
      final ali = HouseholdMember(id: 'ali', householdId: 'h1', displayName: 'Ali');
      final veli = HouseholdMember(id: 'veli', householdId: 'h1', displayName: 'Veli');
      final can = HouseholdMember(id: 'can', householdId: 'h1', displayName: 'Can');

      // Ali 300 TL ortak harcama yaptı, Veli ve Can 0 TL yaptı
      final expenses = [
        Expense(
          id: '1',
          householdId: 'h1',
          title: 'Pazar',
          amount: 300.0,
          type: ExpenseType.joint,
          paidByMemberId: 'ali',
        ),
      ];

      final result = DebtEngine.calculate(
        members: [ali, veli, can],
        expenses: expenses,
      );

      // Kişi başı 100 TL. Ali +200 alacaklı, Veli -100, Can -100.
      expect(result.perPersonJointShare, 100.0);
      expect(result.settlements.length, 2);
      expect(result.settlements.any((s) => s.fromMemberId == 'veli' && s.toMemberId == 'ali' && s.amount == 100.0), true);
      expect(result.settlements.any((s) => s.fromMemberId == 'can' && s.toMemberId == 'ali' && s.amount == 100.0), true);
    });
  });
}
