import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/crypto_utils.dart';
import '../models/approval_request.dart';
import '../models/expense.dart';
import '../models/household_member.dart';
import '../models/partnership.dart';
import '../models/payment_request.dart';
import '../models/settlement_item.dart';

class ExpenseRepository {
  static const String _keyActivePartnership = 'evdas_active_partnership_v2';
  static const String _keyPartnershipsList = 'evdas_all_partnerships_v2';
  static const String _keyExpensesPrefix = 'evdas_expenses_p_';
  static const String _keyPaymentsPrefix = 'evdas_payments_p_';
  static const String _keyApprovalsPrefix = 'evdas_approvals_p_';
  static const String _keyOfflineExpensesQueue = 'evdas_offline_expenses_queue_v1';
  static const String _keyCurrentUserId = 'evdas_current_user_id_v2';

  final SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;
  final _uuid = const Uuid();

  // ⚡ L1 IN-MEMORY CACHE (Sıfır Gecikme & Sıfır Gereksiz JSON Çözümleme)
  Partnership? _cachedActivePartnership;
  List<Partnership>? _cachedAllPartnerships;
  final Map<String, List<Expense>> _cachedExpenses = {};
  final Map<String, List<PaymentRequest>> _cachedPayments = {};
  final Map<String, List<ApprovalRequest>> _cachedApprovals = {};
  String? _cachedCurrentUserId;

  // Çevrimdışı senkronizasyon bildirim akışı
  static final StreamController<String> _syncNotificationController =
      StreamController<String>.broadcast();
  static Stream<String> get syncNotifications =>
      _syncNotificationController.stream;

  ExpenseRepository(this._prefs);

  static Future<ExpenseRepository> init() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ExpenseRepository(prefs);
    repo._warmUpCache();

    // Oturum açıksa arka planda bulut ile eşitle (Kullanıcıyı bekletmez)
    if (SupabaseService.isAuthenticated) {
      unawaited(repo.syncWithCloud());
    }

