import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/models/custom_category.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/presentation/providers/category_provider.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/category_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomCategory Model & Provider Tests', () {
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

    test('CustomCategory toJson ve fromJson serileştirmesi kayıpsız çalışmalıdır', () {
      const original = CustomCategory(
        id: 'test_id_1',
        name: 'Kedi Maması',
        iconCodePoint: 0xe4a1,
        colorValue: 0xFF10B981,
      );

      final json = original.toJson();
      final restored = CustomCategory.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.iconCodePoint, equals(original.iconCodePoint));
      expect(restored.colorValue, equals(original.colorValue));
      expect(restored, equals(original));
    });

    test('Başlangıçta varsayılan özel kategoriler yüklenmelidir', () {
      final categories = container.read(customCategoriesProvider);
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c.name == 'Damacana Su'), isTrue);
      expect(categories.any((c) => c.name == 'Evcil Hayvan'), isTrue);
    });

    test('Yeni özel kategori eklendiğinde state güncellenmeli ve SharedPreferences\'a yazılmalıdır', () async {
      final notifier = container.read(customCategoriesProvider.notifier);
      final added = await notifier.addCategory('Balkon & Bahçe');

      expect(added.name, equals('Balkon & Bahçe'));
      final updated = container.read(customCategoriesProvider);
      expect(updated.any((c) => c.name == 'Balkon & Bahçe'), isTrue);

      // Yeni container açıldığında diskten okuyabilmeli
      final newContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      final reloaded = newContainer.read(customCategoriesProvider);
      expect(reloaded.any((c) => c.name == 'Balkon & Bahçe'), isTrue);
      newContainer.dispose();
    });

    test('Özel kategori silindiğinde listeden kaldırılmalıdır', () async {
      final notifier = container.read(customCategoriesProvider.notifier);
      final initial = container.read(customCategoriesProvider);
      final targetId = initial.first.id;

      await notifier.removeCategory(targetId);
      final updated = container.read(customCategoriesProvider);
      expect(updated.any((c) => c.id == targetId), isFalse);
    });
  });

  group('CategorySelector Widget Tests', () {
    testWidgets('CategorySelector standart kategorileri ve özel kategorileri emojisz göstermeli, Kira olmamalıdır', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      ExpenseCategory selected = ExpenseCategory.market;
      CustomCategory? selectedCustom;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return CategorySelector(
                    selectedCategory: selected,
                    selectedCustomCategory: selectedCustom?.name,
                    onSelect: (cat) => setState(() {
                      selected = cat;
                      selectedCustom = null;
                    }),
                    onSelectCustom: (c) => setState(() {
                      selected = ExpenseCategory.diger;
                      selectedCustom = c;
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Günlük standart kategoriler görünür olmalı
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('Mutfak'), findsOneWidget);
      expect(find.text('Ev Eşyası'), findsOneWidget);
      expect(find.text('Fatura'), findsOneWidget);
      expect(find.text('Ulaşım'), findsOneWidget);
      expect(find.text('Diğer'), findsOneWidget);

      // Ayda 1 kez ödenen Kira butonu günlük alanda olmamalıdır
      expect(find.text('Kira'), findsNothing);

      // Varsayılan özel kategoriler ve Özel Kategori butonu görünmelidir
      expect(find.text('Damacana Su'), findsOneWidget);
      expect(find.text('Özel Kategori'), findsOneWidget);

      // Özel kategori seçilebilmelidir (Yatay kaydırma ile görünür alana getirilir)
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Damacana Su'));
      await tester.pumpAndSettle();
      expect(selectedCustom?.name, equals('Damacana Su'));

      container.dispose();
    });
  });
}
