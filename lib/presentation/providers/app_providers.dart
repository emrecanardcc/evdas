import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/approval_request.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_member.dart';
import '../../data/models/partnership.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/settlement_item.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/debt_engine.dart';
import '../../domain/reporting_engine.dart';

// REPOSITORY PROVIDER
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  throw UnimplementedError('ExpenseRepository must be initialized in main');
});

// ALL PARTNERSHIPS PROVIDER
final allPartnershipsProvider = Provider<List<Partnership>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  ref.watch(householdProvider);
  return repo.getAllPartnerships();
});

// ACTIVE PARTNERSHIP NOTIFIER
class HouseholdNotifier extends Notifier<Partnership?> {
  @override
  Partnership? build() {
    final repo = ref.watch(expenseRepositoryProvider);
    return repo.getActiveHousehold();
  }

  void refresh() {
    final repo = ref.read(expenseRepositoryProvider);
    state = repo.getActiveHousehold();
  }

  Future<void> switchPartnership(Partnership p) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.setActivePartnership(p);

    // Ortaklık değiştirildiğinde kullanıcının bu ortaklıktaki profilini otomatik belirle
    final authUserId = SupabaseService.currentUser?.id;
    if (authUserId != null) {
      final myMember = p.members
          .where((m) => m.userId != null && m.userId == authUserId)
          .firstOrNull;
      if (myMember != null) {
        await repo.setCurrentUserId(myMember.id);
      }
    }

    state = p;
    ref.read(expensesProvider.notifier).refresh();
    ref.read(paymentRequestsProvider.notifier).refresh();
  }

  Future<void> updateMemberProfile({
    required String memberId,
    required String displayName,
    String? iban,
  }) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.updateMemberProfile(
      memberId: memberId,
      displayName: displayName,
      iban: iban,
    );
    state = repo.getActiveHousehold();
  }

  Future<void> addMember(String displayName, {String? iban}) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.addMemberToHousehold(displayName, iban: iban);
    state = repo.getActiveHousehold();
  }

  Future<Partnership> createNew({
    required String name,
    required PartnershipType type,
    required String creatorName,
    String? iban,
  }) async {
    final repo = ref.read(expenseRepositoryProvider);
    final p = await repo.createPartnership(
      name: name,
      type: type,
      creatorName: creatorName,
      creatorIban: iban,
    );
    state = p;
    ref.read(expensesProvider.notifier).refresh();
    ref.read(paymentRequestsProvider.notifier).refresh();
    return p;
  }

  Future<Partnership> joinByCode({
    required String code,
    required String userName,
    String? iban,
  }) async {
    final repo = ref.read(expenseRepositoryProvider);
    final p = await repo.joinPartnershipByCode(
      inviteCode: code,
      userName: userName,
      userIban: iban,
    );
    state = p;
    ref.read(expensesProvider.notifier).refresh();
    ref.read(paymentRequestsProvider.notifier).refresh();
    return p;
  }

  Future<void> updateHousehold(Partnership partnership) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.saveHousehold(partnership);
    state = repo.getActiveHousehold();
  }

  Future<Partnership> updateDetails({
    String? name,
    int? settlementDay,
    int? customColor,
    String? customIcon,
  }) async {
    final current = state;
    if (current == null) throw Exception('Aktif ortaklık yok');
    final repo = ref.read(expenseRepositoryProvider);
    final updated = await repo.updatePartnershipDetails(
      current.id,
      name: name,
      settlementDay: settlementDay,
      customColor: customColor,
      customIcon: customIcon,
    );
    state = updated;
    return updated;
  }

  Future<void> removeMember(String memberId) async {
    final current = state;
    if (current == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    await repo.removeMemberFromPartnership(current.id, memberId);
    state = repo.getActiveHousehold();
  }

  Future<void> deleteCurrentPartnership() async {
    final current = state;
    if (current == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    await repo.deletePartnership(current.id);
    state = repo.getActiveHousehold();
    ref.read(expensesProvider.notifier).refresh();
    ref.read(paymentRequestsProvider.notifier).refresh();
  }
}

final householdProvider =
    NotifierProvider<HouseholdNotifier, Partnership?>(HouseholdNotifier.new);

// CURRENT MEMBER NOTIFIER (Her cihazda yalnızca oturum açmış kullanıcıya bağlanır)
class CurrentMemberNotifier extends Notifier<HouseholdMember?> {
  @override
  HouseholdMember? build() {
    final house = ref.watch(householdProvider);
    final repo = ref.watch(expenseRepositoryProvider);
    final userId = repo.getCurrentUserId();
    final authUserId = SupabaseService.currentUser?.id;

    if (house != null && house.members.isNotEmpty) {
      // 1. Cihazdaki aktif Supabase kullanıcısı ile eşleşen üyeyi bul
      if (authUserId != null) {
        final authMatch = house.members
            .where((m) => m.userId != null && m.userId == authUserId)
            .firstOrNull;
        if (authMatch != null) return authMatch;
      }

      // 2. Yerel depolamadaki üye ID'si ile eşleşeni bul
      if (userId != null) {
        final idMatch =
            house.members.where((m) => m.id == userId).firstOrNull;
        if (idMatch != null) return idMatch;
      }

      // 3. Ortaklığın ilk üyesine güvenli geri dönüş
      return house.members.first;
    }
    return null;
  }
}

final currentMemberProvider =
    NotifierProvider<CurrentMemberNotifier, HouseholdMember?>(
        CurrentMemberNotifier.new);

// EXPENSES NOTIFIER
class ExpensesNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() {
    final repo = ref.watch(expenseRepositoryProvider);
    return repo.getExpenses();
  }

  void refresh() {
    final repo = ref.read(expenseRepositoryProvider);
    state = repo.getExpenses();
  }

  Future<void> addExpense(Expense expense) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.addExpense(expense);
    state = repo.getExpenses();
  }

  Future<void> deleteExpense(String id) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.deleteExpense(id);
    state = repo.getExpenses();
  }

  Future<void> settleAll(List<SettlementItem> settlements) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.settleAllDebts(settlements);
    state = repo.getExpenses();
  }

  Future<void> resetAll() async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.resetData();
    ref.read(householdProvider.notifier).refresh();
    ref.read(paymentRequestsProvider.notifier).refresh();
    state = repo.getExpenses();
  }
}

