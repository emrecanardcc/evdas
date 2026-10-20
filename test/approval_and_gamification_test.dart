import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/models/approval_request.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/domain/debt_engine.dart';
import 'package:evdas_mobile/domain/reporting_engine.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/screens/decision_wheel_screen.dart';
import 'package:evdas_mobile/presentation/screens/quick_expense_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ortak Karar ve Onay Sistemi (Approval Requests) Testleri', () {
    test('Harcama silme talebi çoğunluk onayına ulaştığında onaylanmalıdır', () {
      final req = ApprovalRequest(
        id: 'req-1',
        partnershipId: 'p-1',
        type: ApprovalType.expenseDelete,
        targetId: 'exp-1',
        title: 'Kira Harcaması Silme',
        requestedByMemberId: 'm-1',
        requestedByName: 'Ali',
        approvals: ['m-1'],
        requiredCount: 2, // 3 kişilik evde çoğunluk = 2
      );

      expect(req.isPending, isTrue);
      expect(req.hasVoted('m-1'), isTrue);
      expect(req.hasVoted('m-2'), isFalse);

      // 2. üye onaylar
      final updated = req.copyWith(
        approvals: [...req.approvals, 'm-2'],
        status: ApprovalStatus.approved,
      );

      expect(updated.isApproved, isTrue);
      expect(updated.approvals.length, greaterThanOrEqualTo(updated.requiredCount));
    });

    test('Ortaklıktan ayrılma talebi oy birliği (100%) gerektirmelidir', () {
      final req = ApprovalRequest(
        id: 'req-2',
        partnershipId: 'p-1',
        type: ApprovalType.leavePartnership,
        targetId: 'm-3',
        title: 'Mehmet Ortaklıktan Ayrılma Talebi',
        requestedByMemberId: 'm-3',
        requestedByName: 'Mehmet',
        approvals: ['m-3'],
        requiredCount: 3, // 3 üyenin tamamı onaylamalı
      );

      expect(req.requiredCount, equals(3));
      expect(req.isPending, isTrue);

      // Tek bir ret oyu süreci reddetmelidir
      final rejected = req.copyWith(
        rejections: ['m-2'],
        status: ApprovalStatus.rejected,
      );

      expect(rejected.isRejected, isTrue);
    });
  });

  group('Şahsi Borçlar ve Raporlama Kırılımı Testleri', () {
    test('Şahsi borç sadece alan ve veren arasında izole hesaplanmalıdır', () {
      final members = [
        HouseholdMember(id: 'm1', householdId: 'p1', displayName: 'Ali'),
        HouseholdMember(id: 'm2', householdId: 'p1', displayName: 'Veli'),
        HouseholdMember(id: 'm3', householdId: 'p1', displayName: 'Can'),
      ];

      final expenses = [
        // Ali 300 TL ortak masraf yaptı (Kişi başı 100 TL düşer)
        Expense(
          id: 'e1',
          householdId: 'p1',
          title: 'Market',
          amount: 300,
          type: ExpenseType.joint,
          paidByMemberId: 'm1',
        ),
        // Ali Veli\'ye 100 TL şahsi borç verdi (Can\'ı kesinlikle etkilememeli!)
        Expense(
          id: 'e2',
          householdId: 'p1',
          title: 'Sinema Bileti',
          amount: 100,
          type: ExpenseType.personalDebt,
          paidByMemberId: 'm1',
          debtorMemberId: 'm2',
        ),
      ];

      final result = DebtEngine.calculate(members: members, expenses: expenses);

      // Ortak havuz: 300 TL / 3 = 100 TL kişi başı
      expect(result.totalJointExpenses, equals(300.0));
      expect(result.perPersonJointShare, equals(100.0));

      // Can'ın bakiyesi SADECE ortak harcamadan ötürü -100 TL olmalıdır (Şahsi borçtan etkilenmez!)
      expect(result.netBalanceByMember['m3'], equals(-100.0));

      // Veli: -100 (ortak pay) - 100 (Ali'ye şahsi borç) = -200 TL
      expect(result.netBalanceByMember['m2'], equals(-200.0));

      // Ali: +200 (ortak alacak) + 100 (Veli'den şahsi alacak) = +300 TL
      expect(result.netBalanceByMember['m1'], equals(300.0));
    });

    test('ReportingEngine şahsi borçların kimden kime olduğunu detaylı listelemelidir', () {
      final members = [
        HouseholdMember(id: 'm1', householdId: 'p1', displayName: 'Ali'),
        HouseholdMember(id: 'm2', householdId: 'p1', displayName: 'Veli'),
      ];

      final expenses = [
        Expense(
          id: 'e1',
          householdId: 'p1',
          title: 'Kahve',
          amount: 75,
          type: ExpenseType.personalDebt,
          paidByMemberId: 'm1',
          debtorMemberId: 'm2',
          expenseDate: DateTime.now(),
        ),
        Expense(
          id: 'e2',
          householdId: 'p1',
          title: 'Taksi',
          amount: 125,
          type: ExpenseType.personalDebt,
          paidByMemberId: 'm1',
          debtorMemberId: 'm2',
          expenseDate: DateTime.now(),
        ),
      ];

      final report = ReportingEngine.generate(
        members: members,
        expenses: expenses,
        timeRange: ReportTimeRange.thisMonth,
      );

      expect(report.totalPersonalDebts, equals(200.0));
      expect(report.personalDebtsBreakdown.length, equals(1));

      final debt = report.personalDebtsBreakdown.first;
      expect(debt.creditorName, equals('Ali'));
      expect(debt.debtorName, equals('Veli'));
      expect(debt.amount, equals(200.0));
      expect(debt.count, equals(2));

      // Rapor özet metninde şahsi borç bilgisi yer almalıdır
      final summary = report.toSummaryString('Test Evi');
      expect(summary.contains('Şahsi Borçlar'), isTrue);
      expect(summary.contains('Veli ➔ Ali'), isTrue);
    });
  });

  group('Ortaklık Özelleştirme & Aylık Ödeşme Günü Testleri', () {
    test('Partnership özel renk, simge ve hesaplaşma gününü saklamalıdır', () {
      final p = Partnership(
        id: 'p-custom',
        name: 'Kadıköy Penthouse',
        inviteCode: 'PENT-1234',
        settlementDay: 15,
        customColor: 0xFFF97316,
        customIcon: 'apartment',
      );

      expect(p.settlementDay, equals(15));
      expect(p.customColor, equals(0xFFF97316));
      expect(p.customIcon, equals('apartment'));
      expect(p.displayIcon, equals(Icons.apartment_rounded));
      expect(p.displayColor, equals(const Color(0xFFF97316)));

      // JSON serileştirme kontrolü
      final json = p.toJson();
      expect(json['settlement_day'], equals(15));
      expect(json['custom_color'], equals(0xFFF97316));
      expect(json['custom_icon'], equals('apartment'));

      final parsed = Partnership.fromJson(json);
      expect(parsed.settlementDay, equals(15));
      expect(parsed.customColor, equals(0xFFF97316));
    });
  });

  group('DecisionWheelScreen (Ev Karar Çarkı) Widget Testleri', () {
    testWidgets('Çark ekranı açılmalı, görev butonları ve katılımcılar listelenmelidir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ExpenseRepository(prefs);

      final p = Partnership(
        id: 'p1',
        name: 'Bizim Ev',
        inviteCode: 'EV-1234',
        members: [
          HouseholdMember(id: 'm1', householdId: 'p1', displayName: 'Ahmet'),
          HouseholdMember(id: 'm2', householdId: 'p1', displayName: 'Burak'),
          HouseholdMember(id: 'm3', householdId: 'p1', displayName: 'Cem'),
        ],
      );
      await repo.saveHousehold(p);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: DecisionWheelScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Başlık ve görev seçenekleri doğrulanmalıdır
      expect(find.text('Ev Karar Çarkı'), findsOneWidget);
      expect(find.text('🗑️ Çöpü Dök'), findsOneWidget);
      expect(find.text('🍽️ Bulaşıkları Yıka'), findsOneWidget);

      // Çevir butonu doğrulanmalıdır
      expect(find.textContaining('Çarkı Çevir!'), findsOneWidget);

      // Katılan ortaklar çipleri doğrulanmalıdır
      expect(find.text('Ahmet'), findsWidgets);
      expect(find.text('Burak'), findsWidgets);
      expect(find.text('Cem'), findsWidgets);
    });
  });

  group('Cihaz Başına Tek Kullanıcı & Profil Düzenleme Testleri', () {
    test('updateMemberProfile hem yerel kaydı hem ortaklık üyesini güncellemelidir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ExpenseRepository(prefs);

      final p = Partnership(
        id: 'p-user',
        name: 'Moda Evi',
        inviteCode: 'EV-MODA',
        members: [
          HouseholdMember(id: 'm1', householdId: 'p-user', displayName: 'Eski İsim', iban: null),
        ],
      );
      await repo.saveHousehold(p);

      await repo.updateMemberProfile(
        memberId: 'm1',
        displayName: 'Yeni Profil İsmi',
        iban: 'TR123456789012345678901234',
      );

      final updatedHouse = repo.getActiveHousehold();
      expect(updatedHouse, isNotNull);
      final member = updatedHouse!.members.firstWhere((m) => m.id == 'm1');
      expect(member.displayName, equals('Yeni Profil İsmi'));
      expect(member.iban, equals('TR123456789012345678901234'));
    });

    testWidgets('QuickExpenseScreen üzerinde kullanıcı değiştirme paneli (switch_account) olmamalıdır', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ExpenseRepository(prefs);

      final p = Partnership(
        id: 'p1',
        name: 'Bizim Ev',
        inviteCode: 'EV-1234',
        members: [
          HouseholdMember(id: 'm1', householdId: 'p1', displayName: 'Emre'),
          HouseholdMember(id: 'm2', householdId: 'p1', displayName: 'Diyar'),
        ],
      );
      await repo.saveHousehold(p);
      await repo.setCurrentUserId('m1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: QuickExpenseScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // switch_account_outlined ikonu kesinlikle bulunmamalıdır
      expect(find.byIcon(Icons.switch_account_outlined), findsNothing);
      expect(find.text('Kullanıcı Değiştir'), findsNothing);

      // Kendi profili başlık yanında veya sağ üstte gösterilmelidir
      expect(find.text('Emre'), findsWidgets);
    });
  });
}
