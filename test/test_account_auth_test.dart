import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/screens/auth_screen.dart';
import 'package:evdas_mobile/presentation/screens/home_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('Test Account Auth Tests', () {
    late ExpenseRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = await ExpenseRepository.init();
    });

    testWidgets('Test hesabı doldur butonu e-posta ve şifreyi otomatik girmelidir', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fillButton = find.text('Test Hesabı Bilgilerini Doldur');
      expect(fillButton, findsOneWidget);

      await tester.tap(fillButton);
      await tester.pumpAndSettle();

      expect(find.text('test@evdas.app'), findsOneWidget);
    });

    testWidgets('Test hesabı ile giriş yapıldığında HomeScreen açılmalı ve test ortaklığı kurulmalıdır', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Butona tıkla ve formu doldur
      await tester.tap(find.text('Test Hesabı Bilgilerini Doldur'));
      await tester.pumpAndSettle();

      // Giriş Yap butonuna bas
      final loginBtn = find.widgetWithText(ElevatedButton, 'Giriş Yap');
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // HomeScreen açılmış olmalı
      expect(find.byType(HomeScreen), findsOneWidget);

      // Kadıköy Evi (Test) ortaklığı repo üzerinden açılmış olmalı
      final activeHouse = repo.getActiveHousehold();
      expect(activeHouse, isNotNull);
      expect(activeHouse!.name, equals('Kadıköy Evi (Test)'));
      expect(activeHouse.members.length, equals(3));
    });
  });
}
