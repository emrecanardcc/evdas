import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/services/budget_service.dart';
import 'package:evdas_mobile/data/models/burn_rate_analysis.dart';
import 'package:evdas_mobile/data/models/household_budget.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/burn_rate_card.dart';

void main() {
  group('BurnRateCard Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Dengeli tempoda BurnRateCard doğru metrikler ve rozet ile render edilmelidir',
        (tester) async {
      final mockBudget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 30000.0,
        updatedAt: DateTime.now(),
      );

      const mockAnalysis = BurnRateAnalysis(
        monthlyLimit: 30000.0,
        currentSpent: 6000.0,
        daysElapsed: 10,
        daysInMonth: 30,
        daysRemaining: 20,
        dailyVelocity: 600.0,
        projectedMonthEndSpend: 18000.0,
        projectedVariance: -12000.0,
        projectedRatio: 0.6,
        status: BurnRateStatus.onTrack,
        budgetDepletionDay: null,
        safeDailyRemainingBudget: 1200.0,
        smartRecommendation:
            'Harcama temponuz dengeli. Mevcut hızla ay sonunu bütçenin 12.000 TL altında kapatmanız öngörülüyor.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            budgetProvider.overrideWith(() => _MockBudgetNotifier(mockBudget)),
            burnRateAnalysisProvider.overrideWithValue(mockAnalysis),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: BurnRateCard()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Harcama Temposu & Projeksiyon'), findsOneWidget);
      expect(find.text('Dengeli Tempo'), findsOneWidget);
      expect(find.text('Günlük Hız'), findsOneWidget);
      expect(find.text('Ay Sonu Tahmini'), findsOneWidget);
      expect(find.textContaining('18.000'), findsWidgets);
      expect(find.textContaining('12.000 TL altında'), findsOneWidget);
    });

    testWidgets('Kritik aşım durumunda "Kritik Hız" rozeti ve detaylar açılabilmelidir',
        (tester) async {
      final mockBudget = HouseholdBudget(
        householdId: 'h-1',
        monthlyLimit: 20000.0,
        updatedAt: DateTime.now(),
      );

      const mockAnalysis = BurnRateAnalysis(
        monthlyLimit: 20000.0,
        currentSpent: 12000.0,
        daysElapsed: 10,
        daysInMonth: 30,
        daysRemaining: 20,
        dailyVelocity: 1200.0,
        projectedMonthEndSpend: 36000.0,
        projectedVariance: 16000.0,
        projectedRatio: 1.8,
        status: BurnRateStatus.critical,
        budgetDepletionDay: 16,
        safeDailyRemainingBudget: 400.0,
        smartRecommendation:
            'Yüksek aşım riski: Mevcut temponuzla bütçeniz ayın 16. gününde tükenecektir.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            budgetProvider.overrideWith(() => _MockBudgetNotifier(mockBudget)),
            burnRateAnalysisProvider.overrideWithValue(mockAnalysis),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: BurnRateCard()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kritik Hız'), findsOneWidget);
      expect(find.textContaining('16. gününde tükenecektir'), findsOneWidget);

      // Detayları aç
      final expandTrigger = find.text('Projeksiyon Parametrelerini İncele');
      expect(expandTrigger, findsOneWidget);

      await tester.tap(expandTrigger);
      await tester.pumpAndSettle();

      expect(find.text('Projeksiyon Detaylarını Gizle'), findsOneWidget);
      expect(find.text('Geçen Gün / Toplam Gün'), findsOneWidget);
      expect(find.text('10 gün / 30 gün'), findsOneWidget);
      expect(find.text('Kalan Gün Sayısı'), findsOneWidget);
      expect(find.text('20 gün'), findsOneWidget);
      expect(find.text('Öngörülen Bütçe Tükenme Günü'), findsOneWidget);
      expect(find.text('Ayın 16. Günü'), findsOneWidget);
    });
  });
}

class _MockBudgetNotifier extends BudgetNotifier {
  final HouseholdBudget? _initial;
  _MockBudgetNotifier(this._initial);

  @override
  HouseholdBudget? build() => _initial;
}
