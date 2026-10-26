import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'household_member.dart';

enum PartnershipType {
  home, // Ev Arkadaşları
  office, // İş Yeri / Ofis Ortaklığı
  travel, // Tatil / Seyahat Grubu
  project, // Proje / Etkinlik Grubu
  other, // Genel Ortaklık
}

extension PartnershipTypeExt on PartnershipType {
  String get displayName {
    switch (this) {
      case PartnershipType.home:
        return 'Ev';
      case PartnershipType.office:
        return 'İş Yeri / Ofis';
      case PartnershipType.travel:
        return 'Tatil / Seyahat';
      case PartnershipType.project:
        return 'Proje / Ekip';
      case PartnershipType.other:
        return 'Ortaklık';
    }
  }

  IconData get icon {
    switch (this) {
      case PartnershipType.home:
        return Icons.home_rounded;
      case PartnershipType.office:
        return Icons.business_rounded;
      case PartnershipType.travel:
        return Icons.flight_takeoff_rounded;
      case PartnershipType.project:
        return Icons.work_outline_rounded;
      case PartnershipType.other:
        return Icons.group_rounded;
    }
  }

  Color get color {
    switch (this) {
      case PartnershipType.home:
        return AppColors.primary;
      case PartnershipType.office:
        return const Color(0xFF0284C7); // Sky Blue
      case PartnershipType.travel:
        return const Color(0xFFF59E0B); // Amber
      case PartnershipType.project:
        return const Color(0xFF7C3AED); // Purple
      case PartnershipType.other:
        return const Color(0xFF10B981); // Emerald
    }
  }
}

class Partnership {
  static const int maxMembers = 6; // MAKSİMUM 6 ORTAK KURALI

  final String id;
  final String name;
  final PartnershipType type;
  final String inviteCode;
  final String currency;
  final String? createdBy;
  final DateTime createdAt;
  final List<HouseholdMember> members;
  final int settlementDay; // Ayın ödeşme günü (1-28)
  final int? customColor; // Özelleştirilmiş renk değeri
  final String? customIcon; // Özelleştirilmiş simge adı

  Partnership({
    required this.id,
    required this.name,
    this.type = PartnershipType.home,
    required this.inviteCode,
    this.currency = 'TRY',
    this.createdBy,
    DateTime? createdAt,
    this.members = const [],
    this.settlementDay = 1,
    this.customColor,
    this.customIcon,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFull => members.length >= maxMembers;
  int get remainingSlots => (maxMembers - members.length).clamp(0, maxMembers);

  Color get displayColor =>
      customColor != null ? Color(customColor!) : type.color;

  IconData get displayIcon {
    if (customIcon == null) return type.icon;
    switch (customIcon) {
      case 'home':
        return Icons.home_rounded;
      case 'apartment':
        return Icons.apartment_rounded;
      case 'villa':
        return Icons.villa_rounded;
      case 'business':
        return Icons.business_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'beach':
        return Icons.beach_access_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      default:
        return type.icon;
    }
  }

  factory Partnership.fromJson(Map<String, dynamic> json,
      {List<HouseholdMember>? members}) {
    return Partnership(
      id: json['id'] as String,
      name: json['name'] as String,
      type: _parseType(json['type'] as String?),
      inviteCode: json['invite_code'] as String? ?? 'ORTAK-0000',
      currency: json['currency'] as String? ?? 'TRY',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      members: members ?? [],
      settlementDay: (json['settlement_day'] as num?)?.toInt() ?? 1,
      customColor: (json['custom_color'] as num?)?.toInt(),
      customIcon: json['custom_icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'invite_code': inviteCode,
      'currency': currency,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'settlement_day': settlementDay,
      'custom_color': customColor,
      'custom_icon': customIcon,
    };
  }

  static final Map<String, PartnershipType> _typeMap = {
    for (final t in PartnershipType.values) t.name.toLowerCase(): t,
  };

  static PartnershipType _parseType(String? val) {
    if (val == null) return PartnershipType.home;
    return _typeMap[val.toLowerCase()] ?? PartnershipType.home;
  }

  Partnership copyWith({
    String? id,
    String? name,
    PartnershipType? type,
    String? inviteCode,
    String? currency,
    String? createdBy,
    DateTime? createdAt,
    List<HouseholdMember>? members,
    int? settlementDay,
    int? customColor,
    String? customIcon,
  }) {
    return Partnership(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      inviteCode: inviteCode ?? this.inviteCode,
      currency: currency ?? this.currency,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      settlementDay: settlementDay ?? this.settlementDay,
      customColor: customColor ?? this.customColor,
      customIcon: customIcon ?? this.customIcon,
    );
  }
}
