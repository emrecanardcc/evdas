import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/constants/legal_texts.dart';
import 'package:evdas_mobile/core/services/feedback_service.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/screens/household_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FAZ 4 & FAZ 5: Yasal Sözleşmeler ve Destek Sistemi Doğrulamaları', () {
    test('Destek e-posta adresi emrecanardc.dev@gmail.com olmalıdır', () {
      expect(LegalTexts.contactEmail, 'emrecanardc.dev@gmail.com');
      expect(FeedbackService.supportEmail, 'emrecanardc.dev@gmail.com');
    });

    test('Kullanım Koşulları (EULA) banka şifresi istenmediğini ve hesap silmeyi içermelidir', () {
      final eula = LegalTexts.termsOfService;
      expect(eula.contains('KESİNLİKLE BANKA BİLGİSİ TALEP EDİLMEZ'), isTrue);
      expect(eula.contains('HESAP VE VERİ SİLME (APPLE GUIDELINE 5.1.1(v) UYUMU)'), isTrue);
      expect(eula.contains('emrecanardc.dev@gmail.com'), isTrue);
    });

    test('Gizlilik Politikası (KVKK/GDPR) hassas banka verisi toplanmadığını teyit etmelidir', () {
      final privacy = LegalTexts.privacyPolicy;
      expect(privacy.contains('KESİNLİKLE TOPLANMAYAN HASSAS VERİLER'), isTrue);
      expect(privacy.contains('HESAP VE VERİ SİLME KOLAYLIĞI (Apple 5.1.1(v))'), isTrue);
      expect(privacy.contains('emrecanardc.dev@gmail.com'), isTrue);
    });
  });

  group('FAZ 3: Apple Guideline 5.1.1(v) Hesap Silme & Veri Tasfiyesi', () {
    test('deleteUserAccount tüm yerel depolamayı ve önbelleği sıfırlamalıdır', () async {
      SharedPreferences.setMockInitialValues({
        'all_partnerships': '[]',
        'active_partnership': '{"id":"p1","name":"Test","type":"home","inviteCode":"CODE123","members":[]}',
        'current_user_id': 'u1',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = ExpenseRepository(prefs);

      // Verilerin varlığını kontrol et
      expect(prefs.containsKey('active_partnership'), isTrue);

      // Hesabı sil
      await repo.deleteUserAccount();

      // Depolamanın tamamen temizlendiğini doğrula
      expect(prefs.containsKey('active_partnership'), isFalse);
      expect(prefs.containsKey('all_partnerships'), isFalse);
      expect(prefs.containsKey('current_user_id'), isFalse);
      expect(repo.getActiveHousehold(), isNull);
      expect(repo.getAllPartnerships(), isEmpty);
    });
  });

  group('UI Doğrulaması: HouseholdScreen Yasal, Destek ve Hesap Silme Butonları', () {
    testWidgets('HouseholdScreen ayarlar alanında destek, yasal sözleşmeler ve hesap silme butonları bulunmalıdır',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ExpenseRepository(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: HouseholdScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Boş durumda veya aktif ortaklıkta ayarlar bölümünün varlığını doğrula
      expect(find.text('DESTEK VE GERİ BİLDİRİM'), findsOneWidget);
      expect(find.text('Öneri, Hata veya Şikayet Bildir'), findsOneWidget);
      expect(find.text('YASAL BİLGİLER VE SÖZLEŞMELER'), findsOneWidget);
      expect(find.text('Kullanım Koşulları ve Lisans (EULA)'), findsOneWidget);
      expect(find.text('Gizlilik Politikası ve KVKK Aydınlatması'), findsOneWidget);
      expect(find.text('Hesabımı ve Verilerimi Kalıcı Olarak Sil'), findsOneWidget);
    });
  });
}
