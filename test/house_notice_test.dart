import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/house_notice_service.dart';
import 'package:evdas_mobile/data/models/house_notice_board.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/house_notice_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HouseNoticeBoard Model Tests', () {
    test('toJson ve fromJson kayıpsız çalışmalıdır', () {
      final now = DateTime.now();
      final board = HouseNoticeBoard(
        householdId: 'house-notice-1',
        wifiSsid: 'SuperOnline_5G',
        wifiPassword: 'SuperPassword123',
        buildingDoorCode: '2026#',
        trashSchedule: '20:30 kapı önüne',
        boilerValveLocation: 'Tezgah altı mavi vana',
        mainWaterValveLocation: 'Kapı dışı kırmızı vana',
        electricalPanelLocation: 'Holdeki pano',
        spareKeyLocation: 'Ece de',
        landlordName: 'Mehmet Amca',
        landlordPhone: '0533 111 22 33',
        landlordIban: 'TR11 2233 4455 6677 8899 0011 22',
        customRules: const ['Sessizlik 23:00', 'Balkon temizliği'],
        updatedAt: now,
      );

      final json = board.toJson();
      final parsed = HouseNoticeBoard.fromJson(json);

      expect(parsed.householdId, equals(board.householdId));
      expect(parsed.wifiSsid, equals('SuperOnline_5G'));
      expect(parsed.wifiPassword, equals('SuperPassword123'));
      expect(parsed.buildingDoorCode, equals('2026#'));
      expect(parsed.boilerValveLocation, equals('Tezgah altı mavi vana'));
      expect(parsed.landlordName, equals('Mehmet Amca'));
      expect(parsed.customRules.length, equals(2));
      expect(parsed.customRules[0], equals('Sessizlik 23:00'));
    });

    test('copyWith alanları doğru güncellemelidir', () {
      final board = HouseNoticeBoard.initial('house-init-1');
      final updated = board.copyWith(
        wifiSsid: 'Yeni_Wifi_Adi',
        wifiPassword: 'GizliSifre',
      );

      expect(updated.wifiSsid, equals('Yeni_Wifi_Adi'));
      expect(updated.wifiPassword, equals('GizliSifre'));
      expect(updated.householdId, equals('house-init-1'));
    });
  });

  group('HouseNoticeNotifier Service Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Kural ekleme ve silme işlemleri çalışmalıdır', () async {
      final repo = ExpenseRepository(prefs);
      final mockHouse = Partnership(
        id: 'house-notice-svc',
        name: 'Test Evi',
        type: PartnershipType.home,
        inviteCode: 'TEST',
        createdAt: DateTime.now(),
        members: [
          HouseholdMember(id: 'm1', householdId: 'house-notice-svc', displayName: 'Arda'),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          expenseRepositoryProvider.overrideWithValue(repo),
          householdProvider.overrideWith(() => _MockHouseholdNotifier(mockHouse)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(houseNoticeProvider.notifier);
      final initialBoard = container.read(houseNoticeProvider);
      expect(initialBoard, isNotNull);

      final initialRulesCount = initialBoard!.customRules.length;

      // 1. Yeni kural ekle
      await notifier.addRule('Kedi kumunu her gün temizle');
      final afterAdd = container.read(houseNoticeProvider);
      expect(afterAdd!.customRules.length, equals(initialRulesCount + 1));
      expect(afterAdd.customRules.last, equals('Kedi kumunu her gün temizle'));

      // 2. Kural sil
      await notifier.removeRule(afterAdd.customRules.length - 1);
      final afterRemove = container.read(houseNoticeProvider);
      expect(afterRemove!.customRules.length, equals(initialRulesCount));
    });
  });

  group('HouseNoticeModal Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('HouseNoticeModal render edilmeli, Wi-Fi ve ev bilgileri görünmelidir', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = ExpenseRepository(prefs);
      final mockHouse = Partnership(
        id: 'kadikoy_evi_test',
        name: 'Kadıköy Evi',
        type: PartnershipType.home,
        inviteCode: 'TEST',
        createdAt: DateTime.now(),
        members: [
          HouseholdMember(id: 'u1', householdId: 'kadikoy_evi_test', displayName: 'Can'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            expenseRepositoryProvider.overrideWithValue(repo),
            householdProvider.overrideWith(() => _MockHouseholdNotifier(mockHouse)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HouseNoticeModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Başlık
      expect(find.text('Ev Panosu ve Acil Bilgiler'), findsOneWidget);

      // Wi-Fi kartı
      expect(find.text('Ev İnterneti (Wi-Fi)'), findsOneWidget);
      expect(find.text('Kadikoy_Evi_5G'), findsOneWidget);
      expect(find.text('KadikoyEvdas2026'), findsOneWidget);

      // Tesisat ve kapı kartları
      expect(find.text('Bina ve Giriş Bilgileri'), findsOneWidget);
      expect(find.text('Tesisat ve Acil Durum'), findsOneWidget);

      // Kural listesi
      expect(find.text('Ev İçi Kurallar ve Düzen'), findsOneWidget);
    });
  });
}

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership? _mock;
  _MockHouseholdNotifier(this._mock);
  @override
  Partnership? build() => _mock;
}
