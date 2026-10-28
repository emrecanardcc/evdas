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
  final int totalTransfersBeforeOptimization;
  final int totalTransfersOptimized;
  final int transfersSaved;
  final double totalSettlementVolume;

  DebtEngineResult({
    required this.totalJointExpenses,
    required this.perPersonJointShare,
    required this.jointSpentByMember,
    required this.netBalanceByMember,
    required this.settlements,
    required this.directPersonalDebts,
    this.pendingPayments = const [],
    this.confirmedPayments = const [],
    int? totalTransfersBeforeOptimization,
    int? totalTransfersOptimized,
    int? transfersSaved,
    double? totalSettlementVolume,
  })  : totalTransfersOptimized = totalTransfersOptimized ?? settlements.length,
        totalTransfersBeforeOptimization = totalTransfersBeforeOptimization ??
            (settlements.isEmpty ? 0 : settlements.length * 2),
        transfersSaved = transfersSaved ??
            ((totalTransfersBeforeOptimization ??
                        (settlements.isEmpty ? 0 : settlements.length * 2)) -
                    settlements.length)
                .clamp(0, 999),
        totalSettlementVolume = totalSettlementVolume ??
            settlements.fold<double>(0.0, (sum, s) => sum + s.amount);
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
        totalTransfersBeforeOptimization: 0,
        totalTransfersOptimized: 0,
        transfersSaved: 0,
        totalSettlementVolume: 0,
      );
    }

    final memberMap = {for (final m in members) m.id: m};
    final jointSpent = <String, double>{for (final m in members) m.id: 0.0};
    final jointOwed = <String, double>{for (final m in members) m.id: 0.0};
    final netBalance = <String, double>{for (final m in members) m.id: 0.0};
    final directPersonalDebts = <Expense>[];

    double totalJoint = 0.0;
    double totalUnweightedJoint = 0.0;

    // 1. Masrafları ve Şahsi Borçları İşle
    for (final exp in expenses) {
      if (exp.type == ExpenseType.joint) {
        totalJoint += exp.amount;
        jointSpent[exp.paidByMemberId] =
            (jointSpent[exp.paidByMemberId] ?? 0.0) + exp.amount;

        // Eşit olmayan / ağırlıklı bölüşüm veya muafiyet kontrolü
        final weights = exp.splitMemberWeights;
        if (weights != null && weights.isNotEmpty) {
          double totalWeight = 0.0;
          weights.forEach((memberId, w) {
            if (w > 0 && jointOwed.containsKey(memberId)) {
              totalWeight += w;
            }
          });

          if (totalWeight > 0) {
            weights.forEach((memberId, weight) {
              if (weight > 0 && jointOwed.containsKey(memberId)) {
                final share = exp.amount * (weight / totalWeight);
                jointOwed[memberId] = (jointOwed[memberId] ?? 0.0) + share;
              }
            });
          } else {
            totalUnweightedJoint += exp.amount;
          }
        } else {
          totalUnweightedJoint += exp.amount;
        }
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
    final unweightedPerPersonShare =
        members.isNotEmpty ? (totalUnweightedJoint / members.length) : 0.0;

    // Ortak harcama dengesini net bakiyeye ekle (Tek geçişte O(M))
    for (final member in members) {
      final spent = jointSpent[member.id] ?? 0.0;
      final owed = (jointOwed[member.id] ?? 0.0) + unweightedPerPersonShare;
      final jointDiff = spent - owed;
      netBalance[member.id] = (netBalance[member.id] ?? 0.0) + jointDiff;
    }

    // 2. Çift Taraflı Onaylı Ödemeleri (Partial / Full Payments) İşle
    final pending = <PaymentRequest>[];
    final confirmed = <PaymentRequest>[];

    for (final pay in paymentRequests) {
      if (pay.status == PaymentStatus.confirmed) {
        confirmed.add(pay);
        netBalance[pay.fromMemberId] =
            (netBalance[pay.fromMemberId] ?? 0.0) + pay.amount;
        netBalance[pay.toMemberId] =
            (netBalance[pay.toMemberId] ?? 0.0) - pay.amount;
      } else if (pay.status == PaymentStatus.pending) {
        pending.add(pay);
      }
    }

    // 3. Minimum Transfer Graf Optimizasyonu (Minimum Cash Flow Engine)
    final settlements = _simplifyDebts(netBalance, memberMap);

    final debtorsCount = netBalance.values.where((b) => b <= -0.01).length;
    final creditorsCount = netBalance.values.where((b) => b >= 0.01).length;
    final naivePairs = debtorsCount * creditorsCount;
    final beforeCount =
        naivePairs > settlements.length ? naivePairs : settlements.length;
    final saved = beforeCount - settlements.length;

    return DebtEngineResult(
      totalJointExpenses: totalJoint,
      perPersonJointShare: perPersonShare,
      jointSpentByMember: jointSpent,
      netBalanceByMember: netBalance,
      settlements: settlements,
      directPersonalDebts: directPersonalDebts,
      pendingPayments: pending,
      confirmedPayments: confirmed,
      totalTransfersBeforeOptimization: beforeCount,
      totalTransfersOptimized: settlements.length,
      transfersSaved: saved > 0 ? saved : 0,
      totalSettlementVolume:
          settlements.fold<double>(0.0, (sum, s) => sum + s.amount),
    );
  }

  /// Minimum Transfer Algoritması (Bipartite Graph & Greedy Cash Flow Reduction)
  static List<SettlementItem> _simplifyDebts(
    Map<String, double> netBalances,
    Map<String, HouseholdMember> members,
  ) {
    final creditors = <_MemberBalance>[];
    final debtors = <_MemberBalance>[];

    netBalances.forEach((id, balance) {
      final rounded = (balance * 100).round() / 100.0;
      if (rounded >= 0.01) {
        creditors.add(_MemberBalance(id, rounded));
      } else if (rounded <= -0.01) {
        debtors.add(_MemberBalance(id, -rounded));
      }
    });

    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    final result = <SettlementItem>[];

    // Faz 1: Tam Eşleşmeler (Birebir kuruşu kuruşuna denkleşmeler)
    // Eğer bir borçlu ile alacaklı eşit miktara sahipse, aralarında tek transferle ikisini de sıfırla
    for (int d = debtors.length - 1; d >= 0; d--) {
      final debtor = debtors[d];
      final cIdx = creditors
          .indexWhere((c) => (c.amount - debtor.amount).abs() < 0.009);
      if (cIdx != -1) {
        final creditor = creditors[cIdx];
        final fromName = members[debtor.id]?.displayName ?? 'Ortak';
        final toName = members[creditor.id]?.displayName ?? 'Ortak';

        result.add(
          SettlementItem(
            fromMemberId: debtor.id,
            fromMemberName: fromName,
            toMemberId: creditor.id,
            toMemberName: toName,
            amount: debtor.amount,
          ),
        );

        debtors.removeAt(d);
        creditors.removeAt(cIdx);
      }
    }

    // Faz 2: Kalan bakiyeler için açgözlü (Greedy) en büyük borçlu / alacaklı eşleştirmesi
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    int cIdx = 0;
    int dIdx = 0;

    while (cIdx < creditors.length && dIdx < debtors.length) {
      final creditor = creditors[cIdx];
      final debtor = debtors[dIdx];

      final transferAmount = creditor.amount < debtor.amount
          ? creditor.amount
          : debtor.amount;

      if (transferAmount >= 0.01) {
        final fromName = members[debtor.id]?.displayName ?? 'Ortak';
        final toName = members[creditor.id]?.displayName ?? 'Ortak';

        result.add(
          SettlementItem(
            fromMemberId: debtor.id,
            fromMemberName: fromName,
            toMemberId: creditor.id,
            toMemberName: toName,
            amount: (transferAmount * 100).round() / 100.0,
          ),
        );
      }

      creditor.amount =
          ((creditor.amount - transferAmount) * 100).round() / 100.0;
      debtor.amount =
          ((debtor.amount - transferAmount) * 100).round() / 100.0;

      if (creditor.amount < 0.01) cIdx++;
      if (debtor.amount < 0.01) dIdx++;
    }

    return result;
  }
}

class _MemberBalance {
  final String id;
  double amount;
  _MemberBalance(this.id, this.amount);
}
