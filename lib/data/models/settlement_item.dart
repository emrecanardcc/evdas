class SettlementItem {
  final String fromMemberId;
  final String fromMemberName;
  final String toMemberId;
  final String toMemberName;
  final double amount;
  final bool isSettled;

  SettlementItem({
    required this.fromMemberId,
    required this.fromMemberName,
    required this.toMemberId,
    required this.toMemberName,
    required this.amount,
    this.isSettled = false,
  });

  factory SettlementItem.fromJson(Map<String, dynamic> json) {
    return SettlementItem(
      fromMemberId: json['from_member_id'] as String,
      fromMemberName: json['from_member_name'] as String,
      toMemberId: json['to_member_id'] as String,
      toMemberName: json['to_member_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      isSettled: json['is_settled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_member_id': fromMemberId,
      'from_member_name': fromMemberName,
      'to_member_id': toMemberId,
      'to_member_name': toMemberName,
      'amount': amount,
      'is_settled': isSettled,
    };
  }

  SettlementItem copyWith({
    String? fromMemberId,
    String? fromMemberName,
    String? toMemberId,
    String? toMemberName,
    double? amount,
    bool? isSettled,
  }) {
    return SettlementItem(
      fromMemberId: fromMemberId ?? this.fromMemberId,
      fromMemberName: fromMemberName ?? this.fromMemberName,
      toMemberId: toMemberId ?? this.toMemberId,
      toMemberName: toMemberName ?? this.toMemberName,
      amount: amount ?? this.amount,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}
