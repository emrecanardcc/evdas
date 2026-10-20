import 'household_member.dart';
import 'partnership.dart';

// Geriye dönük tam uyumluluk için Household takma adı
typedef Household = Partnership;

extension HouseholdCompat on Partnership {
  // Household uyumluluk yardımcıları
  static Partnership create({
    required String id,
    required String name,
    required String inviteCode,
    String currency = 'TRY',
    String? createdBy,
    DateTime? createdAt,
    List<HouseholdMember> members = const [],
  }) {
    return Partnership(
      id: id,
      name: name,
      inviteCode: inviteCode,
      currency: currency,
      createdBy: createdBy,
      createdAt: createdAt,
      members: members,
    );
  }
}
