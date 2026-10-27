import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/approval_request.dart';
import '../../data/models/burn_rate_analysis.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_budget.dart';
import '../../data/models/household_member.dart';
import '../../data/models/partnership.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/recurring_expense.dart';
import '../../domain/debt_engine.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/customization_provider.dart';
import 'budget_service.dart';
import 'burn_rate_engine.dart';
import 'recurring_expense_service.dart';

/// Bildirim ve Hatırlatıcı Türleri
enum ReminderType {
  settlementDay,
  settlementApproaching,
  highDebt,
  highCredit,
  pendingApproval,
  pendingPayment,
  expenseInactivity,
  recurringDue,
  budgetAlert,
  burnRateWarning,
}

extension ReminderTypeExtension on ReminderType {
  String get label {
    switch (this) {
      case ReminderType.settlementDay:
        return 'Hesaplaşma Günü';
      case ReminderType.settlementApproaching:
        return 'Yaklaşan Hesaplaşma';
      case ReminderType.highDebt:
        return 'Borç Uyarısı';
      case ReminderType.highCredit:
        return 'Alacak Bildirimi';
      case ReminderType.pendingApproval:
        return 'Onay Talebi';
      case ReminderType.pendingPayment:
        return 'Ödeme Doğrulama';
      case ReminderType.expenseInactivity:
        return 'Harcama Hatırlatması';
      case ReminderType.recurringDue:
        return 'Sabit Gider Vadesi';
      case ReminderType.budgetAlert:
        return 'Bütçe Uyarısı';
      case ReminderType.burnRateWarning:
        return 'Harcama Temposu Uyarısı';
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderType.settlementDay:
        return Icons.calendar_month_rounded;
      case ReminderType.settlementApproaching:
        return Icons.event_available_rounded;
      case ReminderType.highDebt:
        return Icons.account_balance_wallet_rounded;
      case ReminderType.highCredit:
        return Icons.savings_rounded;
      case ReminderType.pendingApproval:
        return Icons.how_to_vote_rounded;
      case ReminderType.pendingPayment:
        return Icons.payments_rounded;
      case ReminderType.expenseInactivity:
        return Icons.receipt_long_rounded;
      case ReminderType.recurringDue:
        return Icons.event_repeat_rounded;
      case ReminderType.budgetAlert:
        return Icons.pie_chart_rounded;
      case ReminderType.burnRateWarning:
        return Icons.speed_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ReminderType.settlementDay:
        return AppColors.primary;
      case ReminderType.settlementApproaching:
        return const Color(0xFF0284C7); // Sky blue
      case ReminderType.highDebt:
        return AppColors.negative;
      case ReminderType.highCredit:
        return AppColors.positive;
      case ReminderType.pendingApproval:
        return AppColors.primary;
      case ReminderType.pendingPayment:
        return AppColors.positive;
      case ReminderType.expenseInactivity:
        return const Color(0xFFD97706); // Amber 600
      case ReminderType.recurringDue:
        return const Color(0xFF7C3AED); // Purple 600
      case ReminderType.budgetAlert:
        return const Color(0xFFE11D48); // Rose 600
      case ReminderType.burnRateWarning:
        return const Color(0xFFE11D48); // Rose 600
    }
  }
}

/// Bildirim Öğesi Modeli
@immutable
class ReminderItem {
  final String id;
  final ReminderType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? actionRoute;
  final String? actionLabel;
  final bool isRead;

