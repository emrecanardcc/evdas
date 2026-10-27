import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/reminder_service.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/notification_center_modal.dart';

void main() {
  group('NotificationCenterModal Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Boş bildirim merkezi: "Her Şey Güncel" mesajı gösterilmelidir',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reminderProvider.overrideWith(() => _MockEmptyReminderNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationCenterModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bildirim Merkezi'), findsOneWidget);
      expect(find.text('Her Şey Güncel'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    testWidgets('Aktif hatırlatıcılar listelenmeli ve aksiyon butonu gösterilmelidir',
        (tester) async {
      int navigatedTab = -1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reminderProvider.overrideWith(() => _MockActiveReminderNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NotificationCenterModal(
                onNavigateTab: (tab) => navigatedTab = tab,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aylık Hesaplaşma Vakti'), findsOneWidget);
      expect(find.text('Hesaplaşmaya Git'), findsOneWidget);

      // Eylem butonuna dokunulduğunda tab yönlendirmesi tetiklenmeli
      await tester.tap(find.text('Hesaplaşmaya Git'));
      await tester.pumpAndSettle();

      expect(navigatedTab, equals(3));
    });
  });
}

class _MockEmptyReminderNotifier extends ReminderNotifier {
  @override
  ReminderState build() {
    return const ReminderState(
      items: [],
      dismissedIds: {},
      readIds: {},
    );
  }
}

class _MockActiveReminderNotifier extends ReminderNotifier {
  @override
  ReminderState build() {
    return ReminderState(
      items: [
        ReminderItem(
          id: 'mock-1',
          type: ReminderType.settlementDay,
          title: 'Aylık Hesaplaşma Vakti',
          message: 'Bugün hesaplaşma günü.',
          timestamp: DateTime.now(),
          actionRoute: 'settlement',
          actionLabel: 'Hesaplaşmaya Git',
        ),
      ],
      dismissedIds: const {},
      readIds: const {},
    );
  }
}
