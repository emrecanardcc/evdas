import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/expense.dart';
import '../../data/models/shopping_item.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/customization_provider.dart';
import 'haptic_service.dart';
import 'sound_service.dart';

/// Alışveriş & İhtiyaç Listesi Yönetim Notifier'ı (Riverpod 3.x)
class ShoppingListNotifier extends Notifier<List<ShoppingItem>> {
  static const String prefKey = 'evdas_shopping_items_list';
  final _uuid = const Uuid();

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<ShoppingItem> build() {
    final house = ref.watch(householdProvider);
    final currentHouseId = house?.id ?? 'kadikoy_evi_test';

    final prefs = _prefs;
    if (prefs == null) return _loadDefaultTestItems(currentHouseId);

    final raw = prefs.getStringList(prefKey);
    if (raw == null || raw.isEmpty) {
      return _loadDefaultTestItems(currentHouseId);
    }

    try {
      final items = raw
          .map((str) => ShoppingItem.fromJson(jsonDecode(str) as Map<String, dynamic>))
          .toList();
      if (items.any((i) => i.householdId == currentHouseId)) {
        return items;
      } else {
        return [...items, ..._loadDefaultTestItems(currentHouseId)];
      }
    } catch (e) {
      debugPrint('[ShoppingService] Ayrıştırma hatası: $e');
      return _loadDefaultTestItems(currentHouseId);
    }
  }

  List<ShoppingItem> _loadDefaultTestItems(String houseId) {
    final now = DateTime.now();
    return [
      ShoppingItem(
        id: 'mock-shop-1-$houseId',
        householdId: houseId,
        title: 'Damacana Su (19L)',
        category: ExpenseCategory.market,
        addedByMemberId: 'mem_ece',
        addedByName: 'Ece',
        createdAt: now.subtract(const Duration(hours: 4)),
        estimatedPrice: 90.0,
        quantity: 1,
        unit: 'Damacana',
      ),
      ShoppingItem(
        id: 'mock-shop-2-$houseId',
        householdId: houseId,
        title: 'Tuvalet Kağıdı (32 li)',
        category: ExpenseCategory.esya,
        addedByMemberId: 'mem_can',
        addedByName: 'Can',
        createdAt: now.subtract(const Duration(hours: 8)),
        estimatedPrice: 195.0,
        quantity: 1,
        unit: 'Paket',
      ),
      ShoppingItem(
        id: 'mock-shop-3-$houseId',
        householdId: houseId,
        title: 'Bulaşık Makinesi Tableti',
        category: ExpenseCategory.esya,
        addedByMemberId: 'mem_arda',
        addedByName: 'Arda',
        createdAt: now.subtract(const Duration(hours: 12)),
        estimatedPrice: 240.0,
        quantity: 1,
        unit: 'Kutu',
      ),
    ];
  }

  Future<void> _persist(List<ShoppingItem> items) async {
    state = items;
    final prefs = _prefs;
    if (prefs != null) {
      final list = items.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(prefKey, list);
    }
  }

  Future<ShoppingItem> addItem({
    required String householdId,
    required String title,
    ExpenseCategory category = ExpenseCategory.market,
    String? customCategory,
    required String memberId,
    String? memberName,
    double? estimatedPrice,
    int quantity = 1,
    String unit = 'Adet',
  }) async {
    final newItem = ShoppingItem(
      id: _uuid.v4(),
      householdId: householdId,
      title: title.trim(),
      category: category,
      customCategory: customCategory,
      addedByMemberId: memberId,
      addedByName: memberName,
      createdAt: DateTime.now(),
      estimatedPrice: estimatedPrice,
      quantity: quantity,
      unit: unit,
    );

    final updated = List<ShoppingItem>.from(state)..insert(0, newItem);
    await _persist(updated);
    return newItem;
  }

  Future<void> toggleItem(String id, {String? memberId}) async {
    final now = DateTime.now();
    final updated = state.map((item) {
      if (item.id == id) {
        final willComplete = !item.isCompleted;
        return item.copyWith(
          isCompleted: willComplete,
          completedAt: willComplete ? now : null,
          completedByMemberId: willComplete ? memberId : null,
        );
      }
      return item;
    }).toList();
    await _persist(updated);
  }

  Future<void> deleteItem(String id) async {
    final updated = state.where((item) => item.id != id).toList();
    await _persist(updated);
  }

  Future<void> updateItem(ShoppingItem item) async {
    final updated = state.map((i) => i.id == item.id ? item : i).toList();
    await _persist(updated);
  }

  Future<void> clearCompleted(String householdId) async {
    final updated = state.where((item) {
      return item.householdId != householdId || !item.isCompleted;
    }).toList();
    await _persist(updated);
  }

  /// Seçili veya tamamlanan ihtiyaç kalemlerini tek tıkla ortak harcamaya dönüştürür
  Future<Expense?> convertToExpense({
    required String householdId,
    required List<String> itemIds,
    required double totalAmount,
    required String paidByMemberId,
    String? customTitle,
    ExpenseCategory? category,
  }) async {
    if (itemIds.isEmpty || totalAmount <= 0) return null;

    final targetItems = state.where((i) => itemIds.contains(i.id)).toList();
    if (targetItems.isEmpty) return null;

    final expenseId = _uuid.v4();
    final autoTitle = customTitle?.trim().isNotEmpty == true
        ? customTitle!.trim()
        : (targetItems.length == 1
            ? targetItems.first.title
            : 'Ortak İhtiyaç (${targetItems.map((e) => e.title).take(3).join(', ')}${targetItems.length > 3 ? '...' : ''})');

    final determinedCategory = category ?? targetItems.first.category;

    final newExpense = Expense(
      id: expenseId,
      householdId: householdId,
      title: autoTitle,
      amount: totalAmount,
      type: ExpenseType.joint,
      category: determinedCategory,
      paidByMemberId: paidByMemberId,
      expenseDate: DateTime.now(),
      notes: 'Ortak İhtiyaç Listesinden dönüştürüldü (${targetItems.length} kalem)',
    );

    // Harcamayı kaydet
    await ref.read(expenseRepositoryProvider).addExpense(newExpense);
    ref.read(expensesProvider.notifier).refresh();

    // Kalemleri tamamlandı ve harcamaya dönüştürüldü olarak güncelle
    final updated = state.map((item) {
      if (itemIds.contains(item.id)) {
        return item.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
          completedByMemberId: paidByMemberId,
          isExpenseConverted: true,
          convertedExpenseId: expenseId,
        );
      }
      return item;
    }).toList();

    await _persist(updated);

    HapticService.success();
    SoundService.playKaChing();

    return newExpense;
  }
}

/// Alışveriş Listesi Provider
final shoppingListProvider =
    NotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
        ShoppingListNotifier.new);

/// Aktif ortaklığa ait bekleyen (satın alınmamış) ihtiyaç sayısı
final activeShoppingCountProvider = Provider<int>((ref) {
  final house = ref.watch(householdProvider);
  if (house == null) return 0;
  final items = ref.watch(shoppingListProvider);
  return items.where((i) => i.householdId == house.id && !i.isCompleted).length;
});