  const ReminderItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.actionRoute,
    this.actionLabel,
    this.isRead = false,
  });

  ReminderItem copyWith({
    bool? isRead,
  }) {
    return ReminderItem(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      actionRoute: actionRoute,
      actionLabel: actionLabel,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Hatırlatıcı Motoru
class ReminderService {
  static const String prefKeyDismissed = 'evdas_dismissed_reminder_ids';
  static const String prefKeyRead = 'evdas_read_reminder_ids';

  /// Verilen model durumlarına göre aktif hatırlatıcıları $O(N)$ karmaşıklığında hesaplar
  static List<ReminderItem> evaluate({
    required Partnership? house,
    required List<Expense> expenses,
    required List<ApprovalRequest> approvals,
    required List<PaymentRequest> payments,
    required HouseholdMember? currentMember,
    List<RecurringExpense> recurringExpenses = const [],
    HouseholdBudget? budget,
    Set<String> dismissedIds = const {},
    Set<String> readIds = const {},
    DateTime? now,
  }) {
    final List<ReminderItem> results = [];
    final currentTime = now ?? DateTime.now();

    // 1. Hesaplaşma Günü Kontrolü
    if (house != null) {
      final settlementDay = house.settlementDay.clamp(1, 28);
      final currentDay = currentTime.day;

      if (currentDay == settlementDay) {
        final id = 'settlement-today-${house.id}-${currentTime.year}-${currentTime.month}-$currentDay';
        if (!dismissedIds.contains(id)) {
          results.add(
            ReminderItem(
              id: id,
              type: ReminderType.settlementDay,
              title: 'Aylık Hesaplaşma Vakti Geldi',
              message: '${house.name} için bugün belirlenen hesaplaşma günü. Tüm masrafları kapatıp bakiyeleri sıfırlayabilirsiniz.',
              timestamp: currentTime,
              actionRoute: 'settlement',
              actionLabel: 'Hesaplaşmaya Git',
              isRead: readIds.contains(id),
            ),
          );
        }
      } else {
        final diff = settlementDay - currentDay;
        if (diff > 0 && diff <= 2) {
          final id = 'settlement-soon-${house.id}-${currentTime.year}-${currentTime.month}-$currentDay';
          if (!dismissedIds.contains(id)) {
            results.add(
              ReminderItem(
                id: id,
                type: ReminderType.settlementApproaching,
                title: 'Hesaplaşma Günü Yaklaşıyor',
                message: '${house.name} için aylık hesaplaşmaya $diff gün kaldı. Henüz girmediğiniz ortak masraflarınızı ekleyin.',
                timestamp: currentTime,
                actionRoute: 'settlement',
                actionLabel: 'Özeti İncele',
                isRead: readIds.contains(id),
              ),
            );
          }
        }
      }
    }

    // 2. Bekleyen Onay Talepleri (Kullanıcının henüz oy vermediği)
    if (currentMember != null) {
      for (final req in approvals) {
        if (req.isPending && !req.hasVoted(currentMember.id)) {
          final id = 'approval-req-${req.id}';
          if (!dismissedIds.contains(id)) {
            results.add(
              ReminderItem(
                id: id,
                type: ReminderType.pendingApproval,
                title: 'Oyunuzu Bekleyen Onay Talebi',
                message: '${req.requestedByName} "${req.title}" için ortak onay talep etti.',
                timestamp: req.createdAt,
                actionRoute: 'approvals',
                actionLabel: 'Talebi İncele',
                isRead: readIds.contains(id),
              ),
            );
          }
        }
      }
    }

    // 3. Bekleyen Ödeme Talepleri (Kullanıcıya ödeme yapılmış, onay bekleniyor)
    if (currentMember != null) {
      for (final req in payments) {
        if (req.status == PaymentStatus.pending && req.toMemberId == currentMember.id) {
          final id = 'payment-confirm-${req.id}';
          if (!dismissedIds.contains(id)) {
            results.add(
              ReminderItem(
                id: id,
                type: ReminderType.pendingPayment,
                title: 'Ödeme Doğrulaması Bekleniyor',
                message: '${req.fromMemberName} size ${CurrencyFormatter.formatClean(req.amount)} ödeme yaptığını bildirdi.',
                timestamp: req.createdAt,
                actionRoute: 'approvals',
                actionLabel: 'Ödemeyi Onayla',
                isRead: readIds.contains(id),
              ),
            );
          }
        }
      }
    }

    // 4. Yüksek Borç / Alacak Uyarısı (DebtEngine üzerinden)
    if (house != null && currentMember != null && house.members.length > 1) {
      final debtResult = DebtEngine.calculate(
        members: house.members,
        expenses: expenses,
        paymentRequests: payments,
      );

      for (final s in debtResult.settlements) {
        if (s.amount >= 250.0) {
          if (s.fromMemberId == currentMember.id) {
            final id = 'debt-alert-${house.id}-${currentMember.id}-${s.toMemberId}';
            if (!dismissedIds.contains(id)) {
              results.add(
                ReminderItem(
                  id: id,
                  type: ReminderType.highDebt,
                  title: 'Ödenmesi Gereken Borç Bakiyesi',
                  message: '${s.toMemberName} kişisine ${CurrencyFormatter.formatClean(s.amount)} borcunuz bulunuyor. Ödeme bildirimi gönderebilirsiniz.',
                  timestamp: currentTime,
                  actionRoute: 'settlement',
                  actionLabel: 'Ödeme Bildir',
                  isRead: readIds.contains(id),
                ),
              );
            }
          } else if (s.toMemberId == currentMember.id) {
            final id = 'credit-notice-${house.id}-${currentMember.id}-${s.fromMemberId}';
            if (!dismissedIds.contains(id)) {
              results.add(
                ReminderItem(
                  id: id,
                  type: ReminderType.highCredit,
                  title: 'Tahsil Edilecek Alacak',
                  message: '${s.fromMemberName} kişisinden ${CurrencyFormatter.formatClean(s.amount)} alacağınız bulunuyor.',
                  timestamp: currentTime,
                  actionRoute: 'settlement',
                  actionLabel: 'Detayları Gör',
                  isRead: readIds.contains(id),
                ),
              );
            }
          }
        }
      }
    }

    // 5. Masraf Girişi Hareketsizliği Uyarısı (Son 4 gün masraf girilmediyse)
    if (house != null && house.members.length > 1 && expenses.isNotEmpty) {
      final latestExpenseDate = expenses
          .map((e) => e.expenseDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final daysInactive = currentTime.difference(latestExpenseDate).inDays;
      if (daysInactive >= 4) {
        final id = 'inactivity-${house.id}-${currentTime.year}-${currentTime.month}-${currentTime.day}';
        if (!dismissedIds.contains(id)) {
          results.add(
            ReminderItem(
              id: id,
              type: ReminderType.expenseInactivity,
              title: 'Unutulan Masraf Var mı?',
              message: '${house.name} ortaklığında son $daysInactive gündür harcama girilmedi. Fiş veya faturalarınızı kontrol edebilirsiniz.',
              timestamp: currentTime,
              actionRoute: 'quick_expense',
              actionLabel: 'Harcama Ekle',
              isRead: readIds.contains(id),
            ),
          );
        }
      }
    }

    // 6. Düzenli ve Sabit Gider Vadesi Kontrolü
    if (house != null) {
      for (final r in recurringExpenses) {
        if (r.householdId == house.id && r.isActive) {
          final targetDay = r.dayOfMonth.clamp(1, 28);
          final diff = targetDay - currentTime.day;

          if (diff == 0) {
            final id = 'recurring-due-${r.id}-${currentTime.year}-${currentTime.month}-$targetDay';
            if (!dismissedIds.contains(id)) {
              results.add(
                ReminderItem(
                  id: id,
                  type: ReminderType.recurringDue,
                  title: 'Sabit Gider Vadesi Geldi',
                  message: '${r.title} (${CurrencyFormatter.formatClean(r.amount)}) için bugün belirlenen sabit ödeme günü.',
                  timestamp: currentTime,
                  actionRoute: 'quick_expense',
                  actionLabel: 'İncele',
                  isRead: readIds.contains(id),
                ),
              );
            }
          } else if (diff == 1) {
            final id = 'recurring-soon-${r.id}-${currentTime.year}-${currentTime.month}-$targetDay';
            if (!dismissedIds.contains(id)) {
              results.add(
                ReminderItem(
                  id: id,
                  type: ReminderType.recurringDue,
                  title: 'Sabit Gider Yaklaşıyor',
                  message: '${r.title} (${CurrencyFormatter.formatClean(r.amount)}) ödemesine 1 gün kaldı.',
                  timestamp: currentTime,
                  actionRoute: 'quick_expense',
                  actionLabel: 'İncele',
                  isRead: readIds.contains(id),
                ),
              );
            }
          }
        }
      }
    }

    // 7. Bütçe Durumu ve Sınır Kontrolü
    if (house != null && budget != null && budget.monthlyLimit > 0) {
      double currentMonthJointSpend = 0.0;
      for (final e in expenses) {
        if (e.type == ExpenseType.joint &&
            e.expenseDate.year == currentTime.year &&
            e.expenseDate.month == currentTime.month) {
          currentMonthJointSpend += e.amount;
        }
      }

      final ratio = budget.ratio(currentMonthJointSpend);

      if (ratio >= 1.0 && budget.alertAt100Percent) {
        final id = 'budget-exceeded-${house.id}-${currentTime.year}-${currentTime.month}';
        if (!dismissedIds.contains(id)) {
          results.add(
            ReminderItem(
              id: id,
              type: ReminderType.budgetAlert,
              title: 'Aylık Ortak Bütçe Aşıldı',
              message: '${house.name} için hedeflenen ${CurrencyFormatter.formatClean(budget.monthlyLimit)} bütçe limiti aşıldı! Toplam harcama: ${CurrencyFormatter.formatClean(currentMonthJointSpend)}.',
              timestamp: currentTime,
              actionRoute: 'reports',
              actionLabel: 'Raporu Gör',
              isRead: readIds.contains(id),
            ),
          );
        }
      } else if (ratio >= 0.8 && budget.alertAt80Percent) {
        final id = 'budget-80pct-${house.id}-${currentTime.year}-${currentTime.month}';
        if (!dismissedIds.contains(id)) {
          results.add(
            ReminderItem(
              id: id,
              type: ReminderType.budgetAlert,
              title: 'Bütçe Sınırına Yaklaşıldı',
              message: 'Aylık ortak bütçenizin %${(ratio * 100).toStringAsFixed(0)} seviyesine ulaştınız. Kalan harcama payı: ${CurrencyFormatter.formatClean(budget.remaining(currentMonthJointSpend))}.',
              timestamp: currentTime,
              actionRoute: 'reports',
              actionLabel: 'Bütçeyi İncele',
              isRead: readIds.contains(id),
            ),
          );
        }
      }

      // 7b. Kategori Bazlı Bütçe Sınır Kontrolü
      if (budget.categoryLimits.isNotEmpty) {
        final categorySpends = <ExpenseCategory, double>{};
        for (final e in expenses) {
          if (e.type == ExpenseType.joint &&
              e.expenseDate.year == currentTime.year &&
              e.expenseDate.month == currentTime.month) {
            categorySpends[e.category] =
                (categorySpends[e.category] ?? 0.0) + e.amount;
          }
        }

        for (final entry in budget.categoryLimits.entries) {
          final cat = entry.key;
          final catLimit = entry.value;
          if (catLimit <= 0) continue;

          final spent = categorySpends[cat] ?? 0.0;
          final catRatio = spent / catLimit;

          if (catRatio >= 1.0 && budget.alertAt100Percent) {
            final id =
                'cat-budget-exceeded-${house.id}-${cat.name}-${currentTime.year}-${currentTime.month}';
            if (!dismissedIds.contains(id)) {
              results.add(
                ReminderItem(
                  id: id,
                  type: ReminderType.budgetAlert,
                  title: '${cat.displayName} Bütçesi Aşıldı',
                  message:
                      '${cat.displayName} için belirlenen ${CurrencyFormatter.formatClean(catLimit)} tavanı aşıldı! Harcanan: ${CurrencyFormatter.formatClean(spent)}.',
                  timestamp: currentTime,
                  actionRoute: 'reports',
                  actionLabel: 'Raporu Gör',
                  isRead: readIds.contains(id),
                ),
              );
            }
          }
        }
      }

      // 7c. Harcama Temposu ve Erken Projeksiyon Uyarısı (Burn Rate Warning)
      if (budget.monthlyLimit > 0 && currentTime.day >= 5) {
        final currentMonthSpend = expenses.fold<double>(0.0, (acc, e) {
          if (e.type == ExpenseType.joint &&
              e.expenseDate.year == currentTime.year &&
              e.expenseDate.month == currentTime.month) {
            return acc + e.amount;
          }
          return acc;
        });

        final burnRate = BurnRateEngine.calculate(
          monthlyLimit: budget.monthlyLimit,
          currentSpent: currentMonthSpend,
          now: currentTime,
        );

        if (burnRate.status == BurnRateStatus.critical &&
            currentMonthSpend < budget.monthlyLimit &&
            budget.alertAt80Percent) {
          final id =
              'burn-rate-warning-${house.id}-${currentTime.year}-${currentTime.month}';
          if (!dismissedIds.contains(id)) {
            results.add(
              ReminderItem(
                id: id,
                type: ReminderType.burnRateWarning,
                title: 'Harcama Temposu Kritik Seviyede',
                message:
                    'Mevcut hızla ay sonunda bütçenizi ${CurrencyFormatter.formatClean(burnRate.projectedVariance)} aşmanız öngörülüyor. Günlük harcamanızı ${CurrencyFormatter.formatClean(burnRate.safeDailyRemainingBudget)} altında tutmanız önerilir.',
                timestamp: currentTime,
                actionRoute: 'reports',
                actionLabel: 'Analizi Gör',
                isRead: readIds.contains(id),
              ),
            );
          }
        }
      }
    }

    return results;
  }
}

/// ReminderState: Aktif Hatırlatıcılar ve Okunmamış Sayısı
@immutable
class ReminderState {
  final List<ReminderItem> items;
  final Set<String> dismissedIds;
  final Set<String> readIds;

  const ReminderState({
    this.items = const [],
    this.dismissedIds = const {},
    this.readIds = const {},
  });

  int get unreadCount => items.where((i) => !i.isRead).length;
}

/// Hatırlatıcı Notifier (Riverpod 3.x)
class ReminderNotifier extends Notifier<ReminderState> {
  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ReminderState build() {
    final prefs = _prefs;
    final dismissed = prefs?.getStringList(ReminderService.prefKeyDismissed)?.toSet() ?? {};
    final read = prefs?.getStringList(ReminderService.prefKeyRead)?.toSet() ?? {};

    final house = ref.watch(householdProvider);
    final expenses = ref.watch(expensesProvider);
    final approvals = ref.watch(approvalRequestsProvider);
    final payments = ref.watch(paymentRequestsProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final recurring = ref.watch(recurringExpensesProvider);
    final budget = ref.watch(budgetProvider);

    final items = ReminderService.evaluate(
      house: house,
      expenses: expenses,
      approvals: approvals,
      payments: payments,
      currentMember: currentMember,
      recurringExpenses: recurring,
      budget: budget,
      dismissedIds: dismissed,
      readIds: read,
    );

    return ReminderState(
      items: items,
      dismissedIds: dismissed,
      readIds: read,
    );
  }

  Future<void> markAsRead(String id) async {
    final newRead = Set<String>.from(state.readIds)..add(id);
    await _prefs?.setStringList(ReminderService.prefKeyRead, newRead.toList());

    final newItems = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();

    state = ReminderState(
      items: newItems,
      dismissedIds: state.dismissedIds,
      readIds: newRead,
    );
  }

  Future<void> markAllAsRead() async {
    final newRead = Set<String>.from(state.readIds);
    for (final item in state.items) {
      newRead.add(item.id);
    }
    await _prefs?.setStringList(ReminderService.prefKeyRead, newRead.toList());

    final newItems = state.items.map((item) => item.copyWith(isRead: true)).toList();

    state = ReminderState(
      items: newItems,
      dismissedIds: state.dismissedIds,
      readIds: newRead,
    );
  }

  Future<void> dismiss(String id) async {
    final newDismissed = Set<String>.from(state.dismissedIds)..add(id);
    await _prefs?.setStringList(ReminderService.prefKeyDismissed, newDismissed.toList());

    final newItems = state.items.where((i) => i.id != id).toList();

    state = ReminderState(
      items: newItems,
      dismissedIds: newDismissed,
      readIds: state.readIds,
    );
  }

  Future<void> clearAll() async {
    final newDismissed = Set<String>.from(state.dismissedIds);
    for (final item in state.items) {
      newDismissed.add(item.id);
    }
    await _prefs?.setStringList(ReminderService.prefKeyDismissed, newDismissed.toList());

    state = ReminderState(
      items: const [],
      dismissedIds: newDismissed,
      readIds: state.readIds,
    );
  }
}

/// Bildirim Provider'ı
final reminderProvider =
    NotifierProvider<ReminderNotifier, ReminderState>(ReminderNotifier.new);
