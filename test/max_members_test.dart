import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';

void main() {
  group('Maksimum 6 Ortak Sınırı Testleri', () {
    test('Ortaklık kapasitesi ve isFull kuralı', () {
      final members = List.generate(
        6,
        (i) => HouseholdMember(
          id: 'member-$i',
          householdId: 'house-test',
          displayName: 'Ortak $i',
        ),
      );

      final fullPartnership = Partnership(
        id: 'house-test',
        name: '6 Kişilik Ortaklık',
        type: PartnershipType.office,
        inviteCode: 'TEST-6666',
        members: members,
      );

      expect(fullPartnership.members.length, 6);
      expect(fullPartnership.isFull, true);
      expect(fullPartnership.remainingSlots, 0);

      final partialPartnership = fullPartnership.copyWith(
        members: members.sublist(0, 4),
      );

      expect(partialPartnership.isFull, false);
      expect(partialPartnership.remainingSlots, 2);
    });

    test('Repository 7. üye eklendiğinde hata fırlatmalıdır', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await ExpenseRepository.init();

      // Yeni ortaklık kur (1 üye ile başlar)
      final p = await repo.createPartnership(
        name: 'Test Grubu',
        type: PartnershipType.travel,
        creatorName: 'Kurucu',
      );

      expect(p.members.length, 1);

      // 5 üye daha ekle (Toplam 6 üye olur)
      await repo.addMemberToHousehold('Üye 2');
      await repo.addMemberToHousehold('Üye 3');
      await repo.addMemberToHousehold('Üye 4');
      await repo.addMemberToHousehold('Üye 5');
      await repo.addMemberToHousehold('Üye 6');

      final active = repo.getActiveHousehold()!;
      expect(active.members.length, 6);
      expect(active.isFull, true);

      // 7. üyeyi eklemeye çalışınca hata fırlatmalıdır
      expect(
        () async => await repo.addMemberToHousehold('Üye 7 (Fazlalık)'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
