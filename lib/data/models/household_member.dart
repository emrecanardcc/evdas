class HouseholdMember {
  final String id;
  final String householdId;
  final String? userId;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;
  final String? iban;

  HouseholdMember({
    required this.id,
    required this.householdId,
    this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = 'member',
    DateTime? joinedAt,
    this.iban,
  }) : joinedAt = joinedAt ?? DateTime.now();

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      id: json['id'] as String,
      householdId: (json['household_id'] ?? json['partnership_id']) as String,
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
      iban: json['iban'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'partnership_id': householdId,
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'iban': iban,
    };
  }

  HouseholdMember copyWith({
    String? id,
    String? householdId,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? role,
    DateTime? joinedAt,
    String? iban,
  }) {
    return HouseholdMember(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      iban: iban ?? this.iban,
    );
  }
}