final expensesProvider =
    NotifierProvider<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);

// PAYMENT REQUESTS NOTIFIER (ÇİFT TARAFLI ONAY VE KISMİ ÖDEMELER)
class PaymentRequestsNotifier extends Notifier<List<PaymentRequest>> {
  @override
  List<PaymentRequest> build() {
    final repo = ref.watch(expenseRepositoryProvider);
    return repo.getPaymentRequests();
  }

  void refresh() {
    final repo = ref.read(expenseRepositoryProvider);
    state = repo.getPaymentRequests();
  }

  Future<PaymentRequest> createPayment({
    required String fromMemberId,
    required String fromMemberName,
    required String toMemberId,
    required String toMemberName,
    required double amount,
    String? note,
  }) async {
    final repo = ref.read(expenseRepositoryProvider);
    final req = await repo.createPaymentRequest(
      fromMemberId: fromMemberId,
      fromMemberName: fromMemberName,
      toMemberId: toMemberId,
      toMemberName: toMemberName,
      amount: amount,
      note: note,
    );
    refresh();
    return req;
  }

  Future<void> confirmPayment(String paymentId) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.confirmPayment(paymentId);
    refresh();
  }

  Future<void> rejectPayment(String paymentId) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.rejectPayment(paymentId);
    refresh();
  }
}

final paymentRequestsProvider =
    NotifierProvider<PaymentRequestsNotifier, List<PaymentRequest>>(
        PaymentRequestsNotifier.new);

