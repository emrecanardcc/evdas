import '../core/utils/currency_formatter.dart';
import '../data/models/expense.dart';
import '../data/models/household_member.dart';

enum ReportTimeRange {
  thisMonth,
  lastMonth,
  allTime,
}

extension ReportTimeRangeExt on ReportTimeRange {
  String get displayName {
    switch (this) {
      case ReportTimeRange.thisMonth:
        return 'Bu Ay';
      case ReportTimeRange.lastMonth:
        return 'Geçen Ay';
      case ReportTimeRange.allTime:
        return 'Tüm Zamanlar';
    }
  }
}

class CategorySpend {
  final ExpenseCategory category;
  final double amount;
  final double percentage; // 0.0 - 100.0
  final int count;

  CategorySpend({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

class MemberSpend {
  final HouseholdMember member;
  final double amount;
  final double percentage;

  MemberSpend({
    required this.member,
    required this.amount,
    required this.percentage,
  });
}

class PersonalDebtBreakdown {
  final String creditorId;
  final String creditorName;
  final String debtorId;
  final String debtorName;
  final double amount;
  final int count;

  PersonalDebtBreakdown({
    required this.creditorId,
    required this.creditorName,
    required this.debtorId,
    required this.debtorName,
    required this.amount,
    required this.count,
  });
}

class PartnershipReport {
  final ReportTimeRange timeRange;
  final double totalJointExpenses;
  final double totalPersonalDebts;
  final double grandTotal;
  final double perMemberAverage;
  final List<CategorySpend> categorySpends;
  final List<MemberSpend> memberSpends;
  final List<PersonalDebtBreakdown> personalDebtsBreakdown;
  final int totalTransactionCount;

  PartnershipReport({
    required this.timeRange,
    required this.totalJointExpenses,
    required this.totalPersonalDebts,
    required this.grandTotal,
    required this.perMemberAverage,
    required this.categorySpends,
    required this.memberSpends,
    this.personalDebtsBreakdown = const [],
    required this.totalTransactionCount,
  });

  /// Paylaşılmak üzere formatlı özet metin üretir
  String toSummaryString(String partnershipName) {
    final buffer = StringBuffer();
    buffer.writeln('*$partnershipName - Net Gider Raporu*');
    buffer.writeln('Dönem: ${timeRange.displayName}');
    buffer.writeln('------------------------------------');
    buffer.writeln('*Toplam Harcama:* ${CurrencyFormatter.formatClean(grandTotal)}');
    buffer.writeln('*Ortak Masraflar:* ${CurrencyFormatter.formatClean(totalJointExpenses)}');
    if (totalPersonalDebts > 0) {
      buffer.writeln('*Şahsi Borçlar:* ${CurrencyFormatter.formatClean(totalPersonalDebts)}');
    }
    buffer.writeln('*Kişi Başı Düşen:* ${CurrencyFormatter.formatClean(perMemberAverage)}');
    buffer.writeln('------------------------------------');
    buffer.writeln('*Kategori Dağılımı:*');

    for (final cat in categorySpends) {
      buffer.writeln('• ${cat.category.displayName}: ${CurrencyFormatter.formatClean(cat.amount)} (%${cat.percentage.toStringAsFixed(1)})');
    }

    buffer.writeln('------------------------------------');
    buffer.writeln('*Harcama Yapanlar:*');
    for (final mem in memberSpends) {
      buffer.writeln('• ${mem.member.displayName}: ${CurrencyFormatter.formatClean(mem.amount)} (%${mem.percentage.toStringAsFixed(1)})');
    }

    if (personalDebtsBreakdown.isNotEmpty) {
      buffer.writeln('------------------------------------');
      buffer.writeln('*Şahsi Borçlar (Kimin Kime Ne Kadar Borcu Var):*');
      for (final debt in personalDebtsBreakdown) {
        buffer.writeln('• ${debt.debtorName} ➔ ${debt.creditorName}: ${CurrencyFormatter.formatClean(debt.amount)}');
      }
    }

    buffer.writeln('------------------------------------');
    buffer.writeln('Evdaş ile oluşturuldu');
    return buffer.toString();
  }
}

class ReportingEngine {
  static PartnershipReport generate({
    required List<HouseholdMember> members,
    required List<Expense> expenses,
    ReportTimeRange timeRange = ReportTimeRange.thisMonth,
  }) {
    final now = DateTime.now();
    final nowYear = now.year;
    final nowMonth = now.month;
    final lastMonthYear = nowMonth == 1 ? nowYear - 1 : nowYear;
    final lastMonth = nowMonth == 1 ? 12 : nowMonth - 1;

    // TEK GECISTE (O(N)) FILTRELEME VE TOPLAMA (Sıfır Ara Liste & Sıfır Gereksiz DateTime Tahsisi)
    double totalJoint = 0;
    double totalPersonal = 0;
    final catAmounts = <ExpenseCategory, double>{};
    final catCounts = <ExpenseCategory, int>{};
    final memberAmounts = <String, double>{for (final m in members) m.id: 0.0};
    final pairwiseDebts = <(String, String), double>{};
    final pairwiseCounts = <(String, String), int>{};
    int filteredTransactionCount = 0;

    for (final exp in expenses) {
      if (timeRange == ReportTimeRange.thisMonth) {
        if (exp.expenseDate.year != nowYear || exp.expenseDate.month != nowMonth) {
          continue;
        }
      } else if (timeRange == ReportTimeRange.lastMonth) {
        if (exp.expenseDate.year != lastMonthYear || exp.expenseDate.month != lastMonth) {
          continue;
        }
      }

      filteredTransactionCount++;

      if (exp.type == ExpenseType.joint) {
        totalJoint += exp.amount;
        catAmounts[exp.category] = (catAmounts[exp.category] ?? 0.0) + exp.amount;
        catCounts[exp.category] = (catCounts[exp.category] ?? 0) + 1;
        memberAmounts[exp.paidByMemberId] =
            (memberAmounts[exp.paidByMemberId] ?? 0.0) + exp.amount;
      } else if (exp.type == ExpenseType.personalDebt) {
        totalPersonal += exp.amount;
        if (exp.debtorMemberId != null) {
          final pair = (exp.paidByMemberId, exp.debtorMemberId!);
          pairwiseDebts[pair] = (pairwiseDebts[pair] ?? 0.0) + exp.amount;
          pairwiseCounts[pair] = (pairwiseCounts[pair] ?? 0) + 1;
        }
      }
    }

    final grandTotal = totalJoint + totalPersonal;
    final perMember = members.isNotEmpty ? (totalJoint / members.length) : 0.0;

    // Kategori Harcamaları Listesi
    final categorySpends = <CategorySpend>[];
    catAmounts.forEach((cat, amount) {
      final percentage = totalJoint > 0 ? (amount / totalJoint) * 100 : 0.0;
      categorySpends.add(
        CategorySpend(
          category: cat,
          amount: amount,
          percentage: percentage,
          count: catCounts[cat] ?? 0,
        ),
      );
    });
    categorySpends.sort((a, b) => b.amount.compareTo(a.amount));

    // Üye Harcamaları Listesi
    final memberSpends = <MemberSpend>[];
    for (final member in members) {
      final amount = memberAmounts[member.id] ?? 0.0;
      final percentage = totalJoint > 0 ? (amount / totalJoint) * 100 : 0.0;
      memberSpends.add(
        MemberSpend(
          member: member,
          amount: amount,
          percentage: percentage,
        ),
      );
    }
    memberSpends.sort((a, b) => b.amount.compareTo(a.amount));

    // Şahsi Borçlar Kırılımı (Kimin kime ne kadar borcu var - Sıfır String Bölme Hatası)
    final memberMap = {for (final m in members) m.id: m};
    final personalDebtsBreakdown = <PersonalDebtBreakdown>[];
    pairwiseDebts.forEach((pair, amount) {
      final (creditorId, debtorId) = pair;
      final creditorName = memberMap[creditorId]?.displayName ?? 'Alacaklı';
      final debtorName = memberMap[debtorId]?.displayName ?? 'Borçlu';

      personalDebtsBreakdown.add(
        PersonalDebtBreakdown(
          creditorId: creditorId,
          creditorName: creditorName,
          debtorId: debtorId,
          debtorName: debtorName,
          amount: amount,
          count: pairwiseCounts[pair] ?? 1,
        ),
      );
    });
    personalDebtsBreakdown.sort((a, b) => b.amount.compareTo(a.amount));

    return PartnershipReport(
      timeRange: timeRange,
      totalJointExpenses: totalJoint,
      totalPersonalDebts: totalPersonal,
      grandTotal: grandTotal,
      perMemberAverage: perMember,
      categorySpends: categorySpends,
      memberSpends: memberSpends,
      personalDebtsBreakdown: personalDebtsBreakdown,
      totalTransactionCount: filteredTransactionCount,
    );
  }
}
