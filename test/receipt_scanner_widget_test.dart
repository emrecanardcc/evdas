import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/haptic_service.dart';
import 'package:evdas_mobile/core/utils/receipt_parser.dart';
import 'package:evdas_mobile/presentation/widgets/receipt_scanner_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await HapticService.init(prefs);
  });

  group('ReceiptScannerDialog Widget Tests', () {
    testWidgets('Fiş tarayıcı açılmalı, örnek fiş seçildiğinde ayrıştırma kartı belirmelidir', (tester) async {
      ParsedReceipt? capturedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  capturedResult = await ReceiptScannerDialog.show(ctx);
                },
                child: const Text('TARA'),
              ),
            ),
          ),
        ),
      );

      // Butona tıkla ve modalı aç
      await tester.tap(find.text('TARA'));
      await tester.pumpAndSettle();

      // Modal başlıkları
      expect(find.text('Akıllı Fiş & Belge Okuyucu'), findsOneWidget);
      expect(find.text('Panodan Yapıştır'), findsOneWidget);
      expect(find.text('Migros Market'), findsOneWidget);
      expect(find.text('Enerjisa Elektrik'), findsOneWidget);

      // Migros Market örneğine tıkla
      await tester.tap(find.text('Migros Market'));
      await tester.pumpAndSettle();

      // Ayrıştırılan veriler görünmeli
      expect(find.text('Ayrıştırılan Finansal Veri'), findsOneWidget);
      expect(find.text('Harcamaya Aktar ve Doldur'), findsOneWidget);
      expect(find.textContaining('224'), findsWidgets);

      // Aktar butonuna bas
      await tester.tap(find.text('Harcamaya Aktar ve Doldur'));
      await tester.pumpAndSettle();

      // Modal kapanmış ve sonuç dönmüş olmalı
      expect(capturedResult, isNotNull);
      expect(capturedResult!.amount, equals(224.0));
      expect(capturedResult!.merchantName, contains('MİGROS'));
    });

    testWidgets('Çoklu kalem listesi görüntülenmeli, seçimler güncellenmeli ve kalemler kaydedilmelidir', (tester) async {
      ParsedReceipt? capturedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  capturedResult = await ReceiptScannerDialog.show(ctx);
                },
                child: const Text('TARA'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TARA'));
      await tester.pumpAndSettle();

      // Migros Market örneğini yükle
      await tester.tap(find.text('Migros Market'));
      await tester.pumpAndSettle();

      // Ayrıştırılan kalemler başlığı ve öğeler görünmeli
      expect(find.text('Ayrıştırılan Kalemler (4)'), findsOneWidget);
      expect(find.text('SÜT 1L'), findsOneWidget);
      expect(find.text('DETERJAN'), findsOneWidget);

      // Başlangıçta 4 kalem seçili olmalı
      expect(find.text('Seçili 4 Kalemi Ortaklığa Kaydet'), findsOneWidget);

      // İlk kalemin checkbox'ına kaydır ve seçimi kaldır
      final firstCheckbox = find.byType(Checkbox).first;
      await tester.ensureVisible(firstCheckbox);
      await tester.pumpAndSettle();
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();

      // Seçili sayısı 3'e düşmeli
      final saveBtnFinder = find.text('Seçili 3 Kalemi Ortaklığa Kaydet');
      expect(saveBtnFinder, findsOneWidget);

      // Seçili kalemleri kaydet butonuna kaydır ve bas
      await tester.ensureVisible(saveBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Modal kapanmalı ve lineItemsSavedDirectly true dönmeli
      expect(capturedResult, isNotNull);
      expect(capturedResult!.lineItemsSavedDirectly, isTrue);
      expect(capturedResult!.selectedCount, equals(3));
    });
  });
}
