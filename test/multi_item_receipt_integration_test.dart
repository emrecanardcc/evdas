import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/haptic_service.dart';
import 'package:evdas_mobile/core/services/sound_service.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/screens/quick_expense_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ExpenseRepository repo;
  late Partnership testHouse;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await HapticService.init(prefs);
    await SoundService.init(prefs);

    repo = await ExpenseRepository.init();
    testHouse = await repo.createPartnership(
      name: 'Moda Evi',
      type: PartnershipType.home,
      creatorName: 'Ali',
    );
    await repo.addMemberToHousehold('Veli');
  });

  group('Multi-Item Receipt Integration & Batch Saving Tests', () {
    test('ExpenseRepository.addExpenses çoklu kalemleri atomik olarak kaydetmelidir', () async {
      expect(repo.getExpenses(), isEmpty);

      final items = [
        Expense(
          id: 'exp-1',
          householdId: testHouse.id,
          title: 'Süt 1L (Migros)',
          amount: 38.50,
          type: ExpenseType.joint,
          category: ExpenseCategory.market,
          paidByMemberId: testHouse.members.first.id,
          expenseDate: DateTime.now(),
        ),
        Expense(
          id: 'exp-2',
          householdId: testHouse.id,
          title: 'Deterjan (Migros)',
          amount: 98.00,
          type: ExpenseType.joint,
          category: ExpenseCategory.market,
          paidByMemberId: testHouse.members.first.id,
          expenseDate: DateTime.now(),
        ),
      ];

      await repo.addExpenses(items);

      final saved = repo.getExpenses();
      expect(saved.length, equals(2));
      expect(saved.any((e) => e.title.contains('Süt') && e.amount == 38.50), isTrue);
      expect(saved.any((e) => e.title.contains('Deterjan') && e.amount == 98.00), isTrue);
    });

    testWidgets('QuickExpenseScreen üzerinden çoklu fiş kalemleri taranıp tek tıkla kaydedilebilmelidir', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuickExpenseScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fiş Oku butonunu bul ve tıkla
      final scanReceiptFinder = find.text('Akıllı Fiş Oku');
      expect(scanReceiptFinder, findsOneWidget);
      await tester.tap(scanReceiptFinder);
      await tester.pumpAndSettle();

      // Modalın açıldığını doğrula
      expect(find.text('Akıllı Fiş & Belge Okuyucu'), findsOneWidget);

      // Migros Market örneğini seç
      final migrosChip = find.text('Migros Market');
      await tester.ensureVisible(migrosChip);
      await tester.pumpAndSettle();
      await tester.tap(migrosChip);
      await tester.pumpAndSettle();

      // 4 kalemin listelendiğini doğrula
      expect(find.text('Ayrıştırılan Kalemler (4)'), findsOneWidget);
      expect(find.text('SÜT 1L'), findsOneWidget);
      expect(find.text('DETERJAN'), findsOneWidget);

      // Seçili 4 kalemi kaydet butonuna kaydır ve tıkla
      final saveBtn = find.text('Seçili 4 Kalemi Ortaklığa Kaydet');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Modal kapanmış ve ortaklığa 4 harcama eklenmiş olmalı
      final savedExpenses = repo.getExpenses();
      expect(savedExpenses.length, equals(4));

      final totalSum = savedExpenses.fold(0.0, (sum, e) => sum + e.amount);
      expect(totalSum, equals(224.00));

      expect(find.textContaining('4 harcama kalemi ortaklığa başarıyla kaydedildi'), findsOneWidget);
    });
  });
}
