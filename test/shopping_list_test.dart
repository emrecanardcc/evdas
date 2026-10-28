import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/shopping_service.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/models/shopping_item.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/shopping_list_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShoppingItem Model Tests', () {
    test('toJson ve fromJson kayıpsız çalışmalıdır', () {
      final now = DateTime.now();
      final item = ShoppingItem(
        id: 'shop-test-1',
        householdId: 'house-123',
        title: 'Damacana Su',
        category: ExpenseCategory.market,
        customCategory: 'Damacana Su',
        addedByMemberId: 'mem-1',
        addedByName: 'Can',
        createdAt: now,
        isCompleted: true,
        completedAt: now,
        completedByMemberId: 'mem-2',
        estimatedPrice: 90.0,
        quantity: 2,
        unit: 'Damacana',
        isExpenseConverted: true,
        convertedExpenseId: 'exp-123',
      );

      final json = item.toJson();
      final parsed = ShoppingItem.fromJson(json);

      expect(parsed.id, equals(item.id));
      expect(parsed.householdId, equals(item.householdId));
      expect(parsed.title, equals('Damacana Su'));
      expect(parsed.category, equals(ExpenseCategory.market));
      expect(parsed.customCategory, equals('Damacana Su'));
      expect(parsed.quantity, equals(2));
      expect(parsed.estimatedPrice, equals(90.0));
      expect(parsed.isCompleted, isTrue);
      expect(parsed.isExpenseConverted, isTrue);
      expect(parsed.convertedExpenseId, equals('exp-123'));
    });

    test('copyWith alanları doğru güncellemelidir', () {
      final item = ShoppingItem(
        id: 'shop-1',
        householdId: 'house-1',
        title: 'Ekmek',
        addedByMemberId: 'm1',
        createdAt: DateTime.now(),
      );

      final updated = item.copyWith(
        title: 'Tam Buğday Ekmeği',
        quantity: 3,
        isCompleted: true,
      );

      expect(updated.title, equals('Tam Buğday Ekmeği'));
      expect(updated.quantity, equals(3));
      expect(updated.isCompleted, isTrue);
      expect(updated.id, equals('shop-1'));
    });
  });

  group('ShoppingListNotifier Service Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Yeni ihtiyaç kalemi ekleme, tamamlama ve silme başarılı olmalıdır', () async {
      final repo = ExpenseRepository(prefs);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          expenseRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(shoppingListProvider.notifier);

      // 1. Yeni kalem ekle
      final added = await notifier.addItem(
        householdId: 'test-house-1',
        title: 'Zeytinyağı (1L)',
        category: ExpenseCategory.market,
        memberId: 'mem-arda',
        memberName: 'Arda',
        estimatedPrice: 350.0,
        quantity: 1,
        unit: 'Şişe',
      );

      expect(added.title, equals('Zeytinyağı (1L)'));
      expect(container.read(shoppingListProvider).any((i) => i.id == added.id), isTrue);

      // 2. Tamamlandı (Alındı) olarak işaretle
      await notifier.toggleItem(added.id, memberId: 'mem-can');
      var currentItem = container.read(shoppingListProvider).firstWhere((i) => i.id == added.id);
      expect(currentItem.isCompleted, isTrue);
      expect(currentItem.completedByMemberId, equals('mem-can'));

      // 3. Tekrar tıklandığında geri almalı
      await notifier.toggleItem(added.id);
      currentItem = container.read(shoppingListProvider).firstWhere((i) => i.id == added.id);
      expect(currentItem.isCompleted, isFalse);

      // 4. Silme
      await notifier.deleteItem(added.id);
      expect(container.read(shoppingListProvider).any((i) => i.id == added.id), isFalse);
    });

    test('convertToExpense seçili ihtiyaçları ortak harcamaya dönüştürmelidir', () async {
      final repo = ExpenseRepository(prefs);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          expenseRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(shoppingListProvider.notifier);

      final item1 = await notifier.addItem(
        householdId: 'test-house-99',
        title: 'Bulaşık Tableti',
        category: ExpenseCategory.esya,
        memberId: 'm1',
        estimatedPrice: 220.0,
      );

      final item2 = await notifier.addItem(
        householdId: 'test-house-99',
        title: 'Çöp Poşeti',
        category: ExpenseCategory.esya,
        memberId: 'm1',
        estimatedPrice: 45.0,
      );

      // Harcamaya dönüştür
      final createdExpense = await notifier.convertToExpense(
        householdId: 'test-house-99',
        itemIds: [item1.id, item2.id],
        totalAmount: 265.0,
        paidByMemberId: 'm1',
        customTitle: 'Bulaşık Tableti & Çöp Poşeti Alışverişi',
      );

      expect(createdExpense, isNotNull);
      expect(createdExpense!.amount, equals(265.0));
      expect(createdExpense.type, equals(ExpenseType.joint));
      expect(createdExpense.title, contains('Bulaşık Tableti'));

      // Kalemlerin güncellendiğini kontrol et
      final updated1 = container.read(shoppingListProvider).firstWhere((i) => i.id == item1.id);
      expect(updated1.isCompleted, isTrue);
      expect(updated1.isExpenseConverted, isTrue);
      expect(updated1.convertedExpenseId, equals(createdExpense.id));
    });
  });

  group('ShoppingListModal Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('ShoppingListModal render edilmeli ve hızlı şablonla eksik eklenebilmelidir', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = ExpenseRepository(prefs);
      final mockHouse = Partnership(
        id: 'test-house-w',
        name: 'Kadıköy Test Evi',
        type: PartnershipType.home,
        inviteCode: 'TEST12',
        createdAt: DateTime.now(),
        members: [
          HouseholdMember(id: 'u1', householdId: 'test-house-w', displayName: 'Can'),
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
              body: ShoppingListModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Başlık ve sekmeler görünmeli
      expect(find.text('Ortak İhtiyaç Listesi'), findsOneWidget);
      expect(find.textContaining('Alınacaklar'), findsOneWidget);
      expect(find.textContaining('Alınanlar'), findsOneWidget);

      // Hızlı şablon çiplerinden biri bulunmalı (örn: Damacana Su)
      expect(find.text('Damacana Su (19L)'), findsWidgets);

      // Şablona tıklandığında listeye eklenmeli
      await tester.tap(find.text('Damacana Su (19L)').first);
      await tester.pumpAndSettle();

      // Kalem listede görünmeli
      expect(find.text('Damacana Su (19L)'), findsWidgets);
    });
  });
}

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership? _mock;
  _MockHouseholdNotifier(this._mock);
  @override
  Partnership? build() => _mock;
}
