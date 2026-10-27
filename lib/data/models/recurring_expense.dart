import 'package:flutter/foundation.dart';
import 'expense.dart';

/// Tekrarlanma Periyodu
enum RecurringCadence {
  monthly, // Her ay
  yearly, // Her yıl
}

extension RecurringCadenceExt on RecurringCadence {
  String get displayName {
    switch (this) {
      case RecurringCadence.monthly:
        return 'Aylık';
      case RecurringCadence.yearly:
        return 'Yıllık';
    }
  }
}

/// Düzenli ve Sabit Gider Modeli
@immutable
class RecurringExpense {
  final String id;
  final String householdId;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final String paidByMemberId;
  final int dayOfMonth; // 1 - 28
  final RecurringCadence cadence;
  final bool autoPost; // Otomatik olarak harcama kaydı oluştur
  final bool isActive;
  final DateTime? lastExecutedDate;
  final DateTime createdAt;
  final Map<String, double>? splitMemberWeights;

  RecurringExpense({
    required this.id,
    required this.householdId,
    required this.title,
    required this.amount,
    this.category = ExpenseCategory.kira,
    required this.paidByMemberId,
    this.dayOfMonth = 1,
    this.cadence = RecurringCadence.monthly,
    this.autoPost = true,
    this.isActive = true,
    this.lastExecutedDate,
    DateTime? createdAt,
    this.splitMemberWeights,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Verilen tarih itibarıyla bu düzenli masrafın vadesinin gelip gelmediğini kontrol eder
  bool isDue(DateTime now) {
    if (!isActive) return false;

    // Son yürütme kontrolü
    if (lastExecutedDate != null) {
      if (cadence == RecurringCadence.monthly) {
        if (lastExecutedDate!.year == now.year &&
            lastExecutedDate!.month == now.month) {
          return false; // Bu ay zaten işlendi
        }
      } else if (cadence == RecurringCadence.yearly) {
        if (lastExecutedDate!.year == now.year) {
          return false; // Bu yıl zaten işlendi
        }
      }
    }

    final targetDay = dayOfMonth.clamp(1, 28);
    return now.day >= targetDay;
  }

  /// Bir sonraki vade tarihini hesaplar
  DateTime nextDueDate(DateTime fromDate) {
    final targetDay = dayOfMonth.clamp(1, 28);

    if (fromDate.day < targetDay) {
      return DateTime(fromDate.year, fromDate.month, targetDay);
    } else {
      // Bir sonraki ay
      final nextMonth = fromDate.month == 12 ? 1 : fromDate.month + 1;
      final nextYear = fromDate.month == 12 ? fromDate.year + 1 : fromDate.year;
      return DateTime(nextYear, nextMonth, targetDay);
    }
  }

  factory RecurringExpense.fromJson(Map<String, dynamic> json) {
    return RecurringExpense(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: _parseCategory(json['category'] as String?),
      paidByMemberId: json['paid_by_member_id'] as String,
      dayOfMonth: (json['day_of_month'] as num?)?.toInt() ?? 1,
      cadence: json['cadence'] == 'yearly'
          ? RecurringCadence.yearly
          : RecurringCadence.monthly,
      autoPost: json['auto_post'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      lastExecutedDate: json['last_executed_date'] != null
          ? DateTime.parse(json['last_executed_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      splitMemberWeights: json['split_member_weights'] != null
          ? (json['split_member_weights'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'title': title,
      'amount': amount,
      'category': category.name,
      'paid_by_member_id': paidByMemberId,
      'day_of_month': dayOfMonth,
      'cadence': cadence.name,
      'auto_post': autoPost,
      'is_active': isActive,
      'last_executed_date': lastExecutedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'split_member_weights': splitMemberWeights,
    };
  }

  static ExpenseCategory _parseCategory(String? val) {
    if (val == null) return ExpenseCategory.diger;
    for (final c in ExpenseCategory.values) {
      if (c.name.toLowerCase() == val.toLowerCase()) return c;
    }
    return ExpenseCategory.diger;
  }

  RecurringExpense copyWith({
    String? id,
    String? householdId,
    String? title,
    double? amount,
    ExpenseCategory? category,
    String? paidByMemberId,
    int? dayOfMonth,
    RecurringCadence? cadence,
    bool? autoPost,
    bool? isActive,
    DateTime? lastExecutedDate,
    DateTime? createdAt,
    Map<String, double>? splitMemberWeights,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paidByMemberId: paidByMemberId ?? this.paidByMemberId,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      cadence: cadence ?? this.cadence,
      autoPost: autoPost ?? this.autoPost,
      isActive: isActive ?? this.isActive,
      lastExecutedDate: lastExecutedDate ?? this.lastExecutedDate,
      createdAt: createdAt ?? this.createdAt,
      splitMemberWeights: splitMemberWeights ?? this.splitMemberWeights,
    );
  }
}
