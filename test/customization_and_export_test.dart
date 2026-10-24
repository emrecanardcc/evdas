import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/core/theme/customization_models.dart';
import 'package:evdas_mobile/core/utils/currency_formatter.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/presentation/widgets/animated_rolling_number.dart';

void main() {
  group('Customization Models & CurrencyFormatter Tests', () {
    test('CurrencyFormatter sembol ve yerleşim kurallarını dinamik uygulamalıdır', () {
      // 1. Standart sonra yerleşim: "100 ₺"
      CurrencyFormatter.updateConfig(
        symbol: '₺',
        placement: CurrencyPlacement.after,
        decimalRule: DecimalRule.clean,
        privacyMasked: false,
      );
      expect(CurrencyFormatter.formatClean(100.0), '100 ₺');
      expect(CurrencyFormatter.formatClean(100.50), '100,50 ₺');

      // 2. Önde yerleşim ve Dolar: "$ 100"
      CurrencyFormatter.updateConfig(
        symbol: r'$',
        placement: CurrencyPlacement.before,
      );
      expect(CurrencyFormatter.formatClean(100.0), r'$ 100');
      expect(CurrencyFormatter.formatClean(100.50), r'$ 100,50');

      // 3. Gizli bakiye maskeleme modu
      CurrencyFormatter.updateConfig(privacyMasked: true);
      expect(CurrencyFormatter.formatClean(100.0, checkPrivacy: true), r'$ ••••');

      // 4. Kuruşsuz yuvarlak kuralı
      CurrencyFormatter.updateConfig(
        privacyMasked: false,
        symbol: '€',
        placement: CurrencyPlacement.after,
        decimalRule: DecimalRule.none,
      );
      expect(CurrencyFormatter.formatClean(123.75), '124 €');
    });

    test('Expense modeli splitMemberWeights alanını JSON ile hatasız serileştirmelidir', () {
      final expense = Expense(
        id: 'test-exp',
        householdId: 'h-1',
        title: 'Özel Bölüşüm Test',
        amount: 450.0,
        paidByMemberId: 'm-1',
        splitMemberWeights: {
          'm-1': 2.0,
          'm-2': 1.0,
        },
      );

      final json = expense.toJson();
      expect(json['split_member_weights'], isNotNull);
      expect(json['split_member_weights']['m-1'], 2.0);
      expect(json['split_member_weights']['m-2'], 1.0);

      final fromJson = Expense.fromJson(json);
      expect(fromJson.splitMemberWeights, isNotNull);
      expect(fromJson.splitMemberWeights!['m-1'], 2.0);
      expect(fromJson.splitMemberWeights!['m-2'], 1.0);
    });

    test('Customization enums displayName ve label uyumluluğu doğrulanmalıdır', () {
      expect(AppThemeType.light.displayName, AppThemeType.light.label);
      expect(AppThemeType.amoledDark.displayName, 'AMOLED Saf Siyah');
      expect(AccentColorOption.warmCoral.displayName, 'Warm Coral');
      expect(NumpadLayoutType.phone.displayName, NumpadLayoutType.phone.label);
      expect(CurrencySymbol.tryLira.displayName, 'Türk Lirası (₺)');
      expect(CurrencyPlacement.after.displayName, 'Sonda (100 ₺)');
      expect(DecimalRule.clean.displayName, 'Akıllı (Varsa kuruş, yoksa tam)');
      expect(HapticLevel.strong.displayName, 'Güçlü');
    });

    testWidgets('AnimatedRollingNumber gizli bakiye modunda sembol yerleşimine uymalıdır', (tester) async {
      // 1. Sonda yerleşim (₺) -> "•••• ₺"
      CurrencyFormatter.updateConfig(symbol: '₺', placement: CurrencyPlacement.after);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedRollingNumber(value: 250.0, isMasked: true),
          ),
        ),
      );
      expect(find.text('•••• ₺'), findsOneWidget);

      // 2. Önde yerleşim ($) -> "$ ••••"
      CurrencyFormatter.updateConfig(symbol: r'$', placement: CurrencyPlacement.before);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedRollingNumber(value: 250.0, isMasked: true),
          ),
        ),
      );
      expect(find.text(r'$ ••••'), findsOneWidget);
    });
  });
}
