enum ApprovalType {
  expenseDelete, // Harcama silme talebi
  leavePartnership, // Ortaklıktan ayrılma talebi
  deletePartnership, // Ortaklığı tamamen kapatma / silme talebi
}

enum ApprovalStatus {
  pending, // Onay bekliyor
  approved, // Kabul edildi ve işlem gerçekleştirildi
  rejected, // Reddedildi
}

extension ApprovalTypeExt on ApprovalType {
  String get displayName {
    switch (this) {
      case ApprovalType.expenseDelete:
        return 'Harcama Silme';
      case ApprovalType.leavePartnership:
        return 'Ortaklıktan Ayrılma';
      case ApprovalType.deletePartnership:
        return 'Ortaklığı Kapatma';
    }
  }
}

class ApprovalRequest {
  final String id;
  final String partnershipId;
  final ApprovalType type;
  final String targetId; // Masraf ID, Üye ID veya Ortaklık ID
  final String title;
  final String requestedByMemberId;
  final String requestedByName;
  final List<String> approvals; // Onaylayan üye ID'leri
  final List<String> rejections; // Reddeden üye ID'leri
  final int requiredCount; // Gerekli onay sayısı
  final ApprovalStatus status;
  final DateTime createdAt;
  final Map<String, dynamic> metadata; // Ek bilgiler (örn. masraf tutarı, başlığı)

  ApprovalRequest({
    required this.id,
    required this.partnershipId,
    required this.type,
    required this.targetId,
    required this.title,
    required this.requestedByMemberId,
    required this.requestedByName,
    this.approvals = const [],
    this.rejections = const [],
    required this.requiredCount,
    this.status = ApprovalStatus.pending,
    DateTime? createdAt,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPending => status == ApprovalStatus.pending;
  bool get isApproved => status == ApprovalStatus.approved;
  bool get isRejected => status == ApprovalStatus.rejected;

  bool hasVoted(String memberId) =>
      approvals.contains(memberId) || rejections.contains(memberId);

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      partnershipId: json['partnership_id'] as String,
      type: _parseType(json['type'] as String?),
      targetId: json['target_id'] as String,
      title: json['title'] as String,
      requestedByMemberId: json['requested_by_member_id'] as String,
      requestedByName: json['requested_by_name'] as String? ?? 'Ortak',
      approvals: (json['approvals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rejections: (json['rejections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      requiredCount: (json['required_count'] as num?)?.toInt() ?? 1,
      status: _parseStatus(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partnership_id': partnershipId,
      'type': type.name,
      'target_id': targetId,
      'title': title,
      'requested_by_member_id': requestedByMemberId,
      'requested_by_name': requestedByName,
      'approvals': approvals,
      'rejections': rejections,
      'required_count': requiredCount,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  static ApprovalType _parseType(String? val) {
    if (val == 'leave_partnership' || val == 'leavePartnership') {
      return ApprovalType.leavePartnership;
    }
    if (val == 'delete_partnership' || val == 'deletePartnership') {
      return ApprovalType.deletePartnership;
    }
    return ApprovalType.expenseDelete;
  }

  static ApprovalStatus _parseStatus(String? val) {
    if (val == 'approved') return ApprovalStatus.approved;
    if (val == 'rejected') return ApprovalStatus.rejected;
    return ApprovalStatus.pending;
  }

  ApprovalRequest copyWith({
    String? id,
    String? partnershipId,
    ApprovalType? type,
    String? targetId,
    String? title,
    String? requestedByMemberId,
    String? requestedByName,
    List<String>? approvals,
    List<String>? rejections,
    int? requiredCount,
    ApprovalStatus? status,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ApprovalRequest(
      id: id ?? this.id,
      partnershipId: partnershipId ?? this.partnershipId,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      title: title ?? this.title,
      requestedByMemberId: requestedByMemberId ?? this.requestedByMemberId,
      requestedByName: requestedByName ?? this.requestedByName,
      approvals: approvals ?? this.approvals,
      rejections: rejections ?? this.rejections,
      requiredCount: requiredCount ?? this.requiredCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
