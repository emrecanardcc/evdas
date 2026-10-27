import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_budget.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/customization_provider.dart';

/// Bütçe Yönetim Notifier'ı (Riverpod 3.x)
class BudgetNotifier extends Notifier<HouseholdBudget?> {
  static const String _prefPrefix = 'evdas_household_budget_';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  HouseholdBudget? build() {
    final house = ref.watch(householdProvider);
    if (house == null) return null;

    final prefs = _prefs;
    if (prefs == null) return HouseholdBudget.initial(house.id);

    final key = '$_prefPrefix${house.id}';
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        return HouseholdBudget.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[BudgetService] Bütçe okuma hatası: $e');
      }
    }

    return HouseholdBudget.initial(house.id);
  }

  Future<void> _persist(HouseholdBudget budget) async {
    state = budget;
    final prefs = _prefs;
    if (prefs != null) {
      final key = '$_prefPrefix${budget.householdId}';
      await prefs.setString(key, jsonEncode(budget.toJson()));
    }
  }

  Future<void> updateMonthlyLimit(double limit) async {
    final current = state;
    if (current == null) return;

    final updated = current.copyWith(
      monthlyLimit: limit,
      updatedAt: DateTime.now(),
    );
    await _persist(updated);
  }

  Future<void> updateCategoryLimit(ExpenseCategory cat, double limit) async {
    final current = state;
    if (current == null) return;

    final newMap = Map<ExpenseCategory, double>.from(current.categoryLimits);
    newMap[cat] = limit;

    final updated = current.copyWith(
      categoryLimits: newMap,
      updatedAt: DateTime.now(),
    );
    await _persist(updated);
  }

  Future<void> updateAlertSettings({bool? alert80, bool? alert100}) async {
    final current = state;
    if (current == null) return;

    final updated = current.copyWith(
      alertAt80Percent: alert80 ?? current.alertAt80Percent,
      alertAt100Percent: alert100 ?? current.alertAt100Percent,
      updatedAt: DateTime.now(),
    );
    await _persist(updated);
  }
}

/// Budget Provider
final budgetProvider =
    NotifierProvider<BudgetNotifier, HouseholdBudget?>(BudgetNotifier.new);

/// Bu ayki toplam ortak harcama hesaplayıcı provider
final currentMonthJointSpendProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesProvider);
  final now = DateTime.now();

  double total = 0.0;
  for (final e in expenses) {
    if (e.type == ExpenseType.joint &&
        e.expenseDate.year == now.year &&
        e.expenseDate.month == now.month) {
      total += e.amount;
    }
  }
  return total;
});

/// Bu ayki kategori bazlı harcamaları hesaplayan reaktif provider
final currentMonthCategorySpendsProvider =
    Provider<Map<ExpenseCategory, double>>((ref) {
  final expenses = ref.watch(expensesProvider);
  final now = DateTime.now();

  final map = <ExpenseCategory, double>{};
  for (final e in expenses) {
    if (e.type == ExpenseType.joint &&
        e.expenseDate.year == now.year &&
        e.expenseDate.month == now.month) {
      map[e.category] = (map[e.category] ?? 0.0) + e.amount;
    }
  }
  return map;
});
