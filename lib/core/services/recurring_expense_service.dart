import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/expense.dart';
import '../../data/models/recurring_expense.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/customization_provider.dart';

/// Düzenli Gider Yönetim Notifier'ı (Riverpod 3.x)
class RecurringExpenseNotifier extends Notifier<List<RecurringExpense>> {
  static const String prefKey = 'evdas_recurring_expenses_list';
  final _uuid = const Uuid();

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<RecurringExpense> build() {
    final prefs = _prefs;
    if (prefs == null) return [];

    final raw = prefs.getStringList(prefKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      return raw
          .map((str) => RecurringExpense.fromJson(jsonDecode(str) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[RecurringExpenseService] Ayrıştırma hatası: $e');
      return [];
    }
  }

  Future<void> _persist(List<RecurringExpense> items) async {
    state = items;
    final prefs = _prefs;
    if (prefs != null) {
      final list = items.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(prefKey, list);
    }
  }

  Future<void> addRecurring(RecurringExpense item) async {
    final updated = List<RecurringExpense>.from(state)..add(item);
    await _persist(updated);
  }

  Future<void> updateRecurring(RecurringExpense item) async {
    final updated = state.map((i) => i.id == item.id ? item : i).toList();
    await _persist(updated);
  }

  Future<void> deleteRecurring(String id) async {
    final updated = state.where((i) => i.id != id).toList();
    await _persist(updated);
  }

  Future<void> toggleActive(String id) async {
    final updated = state.map((i) {
      if (i.id == id) {
        return i.copyWith(isActive: !i.isActive);
      }
      return i;
    }).toList();
    await _persist(updated);
  }

  /// Belirtilen ev/ortaklık için vadesi gelen sabit masrafları otomatik oluşturur
  Future<List<Expense>> processDueExpenses(String householdId, {DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final List<Expense> createdExpenses = [];
    final List<RecurringExpense> updatedRecurringList = [];

    final repo = ref.read(expenseRepositoryProvider);

    for (final item in state) {
      if (item.householdId == householdId && item.isDue(currentTime)) {
        if (item.autoPost) {
          final targetDay = item.dayOfMonth.clamp(1, 28);
          final expenseDate = DateTime(currentTime.year, currentTime.month, targetDay);

          final newExpense = Expense(
            id: _uuid.v4(),
            householdId: item.householdId,
            title: item.title,
            amount: item.amount,
            type: ExpenseType.joint,
            category: item.category,
            paidByMemberId: item.paidByMemberId,
            expenseDate: expenseDate,
            notes: 'Düzenli Masraf Otomasyonu (${item.cadence.displayName})',
            splitMemberWeights: item.splitMemberWeights,
          );

          await repo.addExpense(newExpense);
          createdExpenses.add(newExpense);

          updatedRecurringList.add(item.copyWith(lastExecutedDate: currentTime));
        } else {
          updatedRecurringList.add(item);
        }
      } else {
        updatedRecurringList.add(item);
      }
    }

    if (createdExpenses.isNotEmpty) {
      await _persist(updatedRecurringList);
      ref.read(expensesProvider.notifier).refresh();
    }

    return createdExpenses;
  }
}

/// Recurring Expenses Provider
final recurringExpensesProvider =
    NotifierProvider<RecurringExpenseNotifier, List<RecurringExpense>>(
        RecurringExpenseNotifier.new);
