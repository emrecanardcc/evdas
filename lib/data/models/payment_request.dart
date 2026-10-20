enum PaymentStatus {
  pending, // Alacaklının onayı bekleniyor
  confirmed, // Karşılıklı kabul edildi, borçtan düşüldü
  rejected, // Alacaklı tarafından reddedildi, para hesaba geçmedi
}

extension PaymentStatusExt on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Onay Bekliyor';
      case PaymentStatus.confirmed:
        return 'Onaylandı';
      case PaymentStatus.rejected:
        return 'Reddedildi';
    }
  }
}

class PaymentRequest {
  final String id;
  final String partnershipId;
  final String fromMemberId;
  final String fromMemberName;
  final String toMemberId;
  final String toMemberName;
  final double amount;
  final PaymentStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  PaymentRequest({
    required this.id,
    required this.partnershipId,
    required this.fromMemberId,
    required this.fromMemberName,
    required this.toMemberId,
    required this.toMemberName,
    required this.amount,
    this.status = PaymentStatus.pending,
    this.note,
    DateTime? createdAt,
    this.reviewedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      id: json['id'] as String,
      partnershipId: json['partnership_id'] as String,
      fromMemberId: json['from_member_id'] as String,
      fromMemberName: json['from_member_name'] as String,
      toMemberId: json['to_member_id'] as String,
      toMemberName: json['to_member_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: _parseStatus(json['status'] as String?),
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partnership_id': partnershipId,
      'from_member_id': fromMemberId,
      'from_member_name': fromMemberName,
      'to_member_id': toMemberId,
      'to_member_name': toMemberName,
      'amount': amount,
      'status': status.name,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  static PaymentStatus _parseStatus(String? val) {
    if (val == 'confirmed') return PaymentStatus.confirmed;
    if (val == 'rejected') return PaymentStatus.rejected;
    return PaymentStatus.pending;
  }

  PaymentRequest copyWith({
    String? id,
    String? partnershipId,
    String? fromMemberId,
    String? fromMemberName,
    String? toMemberId,
    String? toMemberName,
    double? amount,
    PaymentStatus? status,
    String? note,
    DateTime? createdAt,
    DateTime? reviewedAt,
  }) {
    return PaymentRequest(
      id: id ?? this.id,
      partnershipId: partnershipId ?? this.partnershipId,
      fromMemberId: fromMemberId ?? this.fromMemberId,
      fromMemberName: fromMemberName ?? this.fromMemberName,
      toMemberId: toMemberId ?? this.toMemberId,
      toMemberName: toMemberName ?? this.toMemberName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