    return repo;
  }

  /// Başlangıçta önbelleği ısıt (Warm-up)
  void _warmUpCache() {
    _cachedCurrentUserId = _prefs.getString(_keyCurrentUserId);
    getAllPartnerships();
    final active = getActiveHousehold();
    if (active != null) {
      getExpensesForPartnership(active.id);
      getPaymentRequestsForPartnership(active.id);
      getApprovalRequestsForPartnership(active.id);
    }
  }

  /// ⚡ CANLI BULUT SENKRONİZASYONU (Supabase Sync Engine)
  Future<void> syncWithCloud() async {
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    if (client == null || user == null) return;

    try {
      // 0. Bekleyen çevrimdışı masrafları buluta aktar
      await _processOfflineQueue();

      // 1. Kullanıcının üyesi olduğu ortaklıkları çek
      final membersRes = await client
          .from('partnership_members')
          .select('partnership_id, display_name, role, iban')
          .eq('user_id', user.id);

      final pIds = (membersRes as List)
          .map((m) => m['partnership_id'].toString())
          .toSet()
          .toList();

      if (pIds.isEmpty) return;

      // 2. Ortaklık detaylarını ve tüm üyelerini çek
      final pListRes = await client
          .from('partnerships')
          .select('*, partnership_members(*)')
          .inFilter('id', pIds);

      final cloudPartnerships = (pListRes as List).map((pMap) {
        final membersData = (pMap['partnership_members'] as List?)
                ?.map((m) =>
                    HouseholdMember.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [];
        return Partnership.fromJson(pMap as Map<String, dynamic>,
            members: membersData);
      }).toList();

      if (cloudPartnerships.isNotEmpty) {
        await savePartnershipList(cloudPartnerships);
        final currentActive = getActiveHousehold();
        if (currentActive == null ||
            !cloudPartnerships.any((p) => p.id == currentActive.id)) {
          await setActivePartnership(cloudPartnerships.first);
        }

        // Aktif ortaklıkta bu kullanıcının profilini otomatik olarak geçerli kullanıcı yap
        final activeNow = getActiveHousehold();
        if (activeNow != null) {
          final myMember = activeNow.members
              .where((m) => m.userId != null && m.userId == user.id)
              .firstOrNull;
          if (myMember != null) {
            await setCurrentUserId(myMember.id);
          }
        }

        // 3. Ortaklıklara ait harcamaları, ödemeleri ve onay taleplerini çek
        for (final p in cloudPartnerships) {
          final expRes = await client
              .from('expenses')
              .select('*')
              .eq('partnership_id', p.id)
              .order('expense_date', ascending: false)
              .limit(100);

          final expenses = (expRes as List)
              .map((e) => Expense.fromJson(e as Map<String, dynamic>))
              .toList();
          await saveExpensesForPartnership(p.id, expenses);

          final payRes = await client
              .from('payment_requests')
              .select('*')
              .eq('partnership_id', p.id)
              .order('created_at', ascending: false)
              .limit(50);

          final payments = (payRes as List)
              .map((pr) => PaymentRequest.fromJson(pr as Map<String, dynamic>))
              .toList();
          await savePaymentRequestsForPartnership(p.id, payments);

          // Onay taleplerini çek
          try {
            final appRes = await client
                .from('approval_requests')
                .select('*')
                .eq('partnership_id', p.id)
                .order('created_at', ascending: false)
                .limit(50);

            final approvals = (appRes as List)
                .map((ar) => ApprovalRequest.fromJson(ar as Map<String, dynamic>))
                .toList();
            await saveApprovalRequestsForPartnership(p.id, approvals);
          } catch (_) {}
        }
      }
    } catch (_) {
      // Çevrimdışı fallback: Hata durumunda yerel L1 önbellek korunur
    }
  }

  /// ⚡ Çevrimdışı biriken masrafları sırayla buluta gönder ve kullanıcıyı bilgilendir
  Future<int> _processOfflineQueue() async {
    final raw = _prefs.getString(_keyOfflineExpensesQueue);
    if (raw == null) return 0;

    final client = SupabaseService.client;
    if (client == null || !SupabaseService.isAuthenticated) return 0;

    List<Expense> queue = [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      queue = list
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return 0;
    }

    if (queue.isEmpty) return 0;

    int syncedCount = 0;
    final List<Expense> remaining = [];

    for (final exp in queue) {
      try {
        final payload = <String, dynamic>{
          'id': exp.id,
          'partnership_id': exp.householdId,
          'title': exp.title,
          'amount': exp.amount,
          'type': exp.type == ExpenseType.personalDebt
              ? 'personal_debt'
              : exp.type == ExpenseType.settlement
                  ? 'settlement'
                  : 'joint',
          'category': exp.category.name,
          'paid_by_member_id': exp.paidByMemberId,
          'debtor_member_id': exp.debtorMemberId,
          'expense_date': exp.expenseDate.toIso8601String(),
          'notes': exp.notes,
        };
        if (exp.splitMemberWeights != null) {
          payload['split_member_weights'] = exp.splitMemberWeights;
        }

        try {
          await client.from('expenses').upsert(payload);
        } catch (_) {
          if (payload.containsKey('split_member_weights')) {
            payload.remove('split_member_weights');
            await client.from('expenses').upsert(payload);
          } else {
            rethrow;
          }
        }

        syncedCount++;

        // Yerel kayıttaki isPendingSync bayrağını kaldır
        final currentExpenses =
            List<Expense>.from(getExpensesForPartnership(exp.householdId));
        final idx = currentExpenses.indexWhere((e) => e.id == exp.id);
        if (idx != -1) {
          currentExpenses[idx] = currentExpenses[idx].copyWith(isPendingSync: false);
          await saveExpensesForPartnership(exp.householdId, currentExpenses);
        }
      } catch (_) {
        remaining.add(exp);
      }
    }

    if (remaining.isEmpty) {
      await _prefs.remove(_keyOfflineExpensesQueue);
    } else {
      final serialized = remaining.map((e) => e.toJson()).toList();
      await _prefs.setString(_keyOfflineExpensesQueue, jsonEncode(serialized));
    }

    if (syncedCount > 0) {
      _syncNotificationController.add(
          '☁️ Çevrimdışıyken kaydettiğiniz $syncedCount harcama buluta başarıyla eşitlendi!');
    }

    return syncedCount;
  }

  // --- PARTNERSHIP OPERATIONS (OPTIMIZED WITH L1 CACHE) ---

  List<Partnership> getAllPartnerships() {
    if (_cachedAllPartnerships != null) return _cachedAllPartnerships!;

    final raw = _prefs.getString(_keyPartnershipsList);
    if (raw == null) {
      _cachedAllPartnerships = [];
      return _cachedAllPartnerships!;
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _cachedAllPartnerships = list.map((item) {
        final map = item as Map<String, dynamic>;
        final membersList = (map['members'] as List<dynamic>?)
                ?.map((m) => HouseholdMember.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [];
        return Partnership.fromJson(map, members: membersList);
      }).toList();
    } catch (_) {
      _cachedAllPartnerships = [];
    }
    return _cachedAllPartnerships!;
  }

  Future<void> savePartnershipList(List<Partnership> list) async {
    _cachedAllPartnerships = list;
    final serialized = list.map((p) {
      final map = p.toJson();
      map['members'] = p.members.map((m) => m.toJson()).toList();
      return map;
    }).toList();
    await _prefs.setString(_keyPartnershipsList, jsonEncode(serialized));
  }

  Partnership? getActiveHousehold() {
    if (_cachedActivePartnership != null) return _cachedActivePartnership;

    final raw = _prefs.getString(_keyActivePartnership);
    if (raw == null) {
      final all = getAllPartnerships();
      _cachedActivePartnership = all.isNotEmpty ? all.first : null;
      return _cachedActivePartnership;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final membersList = (map['members'] as List<dynamic>?)
              ?.map((m) => HouseholdMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];
      _cachedActivePartnership = Partnership.fromJson(map, members: membersList);
    } catch (_) {
      _cachedActivePartnership = null;
    }
    return _cachedActivePartnership;
  }

  Future<void> setActivePartnership(Partnership p) async {
    _cachedActivePartnership = p;
    final map = p.toJson();
    map['members'] = p.members.map((m) => m.toJson()).toList();
    await _prefs.setString(_keyActivePartnership, jsonEncode(map));
  }

  Future<void> saveHousehold(Partnership p) async {
    await setActivePartnership(p);
    final all = List<Partnership>.from(getAllPartnerships());
    final index = all.indexWhere((item) => item.id == p.id);
    if (index != -1) {
      all[index] = p;
    } else {
      all.add(p);
    }
    await savePartnershipList(all);
  }

  Future<Partnership> createPartnership({
    required String name,
    required PartnershipType type,
    required String creatorName,
    String? creatorIban,
  }) async {
    final pId = _uuid.v4();
    final prefix = type == PartnershipType.home
        ? 'EV'
        : type == PartnershipType.office
            ? 'OFS'
            : type == PartnershipType.travel
                ? 'TTL'
                : 'PRJ';
    final code = CryptoUtils.generateSecureInviteCode(prefix: prefix);

    final creatorMember = HouseholdMember(
      id: _uuid.v4(),
      householdId: pId,
      userId: SupabaseService.currentUser?.id,
      displayName: creatorName,
      role: 'admin',
      iban: creatorIban,
    );

    final newP = Partnership(
      id: pId,
      name: name,
      type: type,
      inviteCode: code,
      createdBy: SupabaseService.currentUser?.id,
      members: [creatorMember],
    );

    await saveHousehold(newP);
    await setCurrentUserId(creatorMember.id);

    // Buluta asenkron yazma
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    if (client != null && user != null) {
      unawaited(() async {
        try {
          await client.from('partnerships').insert({
            'id': newP.id,
            'name': newP.name,
            'type': newP.type.name,
            'invite_code': newP.inviteCode,
            'currency': newP.currency,
            'created_by': user.id,
          });

          await client.from('partnership_members').insert({
            'id': creatorMember.id,
            'partnership_id': newP.id,
            'user_id': user.id,
            'display_name': creatorMember.displayName,
            'role': 'admin',
            'iban': creatorMember.iban,
          });
        } catch (_) {}
      }());
    }

    return newP;
  }

  Future<Partnership> joinPartnershipByCode({
    required String inviteCode,
    required String userName,
    String? userIban,
  }) async {
    final cleanCode = inviteCode.trim().toUpperCase();

    if (!CryptoUtils.validateInviteCode(cleanCode)) {
      throw Exception(
          'Geçersiz veya kurcalanmış davet kodu! Lütfen kontrol edin.');
    }

    // 1. Önce buluttan sorgula
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    Partnership? target;

    if (client != null && user != null) {
      try {
        final res = await client
            .from('partnerships')
            .select('*, partnership_members(*)')
            .eq('invite_code', cleanCode)
            .maybeSingle();

        if (res != null) {
          final membersList = (res['partnership_members'] as List?)
                  ?.map((m) =>
                      HouseholdMember.fromJson(m as Map<String, dynamic>))
                  .toList() ??
              [];
          target = Partnership.fromJson(res, members: membersList);
        }
      } catch (_) {}
    }

    // 2. Bulutta yoksa yerel önbelleğe bak
    target ??= getAllPartnerships().firstWhere(
      (p) => p.inviteCode.toUpperCase() == cleanCode,
      orElse: () =>
          throw Exception('Bu koda ait aktif bir ortaklık bulunamadı.'),
    );

    if (target.members.length >= Partnership.maxMembers) {
      throw Exception(
          'Bu ortaklık maksimum kapasitesine (6/6) ulaştı! Yeni ortak eklenemez.');
    }

    final alreadyMember = target.members.any((m) =>
        m.displayName.trim().toLowerCase() == userName.trim().toLowerCase() ||
        (user != null && m.userId == user.id));
    if (alreadyMember) {
      throw Exception('Bu ortaklığa zaten dahilsiniz!');
    }

    final newMember = HouseholdMember(
      id: _uuid.v4(),
      householdId: target.id,
      userId: user?.id,
      displayName: userName,
      role: 'member',
      iban: userIban,
    );

    final updated = target.copyWith(members: [...target.members, newMember]);
    await saveHousehold(updated);
    await setCurrentUserId(newMember.id);

    // Buluta asenkron yazma
    if (client != null && user != null) {
      unawaited(() async {
        try {
          await client.from('partnership_members').insert({
            'id': newMember.id,
            'partnership_id': target!.id,
            'user_id': user.id,
            'display_name': newMember.displayName,
            'role': 'member',
            'iban': newMember.iban,
          });
        } catch (_) {}
      }());
    }

    return updated;
  }

  Future<void> addMemberToHousehold(String displayName, {String? iban}) async {
    final current = getActiveHousehold();
    if (current == null) return;

    if (current.members.length >= Partnership.maxMembers) {
      throw Exception('Bu ortaklıkta maksimum 6 üye yer alabilir.');
    }

    final newMember = HouseholdMember(
      id: _uuid.v4(),
      householdId: current.id,
      displayName: displayName,
      role: 'member',
      iban: iban,
    );

    final updatedMembers = [...current.members, newMember];
    await saveHousehold(current.copyWith(members: updatedMembers));
  }

  /// Kullanıcının kendi profilini (İsim & IBAN) güncellemesi
  Future<void> updateMemberProfile({
    required String memberId,
    required String displayName,
    String? iban,
  }) async {
    final house = getActiveHousehold();
    if (house == null) return;

    final updatedMembers = house.members.map((m) {
      if (m.id == memberId) {
        return m.copyWith(displayName: displayName, iban: iban);
      }
      return m;
    }).toList();

    final updatedHouse = house.copyWith(members: updatedMembers);
    await saveHousehold(updatedHouse);

    // Buluta asenkron güncelleme
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;
    if (client != null) {
      unawaited(() async {
        try {
          await client.from('partnership_members').update({
            'display_name': displayName,
            'iban': iban,
          }).eq('id', memberId);

          if (user != null) {
            await client.from('profiles').update({
              'full_name': displayName,
              'iban': iban,
            }).eq('id', user.id);
          }
        } catch (_) {}
      }());
    }
  }

  // --- CURRENT USER ID ---

  String? getCurrentUserId() {
    return _cachedCurrentUserId ?? _prefs.getString(_keyCurrentUserId);
  }

  Future<void> setCurrentUserId(String memberId) async {
    _cachedCurrentUserId = memberId;
    await _prefs.setString(_keyCurrentUserId, memberId);
  }

  // --- EXPENSE OPERATIONS (OPTIMIZED L1 CACHE) ---

  List<Expense> getExpenses() {
    final active = getActiveHousehold();
    if (active == null) return [];
    return getExpensesForPartnership(active.id);
  }

  List<Expense> getExpensesForPartnership(String partnershipId) {
    if (_cachedExpenses.containsKey(partnershipId)) {
      return _cachedExpenses[partnershipId]!;
    }

    final raw = _prefs.getString('$_keyExpensesPrefix$partnershipId');
    if (raw == null) {
      _cachedExpenses[partnershipId] = [];
      return _cachedExpenses[partnershipId]!;
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      _cachedExpenses[partnershipId] = parsed;
    } catch (_) {
      _cachedExpenses[partnershipId] = [];
    }
    return _cachedExpenses[partnershipId]!;
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    final active = getActiveHousehold();
    if (active == null) return;
    await saveExpensesForPartnership(active.id, expenses);
  }

  Future<void> saveExpensesForPartnership(
      String partnershipId, List<Expense> expenses) async {
    _cachedExpenses[partnershipId] = expenses;
    final list = expenses.map((e) => e.toJson()).toList();
    await _prefs.setString(
        '$_keyExpensesPrefix$partnershipId', jsonEncode(list));
  }

  Future<void> addExpense(Expense expense) async {
    final client = SupabaseService.client;
    final isOnline = client != null && SupabaseService.isAuthenticated;

    Expense finalExpense = expense;

    if (!isOnline) {
      // Çevrimdışı modu: Senkronizasyon kuyruğuna ekle ve rozet ile işaretle
      finalExpense = expense.copyWith(isPendingSync: true);
      await _addToOfflineQueue(finalExpense);
    }

    final current = List<Expense>.from(getExpenses());
    current.insert(0, finalExpense);
    await saveExpenses(current);

    // Çevrimiçi ise buluta yazmayı dene
    if (isOnline) {
      unawaited(() async {
        try {
          final payload = <String, dynamic>{
            'id': finalExpense.id,
            'partnership_id': finalExpense.householdId,
            'title': finalExpense.title,
            'amount': finalExpense.amount,
            'type': finalExpense.type == ExpenseType.personalDebt
                ? 'personal_debt'
                : finalExpense.type == ExpenseType.settlement
                    ? 'settlement'
                    : 'joint',
            'category': finalExpense.category.name,
            'paid_by_member_id': finalExpense.paidByMemberId,
            'debtor_member_id': finalExpense.debtorMemberId,
            'expense_date': finalExpense.expenseDate.toIso8601String(),
            'notes': finalExpense.notes,
          };
          if (finalExpense.splitMemberWeights != null) {
            payload['split_member_weights'] = finalExpense.splitMemberWeights;
          }

          try {
            await client.from('expenses').insert(payload);
          } catch (_) {
            if (payload.containsKey('split_member_weights')) {
              payload.remove('split_member_weights');
              await client.from('expenses').insert(payload);
            } else {
              rethrow;
            }
          }
        } catch (_) {
          // Ağ hatası oluştuysa çevrimdışı kuyruğa al ve yerel bayrağı güncelle
          await _addToOfflineQueue(finalExpense);
          final updatedList = List<Expense>.from(getExpenses());
          final idx = updatedList.indexWhere((e) => e.id == finalExpense.id);
          if (idx != -1) {
            updatedList[idx] = updatedList[idx].copyWith(isPendingSync: true);
            await saveExpenses(updatedList);
          }
        }
      }());
    }
  }

  Future<void> _addToOfflineQueue(Expense expense) async {
    try {
      final raw = _prefs.getString(_keyOfflineExpensesQueue);
      List<Expense> queue = [];
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        queue = list
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (!queue.any((e) => e.id == expense.id)) {
        queue.add(expense);
        await _prefs.setString(
            _keyOfflineExpensesQueue,
            jsonEncode(queue.map((e) => e.toJson()).toList()));
      }
    } catch (_) {}
  }

  Future<void> deleteExpense(String expenseId) async {
    final current = List<Expense>.from(getExpenses());
    current.removeWhere((e) => e.id == expenseId);
    await saveExpenses(current);

    // Buluttan asenkron silme
    final client = SupabaseService.client;
    if (client != null) {
      unawaited(() async {
        try {
          await client.from('expenses').delete().eq('id', expenseId);
        } catch (_) {}
      }());
    }
  }

  // --- PAYMENT REQUESTS OPERATIONS (OPTIMIZED L1 CACHE) ---

  List<PaymentRequest> getPaymentRequests() {
    final active = getActiveHousehold();
    if (active == null) return [];
    return getPaymentRequestsForPartnership(active.id);
  }

  List<PaymentRequest> getPaymentRequestsForPartnership(String partnershipId) {
    if (_cachedPayments.containsKey(partnershipId)) {
      return _cachedPayments[partnershipId]!;
    }

    final raw = _prefs.getString('$_keyPaymentsPrefix$partnershipId');
    if (raw == null) {
      _cachedPayments[partnershipId] = [];
      return _cachedPayments[partnershipId]!;
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((item) => PaymentRequest.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cachedPayments[partnershipId] = parsed;
    } catch (_) {
      _cachedPayments[partnershipId] = [];
    }
    return _cachedPayments[partnershipId]!;
  }

  Future<void> savePaymentRequestsForPartnership(
      String partnershipId, List<PaymentRequest> requests) async {
    _cachedPayments[partnershipId] = requests;
    final list = requests.map((r) => r.toJson()).toList();
    await _prefs.setString(
        '$_keyPaymentsPrefix$partnershipId', jsonEncode(list));
  }

  Future<PaymentRequest> createPaymentRequest({
    required String fromMemberId,
    required String fromMemberName,
    required String toMemberId,
    required String toMemberName,
    required double amount,
    String? note,
  }) async {
    final house = getActiveHousehold();
    if (house == null) throw Exception('Aktif ortaklık bulunamadı.');

    final request = PaymentRequest(
      id: _uuid.v4(),
      partnershipId: house.id,
      fromMemberId: fromMemberId,
      fromMemberName: fromMemberName,
      toMemberId: toMemberId,
      toMemberName: toMemberName,
      amount: amount,
      status: PaymentStatus.pending,
      note: note,
    );

    final current = List<PaymentRequest>.from(getPaymentRequests());
    current.insert(0, request);
    await savePaymentRequestsForPartnership(house.id, current);

    // Buluta asenkron yazma
    final client = SupabaseService.client;
    if (client != null) {
      unawaited(() async {
        try {
          await client.from('payment_requests').insert({
            'id': request.id,
            'partnership_id': request.partnershipId,
            'from_member_id': request.fromMemberId,
            'to_member_id': request.toMemberId,
            'amount': request.amount,
            'status': 'pending',
            'note': request.note,
          });
        } catch (_) {}
      }());
    }

    return request;
  }

  Future<void> confirmPayment(String paymentId) async {
    final house = getActiveHousehold();
    if (house == null) return;

    final current = List<PaymentRequest>.from(getPaymentRequests());
    final index = current.indexWhere((p) => p.id == paymentId);
    if (index != -1) {
      current[index] = current[index].copyWith(
        status: PaymentStatus.confirmed,
        reviewedAt: DateTime.now(),
      );
      await savePaymentRequestsForPartnership(house.id, current);

      // Buluta asenkron güncelleme
      final client = SupabaseService.client;
      if (client != null) {
        unawaited(() async {
          try {
            await client.from('payment_requests').update({
              'status': 'confirmed',
              'reviewed_at': DateTime.now().toIso8601String(),
            }).eq('id', paymentId);
          } catch (_) {}
        }());
      }
    }
  }

  Future<void> rejectPayment(String paymentId) async {
    final house = getActiveHousehold();
    if (house == null) return;

    final current = List<PaymentRequest>.from(getPaymentRequests());
    final index = current.indexWhere((p) => p.id == paymentId);
    if (index != -1) {
      current[index] = current[index].copyWith(
        status: PaymentStatus.rejected,
        reviewedAt: DateTime.now(),
      );
      await savePaymentRequestsForPartnership(house.id, current);

      // Buluta asenkron güncelleme
      final client = SupabaseService.client;
      if (client != null) {
        unawaited(() async {
          try {
            await client.from('payment_requests').update({
              'status': 'rejected',
              'reviewed_at': DateTime.now().toIso8601String(),
            }).eq('id', paymentId);
          } catch (_) {}
        }());
      }
    }
  }

  // --- APPROVAL REQUESTS OPERATIONS (ORTAK KARAR SİSTEMİ) ---

  List<ApprovalRequest> getApprovalRequests() {
    final active = getActiveHousehold();
    if (active == null) return [];
    return getApprovalRequestsForPartnership(active.id);
  }

  List<ApprovalRequest> getApprovalRequestsForPartnership(String partnershipId) {
    if (_cachedApprovals.containsKey(partnershipId)) {
      return _cachedApprovals[partnershipId]!;
    }

    final raw = _prefs.getString('$_keyApprovalsPrefix$partnershipId');
    if (raw == null) {
      _cachedApprovals[partnershipId] = [];
      return _cachedApprovals[partnershipId]!;
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .map((item) => ApprovalRequest.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cachedApprovals[partnershipId] = parsed;
    } catch (_) {
      _cachedApprovals[partnershipId] = [];
    }
    return _cachedApprovals[partnershipId]!;
  }

  Future<void> saveApprovalRequestsForPartnership(
      String partnershipId, List<ApprovalRequest> requests) async {
    _cachedApprovals[partnershipId] = requests;
    final list = requests.map((r) => r.toJson()).toList();
    await _prefs.setString(
        '$_keyApprovalsPrefix$partnershipId', jsonEncode(list));
  }

  Future<ApprovalRequest> createApprovalRequest(ApprovalRequest req) async {
    final current = List<ApprovalRequest>.from(
        getApprovalRequestsForPartnership(req.partnershipId));
    current.insert(0, req);
    await saveApprovalRequestsForPartnership(req.partnershipId, current);

    // Eğer harcama silme talebi ise, ilgili harcamayı 'silinme onayı bekliyor' yap
    if (req.type == ApprovalType.expenseDelete) {
      final expenses =
          List<Expense>.from(getExpensesForPartnership(req.partnershipId));
      final idx = expenses.indexWhere((e) => e.id == req.targetId);
      if (idx != -1) {
        expenses[idx] = expenses[idx].copyWith(isDeletionPending: true);
        await saveExpensesForPartnership(req.partnershipId, expenses);
      }
    }

    // Buluta asenkron yazma
    final client = SupabaseService.client;
    if (client != null) {
      unawaited(() async {
        try {
          await client.from('approval_requests').insert({
            'id': req.id,
            'partnership_id': req.partnershipId,
            'type': req.type == ApprovalType.leavePartnership
                ? 'leave_partnership'
                : req.type == ApprovalType.deletePartnership
                    ? 'delete_partnership'
                    : 'expense_delete',
            'target_id': req.targetId,
            'title': req.title,
            'requested_by_member_id': req.requestedByMemberId,
            'requested_by_name': req.requestedByName,
            'approvals': req.approvals,
            'rejections': req.rejections,
            'required_count': req.requiredCount,
            'status': req.status.name,
            'metadata': req.metadata,
          });
        } catch (_) {}
      }());
    }

    return req;
  }

  Future<void> voteApprovalRequest({
    required String requestId,
    required String memberId,
    required bool approve,
    required int totalMembersCount,
  }) async {
    final house = getActiveHousehold();
    if (house == null) return;

    final current =
        List<ApprovalRequest>.from(getApprovalRequestsForPartnership(house.id));
    final index = current.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    var req = current[index];
    final approvals = List<String>.from(req.approvals);
    final rejections = List<String>.from(req.rejections);

    approvals.remove(memberId);
    rejections.remove(memberId);

    if (approve) {
      approvals.add(memberId);
    } else {
      rejections.add(memberId);
    }

    ApprovalStatus newStatus = ApprovalStatus.pending;

    if (approvals.length >= req.requiredCount) {
      newStatus = ApprovalStatus.approved;
    } else if (rejections.isNotEmpty && req.type != ApprovalType.expenseDelete) {
      // Ayrılma veya ortaklığı kapatma işlemlerinde oy birliği (unanimous) gerektiğinden tek ret oyu reddeder
      newStatus = ApprovalStatus.rejected;
    } else if (rejections.length > (totalMembersCount - req.requiredCount)) {
      // Yeterli çoğunluğa ulaşılması matematiksel olarak imkansızlaştıysa reddet
      newStatus = ApprovalStatus.rejected;
    }

    req = req.copyWith(
      approvals: approvals,
      rejections: rejections,
      status: newStatus,
    );
    current[index] = req;
    await saveApprovalRequestsForPartnership(house.id, current);

    // Eğer ONAYLANDIYSA eylemi icra et
    if (newStatus == ApprovalStatus.approved) {
      if (req.type == ApprovalType.expenseDelete) {
        await deleteExpense(req.targetId);
      } else if (req.type == ApprovalType.leavePartnership) {
        await removeMemberFromPartnership(house.id, req.targetId);
      } else if (req.type == ApprovalType.deletePartnership) {
        await deletePartnership(house.id);
      }
    } else if (newStatus == ApprovalStatus.rejected) {
      // Eğer harcama silme reddedildiyse, harcamadaki 'isDeletionPending' bayrağını kaldır
      if (req.type == ApprovalType.expenseDelete) {
        final expenses =
            List<Expense>.from(getExpensesForPartnership(house.id));
        final idx = expenses.indexWhere((e) => e.id == req.targetId);
        if (idx != -1) {
          expenses[idx] = expenses[idx].copyWith(isDeletionPending: false);
          await saveExpensesForPartnership(house.id, expenses);
        }
      }
    }

    // Buluta asenkron güncelleme
    final client = SupabaseService.client;
    if (client != null) {
      unawaited(() async {
        try {
          await client.from('approval_requests').update({
            'approvals': approvals,
            'rejections': rejections,
            'status': newStatus.name,
          }).eq('id', requestId);
        } catch (_) {}
      }());
    }
  }

  // --- PARTNERSHIP CUSTOMIZATION & MANAGEMENT ---

  Future<Partnership> updatePartnershipDetails(
    String partnershipId, {
    String? name,
    int? settlementDay,
    int? customColor,
    String? customIcon,
  }) async {
    final all = List<Partnership>.from(getAllPartnerships());
    final index = all.indexWhere((p) => p.id == partnershipId);
    if (index == -1) throw Exception('Ortaklık bulunamadı');

    final updated = all[index].copyWith(
      name: name,
      settlementDay: settlementDay,
      customColor: customColor,
      customIcon: customIcon,
    );

    all[index] = updated;
    await savePartnershipList(all);

    final currentActive = getActiveHousehold();
    if (currentActive?.id == partnershipId) {
      await setActivePartnership(updated);
    }

    // Buluta asenkron güncelleme
    final client = SupabaseService.client;
    if (client != null) {
      unawaited(() async {
        try {
          final updates = <String, dynamic>{};
          if (name != null) updates['name'] = name;
          if (settlementDay != null) updates['settlement_day'] = settlementDay;
          if (customColor != null) updates['custom_color'] = customColor;
          if (customIcon != null) updates['custom_icon'] = customIcon;

          if (updates.isNotEmpty) {
            await client
                .from('partnerships')
                .update(updates)
                .eq('id', partnershipId);
          }
        } catch (_) {}
      }());
    }

    return updated;
  }

  Future<void> removeMemberFromPartnership(
      String partnershipId, String memberId) async {
    final all = List<Partnership>.from(getAllPartnerships());
    final index = all.indexWhere((p) => p.id == partnershipId);
    if (index == -1) return;

    final target = all[index];
    final updatedMembers =
        target.members.where((m) => m.id != memberId).toList();
    final updated = target.copyWith(members: updatedMembers);

    all[index] = updated;
    await savePartnershipList(all);

    final currentActive = getActiveHousehold();
    if (currentActive?.id == partnershipId) {
      await setActivePartnership(updated);
    }

    // Buluttan asenkron üye silme
    final client = SupabaseService.client;
    if (client != null) {
      unawaited(() async {
        try {
          await client.from('partnership_members').delete().eq('id', memberId);
        } catch (_) {}
      }());
    }
  }

  Future<void> deletePartnership(String partnershipId) async {
    final all = List<Partnership>.from(getAllPartnerships());
    all.removeWhere((p) => p.id == partnershipId);
    await savePartnershipList(all);

    _cachedExpenses.remove(partnershipId);
    _cachedPayments.remove(partnershipId);
    _cachedApprovals.remove(partnershipId);
    await _prefs.remove('$_keyExpensesPrefix$partnershipId');
    await _prefs.remove('$_keyPaymentsPrefix$partnershipId');
    await _prefs.remove('$_keyApprovalsPrefix$partnershipId');

    final currentActive = getActiveHousehold();
    if (currentActive?.id == partnershipId) {
      _cachedActivePartnership = all.isNotEmpty ? all.first : null;
      if (_cachedActivePartnership != null) {
        await setActivePartnership(_cachedActivePartnership!);
      } else {
        await _prefs.remove(_keyActivePartnership);
      }
    }

    // Buluttan asenkron silme
    final client = SupabaseService.client;
    if (client != null) {
      unawaited(() async {
        try {
          await client.from('partnerships').delete().eq('id', partnershipId);
        } catch (_) {}
      }());
    }
  }

  Future<void> settleAllDebts(List<SettlementItem> settlements) async {
    final current = List<Expense>.from(getExpenses());
    final house = getActiveHousehold();
    if (house == null) return;

    for (final item in settlements) {
      final settlementExpense = Expense(
        id: _uuid.v4(),
        householdId: house.id,
        title: 'Ödeşme: ${item.fromMemberName} ➔ ${item.toMemberName}',
        amount: item.amount,
        type: ExpenseType.settlement,
        category: ExpenseCategory.diger,
        paidByMemberId: item.fromMemberId,
        debtorMemberId: item.toMemberId,
        expenseDate: DateTime.now(),
        notes: 'Hesap kapatıldı ve ödendi olarak işaretlendi.',
      );
      current.insert(0, settlementExpense);
    }

    await saveExpenses(current);
  }

  /// Apple Guideline 5.1.1(v): Hesabı ve tüm verileri sunucudan ve yerel bellekten kalıcı olarak sil
  Future<void> deleteUserAccount() async {
    await SupabaseService.deleteAccount();
    await resetData();
  }

  Future<void> resetData() async {
    _cachedExpenses.clear();
    _cachedPayments.clear();
    _cachedApprovals.clear();
    _cachedActivePartnership = null;
    _cachedAllPartnerships = null;
    _cachedCurrentUserId = null;

    await _prefs.clear();
  }
}
