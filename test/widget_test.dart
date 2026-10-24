import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/main.dart';
import 'package:evdas_mobile/presentation/screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  testWidgets('AuthScreen açılışı, canlı form öğeleri ve sözleşme onayı testi (Demo Butonu Yok)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repo = await ExpenseRepository.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repo),
        ],
        child: const EvdasApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Auth Ekranı kurumsal marka öğeleri
    expect(find.text('Evdaş'), findsOneWidget);
    expect(find.text('Ortak Masraf & Harcama Yönetimi'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Kayıt Ol'), findsOneWidget);
    expect(find.text('Şifremi Unuttum?'), findsOneWidget);

    // 2. Demo butonu KESİNLİKLE bulunmamalıdır
    expect(find.text('Giriş Yapmadan Önce Keşfet (Demo Modu) ➔'), findsNothing);

    // 3. "Kayıt Ol" sekmesine geçiş
    final registerTab = find.text('Kayıt Ol');
    await tester.tap(registerTab);
    await tester.pumpAndSettle();

    // 4. Kayıt alanları ve Sözleşme onay kutusu
    expect(find.text('İsim Soyisim'), findsOneWidget);
    expect(find.text('Şifre (Min. 6 Karakter)'), findsOneWidget);
    expect(find.text('IBAN (İsteğe bağlı)'), findsOneWidget);
    expect(find.text('Hesap Oluştur'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('HomeScreen boş durum (Empty State) testi',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repo = await ExpenseRepository.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Ana navigasyon sekmeleri görünmelidir
    expect(find.text('Hızlı Gir'), findsOneWidget);
    expect(find.text('Hareketler'), findsOneWidget);
    expect(find.text('Raporlar'), findsOneWidget);
    expect(find.text('Ödeşme'), findsOneWidget);
    expect(find.text('Ortaklık'), findsOneWidget);

    // 2. Henüz ortaklık olmadığında rehber Boş Durum (Empty State) kartı gelmelidir
    expect(find.text('Hızlı Harcama Girmek İçin Ortaklık Seçin'), findsOneWidget);
    expect(find.text('Yeni Ortaklık Kur'), findsWidgets);
    expect(find.text('Davet Kodu İle Katıl'), findsWidgets);
  });

  testWidgets('HomeScreen aktif ortaklık ve Hızlı Harcama arayüzü testi',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repo = await ExpenseRepository.init();

    // Ortaklık oluşturulduktan sonra ekran açılır
    await repo.createPartnership(
      name: 'Kadıköy Evi',
      type: PartnershipType.home,
      creatorName: 'Ahmet',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Hızlı harcama bileşenleri görünür
    expect(find.text('Ortak Masraf'), findsOneWidget);
    expect(find.text('Şahsi Borç'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);

    // Çift fonksiyonlu kaydet butonları ve akıllı etiketler
    expect(find.text('Tutar Girin'), findsOneWidget);
    expect(find.text('Kaydet & Devam Et'), findsOneWidget);
    expect(find.text('Market'), findsWidgets);
    expect(find.text('Fatura'), findsWidgets);
    expect(find.text('Ekmek'), findsOneWidget);

    // Numpad ile tutar girme testi: 5 tuşuna bas
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.text('⚡ Kaydet & Kapat'), findsOneWidget);
  });
}
