import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/subscription_service.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/paywall_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionNotifier Unit Tests (Freemium Engine)', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Başlangıçta kullanıcı Free katmanında olmalıdır', () {
      final state = container.read(subscriptionProvider);
      expect(state.isPro, isFalse);
      expect(state.tier, equals(SubscriptionTier.free));
      expect(state.expiresAt, isNull);
    });

    test('Free katmanında 2 haneye kadar izin verilmeli, 3. hane engellenmelidir', () {
      final state = container.read(subscriptionProvider);
      expect(state.canCreateHousehold(0), isTrue);
      expect(state.canCreateHousehold(1), isTrue);
      expect(state.canCreateHousehold(2), isFalse);
      expect(state.canCreateHousehold(3), isFalse);
    });

    test('Free katmanında detaylı CSV export engellenmelidir', () {
      final state = container.read(subscriptionProvider);
      expect(state.canExportDetailedReports(), isFalse);
    });

    test('Pro Yıllık satın alındığında limitler kalkmalı ve süre 1 yıl olmalıdır', () async {
      final notifier = container.read(subscriptionProvider.notifier);
      final success = await notifier.purchase(SubscriptionTier.proYearly);
      expect(success, isTrue);

      final state = container.read(subscriptionProvider);
      expect(state.isPro, isTrue);
      expect(state.tier, equals(SubscriptionTier.proYearly));
      expect(state.expiresAt, isNotNull);

      // Artık sınırsız ortaklık kurulabilmeli
      expect(state.canCreateHousehold(2), isTrue);
      expect(state.canCreateHousehold(5), isTrue);
      expect(state.canExportDetailedReports(), isTrue);
    });

    test('Pro Aylık satın alındığında süre yaklaşık 30 gün olmalıdır', () async {
      final notifier = container.read(subscriptionProvider.notifier);
      final success = await notifier.purchase(SubscriptionTier.proMonthly);
      expect(success, isTrue);

      final state = container.read(subscriptionProvider);
      expect(state.isPro, isTrue);
      expect(state.expiresAt!.difference(DateTime.now()).inDays, inInclusiveRange(29, 31));
    });

    test('Satın alımları geri yükleme (Restore Purchases) doğru çalışmalıdır', () async {
      final notifier = container.read(subscriptionProvider.notifier);
      await notifier.purchase(SubscriptionTier.lifetime);

      final state = container.read(subscriptionProvider);
      expect(state.isPro, isTrue);

      // Yeni container açılsa bile durumu diskten okumalı
      final newContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      final restoredNotifier = newContainer.read(subscriptionProvider.notifier);
      final isRestored = await restoredNotifier.restorePurchases();
      expect(isRestored, isTrue);

      final newState = newContainer.read(subscriptionProvider);
      expect(newState.isPro, isTrue);
      expect(newState.tier, equals(SubscriptionTier.lifetime));
      newContainer.dispose();
    });
  });

  group('PaywallModal Widget Tests', () {
    testWidgets('PaywallModal ekranda tüm pro özelliklerini ve plan seçeneklerini emojisz listelemelidir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PaywallModal(featureTrigger: 'Test Özelliği'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Modal başlıkları ve trigger açıklaması
      expect(find.text('EVDAS PLUS'), findsOneWidget);
      expect(find.text('Ev Masraflarında Tam Özgürlük'), findsOneWidget);
      expect(find.textContaining('Test Özelliği'), findsOneWidget);

      // Pro özellikleri
      expect(find.text('Sınırsız Ortaklık ve Ev'), findsOneWidget);
      expect(find.text('Finansal Raporlar & Excel/PDF Dışa Aktarım'), findsOneWidget);

      // Plan seçenekleri
      expect(find.text('Aylık Plan'), findsOneWidget);
      expect(find.text('Yıllık Plan'), findsOneWidget);
      expect(find.text('Evdaş Plus\'a Yükselt'), findsOneWidget);
      expect(find.text('Satın Alımları Geri Yükle'), findsOneWidget);

      // Plan seçimi değiştirilebilir olmalı
      await tester.tap(find.text('Aylık Plan'));
      await tester.pumpAndSettle();

      // Satın al butonuna basıldığında başarıyla yükseltilmeli
      await tester.tap(find.text('Evdaş Plus\'a Yükselt'));
      await tester.pumpAndSettle();

      final state = container.read(subscriptionProvider);
      expect(state.isPro, isTrue);
      container.dispose();
    });
  });
}
