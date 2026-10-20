import '../data/models/expense.dart';
import '../data/models/household_member.dart';
import '../data/models/payment_request.dart';
import '../data/models/settlement_item.dart';

class DebtEngineResult {
  final double totalJointExpenses;
  final double perPersonJointShare;
  final Map<String, double> jointSpentByMember;
  final Map<String, double> netBalanceByMember; // Pozitif: Alacaklı, Negatif: Borçlu
  final List<SettlementItem> settlements; // Kim kime ne ödemeli (Minimum transfer algoritması)
  final List<Expense> directPersonalDebts; // Şahsi borçların listesi
  final List<PaymentRequest> pendingPayments; // Karşılıklı onay bekleyen ödemeler
  final List<PaymentRequest> confirmedPayments; // Onaylanmış kısmi/tam ödemeler

  DebtEngineResult({
    required this.totalJointExpenses,
    required this.perPersonJointShare,
    required this.jointSpentByMember,
    required this.netBalanceByMember,
    required this.settlements,
    required this.directPersonalDebts,
    this.pendingPayments = const [],
    this.confirmedPayments = const [],
  });
}

class DebtEngine {
  /// Evdeki tüm harcamaları, üyeleri ve çift taraflı onaylı ödemeleri alarak net bakiyeleri hesaplar
  static DebtEngineResult calculate({
    required List<HouseholdMember> members,
    required List<Expense> expenses,
    List<PaymentRequest> paymentRequests = const [],
  }) {
    if (members.isEmpty) {
      return DebtEngineResult(
        totalJointExpenses: 0,
        perPersonJointShare: 0,
        jointSpentByMember: {},
        netBalanceByMember: {},
        settlements: [],
        directPersonalDebts: [],
        pendingPayments: [],
        confirmedPayments: [],
      );
    }

    final memberMap = {for (final m in members) m.id: m};
    final jointSpent = <String, double>{for (final m in members) m.id: 0.0};
    final netBalance = <String, double>{for (final m in members) m.id: 0.0};
    final directPersonalDebts = <Expense>[];

    double totalJoint = 0.0;

    // 1. Masrafları ve Şahsi Borçları İşle
    for (final exp in expenses) {
      if (exp.type == ExpenseType.joint) {
        totalJoint += exp.amount;
        jointSpent[exp.paidByMemberId] =
            (jointSpent[exp.paidByMemberId] ?? 0.0) + exp.amount;
      } else if (exp.type == ExpenseType.personalDebt) {
        directPersonalDebts.add(exp);
        // Şahsi borç: paidByMemberId alacaklı (+), debtorMemberId borçlu (-)
        if (exp.debtorMemberId != null &&
            exp.debtorMemberId != exp.paidByMemberId) {
          netBalance[exp.paidByMemberId] =
              (netBalance[exp.paidByMemberId] ?? 0.0) + exp.amount;
          netBalance[exp.debtorMemberId!] =
              (netBalance[exp.debtorMemberId!] ?? 0.0) - exp.amount;
        }
      } else if (exp.type == ExpenseType.settlement) {
        // Eski manuel ödeşme kaydı
        if (exp.debtorMemberId != null) {
          netBalance[exp.paidByMemberId] =
              (netBalance[exp.paidByMemberId] ?? 0.0) + exp.amount;
          netBalance[exp.debtorMemberId!] =
              (netBalance[exp.debtorMemberId!] ?? 0.0) - exp.amount;
        }
      }
    }

    final perPersonShare =
        members.isNotEmpty ? (totalJoint / members.length) : 0.0;

    // Ortak harcama dengesini net bakiyeye ekle
    for (final member in members) {
      final spent = jointSpent[member.id] ?? 0.0;
      final jointDiff = spent - perPersonShare;
      netBalance[member.id] = (netBalance[member.id] ?? 0.0) + jointDiff;
    }

    // 2. Çift Taraflı Onaylı Ödemeleri (Partial / Full Payments) İşle
    // YALNIZCA her iki tarafın kabul ettiği (confirmed) ödemeler borçtan düşülür!
    final pending = <PaymentRequest>[];
    final confirmed = <PaymentRequest>[];

    for (final pay in paymentRequests) {
      if (pay.status == PaymentStatus.confirmed) {
        confirmed.add(pay);
        // fromMemberId (Borçlu) ödedi -> Borcu azaldı (+)
        // toMemberId (Alacaklı) aldı -> Alacağı tahsil edildi (-)
        netBalance[pay.fromMemberId] =
            (netBalance[pay.fromMemberId] ?? 0.0) + pay.amount;
        netBalance[pay.toMemberId] =
            (netBalance[pay.toMemberId] ?? 0.0) - pay.amount;
      } else if (pay.status == PaymentStatus.pending) {
        pending.add(pay);
        // Onay bekleyen ödemeler HENÜZ bakiyeden düşülmez (güvenliği korumak için)
      }
    }

    // 3. Minimum Transfer Algoritması (Debt Simplification)
    final settlements = _simplifyDebts(netBalance, memberMap);

    return DebtEngineResult(
      totalJointExpenses: totalJoint,
      perPersonJointShare: perPersonShare,
      jointSpentByMember: jointSpent,
      netBalanceByMember: netBalance,
      settlements: settlements,
      directPersonalDebts: directPersonalDebts,
      pendingPayments: pending,
      confirmedPayments: confirmed,
    );
  }

  /// Borç sadeleştirme algoritması: En çok borçlu olan ile en çok alacaklı olanı eşleştirir
  static List<SettlementItem> _simplifyDebts(
    Map<String, double> netBalances,
    Map<String, HouseholdMember> members,
  ) {
    final creditors = <_MemberBalance>[];
    final debtors = <_MemberBalance>[];

    netBalances.forEach((id, balance) {
      final rounded = double.parse(balance.toStringAsFixed(2));
      if (rounded > 0.01) {
        creditors.add(_MemberBalance(id, rounded));
      } else if (rounded < -0.01) {
        debtors.add(_MemberBalance(id, -rounded));
      }
    });

    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final result = <SettlementItem>[];
    int cIdx = 0;
    int dIdx = 0;

    while (cIdx < creditors.length && dIdx < debtors.length) {
      final creditor = creditors[cIdx];
      final debtor = debtors[dIdx];

      final transferAmount = creditor.amount < debtor.amount
          ? creditor.amount
          : debtor.amount;

      if (transferAmount > 0.01) {
        final fromName = members[debtor.id]?.displayName ?? 'Ortak';
        final toName = members[creditor.id]?.displayName ?? 'Ortak';

        result.add(
          SettlementItem(
            fromMemberId: debtor.id,
            fromMemberName: fromName,
            toMemberId: creditor.id,
            toMemberName: toName,
            amount: double.parse(transferAmount.toStringAsFixed(2)),
          ),
        );
      }

      creditor.amount -= transferAmount;
      debtor.amount -= transferAmount;

      if (creditor.amount <= 0.01) cIdx++;
      if (debtor.amount <= 0.01) dIdx++;
    }

    return result;
  }
}

class _MemberBalance {
  final String id;
  double amount;
  _MemberBalance(this.id, this.amount);
}
