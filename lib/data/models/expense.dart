enum ExpenseType {
  joint, // Ortak ev masrafı (Her üyeye eşit bölünür)
  personalDebt, // Şahsi borç (Doğrudan 1'e 1 borç)
  settlement, // Hesap kapatma / Ödeşme
}

enum ExpenseCategory {
  market,
  fatura,
  kira,
  mutfak,
  esya,
  ulasim,
  diger,
}

extension ExpenseCategoryExt on ExpenseCategory {
  String get displayName {
    switch (this) {
      case ExpenseCategory.market:
        return 'Market';
      case ExpenseCategory.fatura:
        return 'Fatura';
      case ExpenseCategory.kira:
        return 'Kira';
      case ExpenseCategory.mutfak:
        return 'Mutfak';
      case ExpenseCategory.esya:
        return 'Ev Eşyası';
      case ExpenseCategory.ulasim:
        return 'Ulaşım';
      case ExpenseCategory.diger:
        return 'Diğer';
    }
  }

  String get iconName {
    switch (this) {
      case ExpenseCategory.market:
        return 'shopping_cart';
      case ExpenseCategory.fatura:
        return 'bolt';
      case ExpenseCategory.kira:
        return 'home';
      case ExpenseCategory.mutfak:
        return 'restaurant';
      case ExpenseCategory.esya:
        return 'weekend';
      case ExpenseCategory.ulasim:
        return 'directions_car';
      case ExpenseCategory.diger:
        return 'receipt';
    }
  }
}

class Expense {
  final String id;
  final String householdId;
  final String title;
  final double amount;
  final ExpenseType type;
  final ExpenseCategory category;
  final String paidByMemberId;
  final String? debtorMemberId; // Sadece personalDebt ise borçlu kişi
  final DateTime expenseDate;
  final String? notes;
  final DateTime createdAt;
  final bool isPendingSync; // Çevrimdışı eklenmiş ve henüz buluta eşitlenmemiş
  final bool isDeletionPending; // Ortak kararla silinme oylaması sürecinde
  final Map<String, double>? splitMemberWeights; // Özel bölüşüm payları/ağırlıkları

  Expense({
    required this.id,
    required this.householdId,
    required this.title,
    required this.amount,
    this.type = ExpenseType.joint,
    this.category = ExpenseCategory.diger,
    required this.paidByMemberId,
    this.debtorMemberId,
    DateTime? expenseDate,
    this.notes,
    DateTime? createdAt,
    this.isPendingSync = false,
    this.isDeletionPending = false,
    this.splitMemberWeights,
  })  : expenseDate = expenseDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      householdId: (json['household_id'] ?? json['partnership_id']) as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: _parseType(json['type'] as String?),
      category: _parseCategory(json['category'] as String?),
      paidByMemberId: json['paid_by_member_id'] as String,
      debtorMemberId: json['debtor_member_id'] as String?,
      expenseDate: json['expense_date'] != null
          ? DateTime.parse(json['expense_date'] as String)
          : DateTime.now(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isPendingSync: json['is_pending_sync'] as bool? ?? false,
      isDeletionPending: json['is_deletion_pending'] as bool? ?? false,
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
      'partnership_id': householdId,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'paid_by_member_id': paidByMemberId,
      'debtor_member_id': debtorMemberId,
      'expense_date': expenseDate.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'is_pending_sync': isPendingSync,
      'is_deletion_pending': isDeletionPending,
      'split_member_weights': splitMemberWeights,
    };
  }

  static ExpenseType _parseType(String? val) {
    if (val == 'personal_debt' || val == 'personalDebt') {
      return ExpenseType.personalDebt;
    }
    if (val == 'settlement') {
      return ExpenseType.settlement;
    }
    return ExpenseType.joint;
  }

  static final Map<String, ExpenseCategory> _categoryMap = {
    for (final c in ExpenseCategory.values) c.name.toLowerCase(): c,
  };

  static ExpenseCategory _parseCategory(String? val) {
    if (val == null) return ExpenseCategory.diger;
    return _categoryMap[val.toLowerCase()] ?? ExpenseCategory.diger;
  }

  Expense copyWith({
    String? id,
    String? householdId,
    String? title,
    double? amount,
    ExpenseType? type,
    ExpenseCategory? category,
    String? paidByMemberId,
    String? debtorMemberId,
    DateTime? expenseDate,
    String? notes,
    DateTime? createdAt,
    bool? isPendingSync,
    bool? isDeletionPending,
    Map<String, double>? splitMemberWeights,
  }) {
    return Expense(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      paidByMemberId: paidByMemberId ?? this.paidByMemberId,
      debtorMemberId: debtorMemberId ?? this.debtorMemberId,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      isDeletionPending: isDeletionPending ?? this.isDeletionPending,
      splitMemberWeights: splitMemberWeights ?? this.splitMemberWeights,
    );
  }
}
