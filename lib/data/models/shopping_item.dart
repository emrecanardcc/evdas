import 'expense.dart';

/// Ev İçi Ortak İhtiyaç ve Alışveriş Kalemi Modeli
class ShoppingItem {
  final String id;
  final String householdId;
  final String title;
  final ExpenseCategory category;
  final String? customCategory;
  final String addedByMemberId;
  final String? addedByName;
  final DateTime createdAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedByMemberId;
  final double? estimatedPrice;
  final int quantity;
  final String unit;
  final bool isExpenseConverted;
  final String? convertedExpenseId;

  const ShoppingItem({
    required this.id,
    required this.householdId,
    required this.title,
    this.category = ExpenseCategory.market,
    this.customCategory,
    required this.addedByMemberId,
    this.addedByName,
    required this.createdAt,
    this.isCompleted = false,
    this.completedAt,
    this.completedByMemberId,
    this.estimatedPrice,
    this.quantity = 1,
    this.unit = 'Adet',
    this.isExpenseConverted = false,
    this.convertedExpenseId,
  });

  ShoppingItem copyWith({
    String? id,
    String? householdId,
    String? title,
    ExpenseCategory? category,
    String? customCategory,
    String? addedByMemberId,
    String? addedByName,
    DateTime? createdAt,
    bool? isCompleted,
    DateTime? completedAt,
    String? completedByMemberId,
    double? estimatedPrice,
    int? quantity,
    String? unit,
    bool? isExpenseConverted,
    String? convertedExpenseId,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      category: category ?? this.category,
      customCategory: customCategory ?? this.customCategory,
      addedByMemberId: addedByMemberId ?? this.addedByMemberId,
      addedByName: addedByName ?? this.addedByName,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedByMemberId: completedByMemberId ?? this.completedByMemberId,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isExpenseConverted: isExpenseConverted ?? this.isExpenseConverted,
      convertedExpenseId: convertedExpenseId ?? this.convertedExpenseId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'title': title,
      'category': category.name,
      'custom_category': customCategory,
      'added_by_member_id': addedByMemberId,
      'added_by_name': addedByName,
      'created_at': createdAt.toIso8601String(),
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by_member_id': completedByMemberId,
      'estimated_price': estimatedPrice,
      'quantity': quantity,
      'unit': unit,
      'is_expense_converted': isExpenseConverted,
      'converted_expense_id': convertedExpenseId,
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    ExpenseCategory parsedCategory;
    try {
      parsedCategory = ExpenseCategory.values.firstWhere(
        (c) => c.name == (json['category'] as String?),
        orElse: () => ExpenseCategory.market,
      );
    } catch (_) {
      parsedCategory = ExpenseCategory.market;
    }

    return ShoppingItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      category: parsedCategory,
      customCategory: json['custom_category'] as String?,
      addedByMemberId: json['added_by_member_id'] as String? ?? '',
      addedByName: json['added_by_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completedByMemberId: json['completed_by_member_id'] as String?,
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
      quantity: json['quantity'] as int? ?? 1,
      unit: json['unit'] as String? ?? 'Adet',
      isExpenseConverted: json['is_expense_converted'] as bool? ?? false,
      convertedExpenseId: json['converted_expense_id'] as String?,
    );
  }
}
