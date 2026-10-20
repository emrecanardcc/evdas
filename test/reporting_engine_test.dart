import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/domain/reporting_engine.dart';

void main() {
  group('ReportingEngine Kategori Raporlama Testleri', () {
    final ahmet = HouseholdMember(id: '1', householdId: 'h', displayName: 'Ahmet');
    final mehmet = HouseholdMember(id: '2', householdId: 'h', displayName: 'Mehmet');

    final now = DateTime.now();
    final expenses = [
      Expense(
        id: '1',
        householdId: 'h',
        title: 'Büyük Market',
        amount: 600.0,
        type: ExpenseType.joint,
        category: ExpenseCategory.market,
        paidByMemberId: '1',
        expenseDate: now,
      ),
      Expense(
        id: '2',
        householdId: 'h',
        title: 'Elektrik Faturası',
        amount: 400.0,
        type: ExpenseType.joint,
        category: ExpenseCategory.fatura,
        paidByMemberId: '2',
        expenseDate: now,
      ),
    ];

    test('Kategori yüzdeleri ve kişi başı ortalama doğru hesaplanmalıdır', () {
      final report = ReportingEngine.generate(
        members: [ahmet, mehmet],
        expenses: expenses,
        timeRange: ReportTimeRange.thisMonth,
      );

      expect(report.grandTotal, 1000.0);
      expect(report.totalJointExpenses, 1000.0);
      expect(report.perMemberAverage, 500.0);

      // Kategori dağılımı: Market %60, Fatura %40
      expect(report.categorySpends.length, 2);
      expect(report.categorySpends.first.category, ExpenseCategory.market);
      expect(report.categorySpends.first.amount, 600.0);
      expect(report.categorySpends.first.percentage, 60.0);

      expect(report.categorySpends[1].category, ExpenseCategory.fatura);
      expect(report.categorySpends[1].amount, 400.0);
      expect(report.categorySpends[1].percentage, 40.0);

      // Formatlı metin çıktısı test edilir
      final text = report.toSummaryString('Bizim Ortaklık');
      expect(text.contains('Bizim Ortaklık - Net Gider Raporu'), true);
      expect(text.contains('Market'), true);
      expect(text.contains('60.0'), true);
    });
  });
}
