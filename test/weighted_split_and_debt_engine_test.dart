import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/domain/debt_engine.dart';

void main() {
  group('DebtEngine Eşit Olmayan & Ağırlıklı Bölüşüm Testleri', () {
    final ali = HouseholdMember(id: 'ali', householdId: 'h1', displayName: 'Ali');
    final veli = HouseholdMember(id: 'veli', householdId: 'h1', displayName: 'Veli');
    final can = HouseholdMember(id: 'can', householdId: 'h1', displayName: 'Can');
    final members = [ali, veli, can];

    test('Ağırlıklı pay (3:2:1) ile ortak harcama doğru dağıtılmalıdır', () {
      final expense = Expense(
        id: 'exp-1',
        householdId: 'h1',
        title: 'Büyük Alışveriş',
        amount: 600.0,
        type: ExpenseType.joint,
        paidByMemberId: 'ali',
        splitMemberWeights: {
          'ali': 3.0,
          'veli': 2.0,
          'can': 1.0,
        },
      );

      final result = DebtEngine.calculate(
        members: members,
        expenses: [expense],
      );

      // Ali: 600 ödedi - 300 payı = +300 alacaklı
      // Veli: 0 ödedi - 200 payı = -200 borçlu
      // Can: 0 ödedi - 100 payı = -100 borçlu
      expect(result.netBalanceByMember['ali'], closeTo(300.0, 0.01));
      expect(result.netBalanceByMember['veli'], closeTo(-200.0, 0.01));
      expect(result.netBalanceByMember['can'], closeTo(-100.0, 0.01));

      // Transferler
      expect(result.settlements.length, 2);
      expect(
        result.settlements.any(
            (s) => s.fromMemberId == 'veli' && s.toMemberId == 'ali' && s.amount == 200.0),
        isTrue,
      );
      expect(
        result.settlements.any(
            (s) => s.fromMemberId == 'can' && s.toMemberId == 'ali' && s.amount == 100.0),
        isTrue,
      );
    });

    test('Belirli üyeyi harcamadan muaf tutma (ağırlık 0.0) testi', () {
      final expense = Expense(
        id: 'exp-2',
        householdId: 'h1',
        title: 'Özel Parti Harcaması (Can Katılmadı)',
        amount: 300.0,
        type: ExpenseType.joint,
        paidByMemberId: 'ali',
        splitMemberWeights: {
          'ali': 1.0,
          'veli': 1.0,
          'can': 0.0, // Can muaf
        },
      );

      final result = DebtEngine.calculate(
        members: members,
        expenses: [expense],
      );

      // Ali: 300 ödedi - 150 payı = +150 alacaklı
      // Veli: 0 ödedi - 150 payı = -150 borçlu
      // Can: 0 pay = 0.0
      expect(result.netBalanceByMember['ali'], closeTo(150.0, 0.01));
      expect(result.netBalanceByMember['veli'], closeTo(-150.0, 0.01));
      expect(result.netBalanceByMember['can'], closeTo(0.0, 0.01));

      expect(result.settlements.length, 1);
      final settlement = result.settlements.first;
      expect(settlement.fromMemberId, 'veli');
      expect(settlement.toMemberId, 'ali');
      expect(settlement.amount, 150.0);
    });

    test('Geriye dönük uyumluluk: splitMemberWeights null ise eşit bölünmelidir', () {
      final expense = Expense(
        id: 'exp-3',
        householdId: 'h1',
        title: 'Standart Harcama',
        amount: 300.0,
        type: ExpenseType.joint,
        paidByMemberId: 'ali',
        splitMemberWeights: null,
      );

      final result = DebtEngine.calculate(
        members: members,
        expenses: [expense],
      );

      expect(result.perPersonJointShare, 100.0);
      expect(result.netBalanceByMember['ali'], closeTo(200.0, 0.01));
      expect(result.netBalanceByMember['veli'], closeTo(-100.0, 0.01));
      expect(result.netBalanceByMember['can'], closeTo(-100.0, 0.01));
    });

    test('Ortaklıktan ayrılmış/olmayan üye ID\'si splitMemberWeights içinde yer alsa dahi aktif üyelerin payları bozulmamalıdır', () {
      final expense = Expense(
        id: 'exp-4',
        householdId: 'h1',
        title: 'Eski Üyeli Harcama',
        amount: 200.0,
        type: ExpenseType.joint,
        paidByMemberId: 'ali',
        splitMemberWeights: {
          'ali': 1.0,
          'veli': 1.0,
          'eski_uye_ayrilmis': 1.0, // Ortaklıkta artık yok
        },
      );

      // Sadece Ali ve Veli evde var
      final result = DebtEngine.calculate(
        members: [ali, veli],
        expenses: [expense],
      );

      // Toplam ağırlık sadece Ali ve Veli için hesaplanmalı (1 + 1 = 2)
      // Ali: 200 ödedi - 100 payı = +100
      // Veli: 0 ödedi - 100 payı = -100
      expect(result.netBalanceByMember['ali'], closeTo(100.0, 0.01));
      expect(result.netBalanceByMember['veli'], closeTo(-100.0, 0.01));
    });
  });
}