// APPROVAL REQUESTS NOTIFIER (ORTAK KARAR SİSTEMİ)
class ApprovalRequestsNotifier extends Notifier<List<ApprovalRequest>> {
  @override
  List<ApprovalRequest> build() {
    final repo = ref.watch(expenseRepositoryProvider);
    ref.watch(householdProvider);
    return repo.getApprovalRequests();
  }

  void refresh() {
    final repo = ref.read(expenseRepositoryProvider);
    state = repo.getApprovalRequests();
  }

  Future<ApprovalRequest> createRequest(ApprovalRequest req) async {
    final repo = ref.read(expenseRepositoryProvider);
    final created = await repo.createApprovalRequest(req);
    refresh();
    ref.read(expensesProvider.notifier).refresh();
    return created;
  }

  Future<void> voteRequest({
    required String requestId,
    required String memberId,
    required bool approve,
    required int totalMembersCount,
  }) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.voteApprovalRequest(
      requestId: requestId,
      memberId: memberId,
      approve: approve,
      totalMembersCount: totalMembersCount,
    );
    refresh();
    ref.read(expensesProvider.notifier).refresh();
    ref.read(householdProvider.notifier).refresh();
  }
}

final approvalRequestsProvider =
    NotifierProvider<ApprovalRequestsNotifier, List<ApprovalRequest>>(
        ApprovalRequestsNotifier.new);

// BEKLEYEN BİLDİRİM / ONAY SAYISI (BADGE COUNTER)
final pendingApprovalsCountProvider = Provider<int>((ref) {
  final approvals = ref.watch(approvalRequestsProvider);
  final payments = ref.watch(paymentRequestsProvider);
  final currentMember = ref.watch(currentMemberProvider);

  if (currentMember == null) return 0;

  // Kullanıcının henüz oy vermediği bekleyen onay talepleri
  final pendingApprovalCount = approvals.where((a) =>
      a.isPending &&
      !a.hasVoted(currentMember.id) &&
      a.requestedByMemberId != currentMember.id).length;

  // Kullanıcının onayını bekleyen ödemeler (alacaklı olduğu)
  final pendingPaymentCount = payments.where((p) =>
      p.status == PaymentStatus.pending &&
      p.toMemberId == currentMember.id).length;

  return pendingApprovalCount + pendingPaymentCount;
});

// COMPUTED DEBT ENGINE RESULT PROVIDER
final debtEngineResultProvider = Provider<DebtEngineResult>((ref) {
  final household = ref.watch(householdProvider);
  final expenses = ref.watch(expensesProvider);
  final payments = ref.watch(paymentRequestsProvider);

  if (household == null || household.members.isEmpty) {
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

  return DebtEngine.calculate(
    members: household.members,
    expenses: expenses,
    paymentRequests: payments,
  );
});

// REPORT TIME RANGE NOTIFIER
class ReportTimeRangeNotifier extends Notifier<ReportTimeRange> {
  @override
  ReportTimeRange build() => ReportTimeRange.thisMonth;

  void setRange(ReportTimeRange range) => state = range;
}

final reportTimeRangeProvider =
    NotifierProvider<ReportTimeRangeNotifier, ReportTimeRange>(
        ReportTimeRangeNotifier.new);

// COMPUTED PARTNERSHIP REPORT PROVIDER
final partnershipReportProvider = Provider<PartnershipReport>((ref) {
  final household = ref.watch(householdProvider);
  final expenses = ref.watch(expensesProvider);
  final range = ref.watch(reportTimeRangeProvider);

  if (household == null) {
    return PartnershipReport(
      timeRange: range,
      totalJointExpenses: 0,
      totalPersonalDebts: 0,
      grandTotal: 0,
      perMemberAverage: 0,
      categorySpends: [],
      memberSpends: [],
      totalTransactionCount: 0,
    );
  }

  return ReportingEngine.generate(
    members: household.members,
    expenses: expenses,
    timeRange: range,
  );
});

// HOME TAB NOTIFIER
class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final homeTabProvider =
    NotifierProvider<HomeTabNotifier, int>(HomeTabNotifier.new);

