import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/financial_insights.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/financial_insights_card.dart';

void main() {
  group('FinancialInsightsCard Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Finansal sağlık kartı ve tavsiyeler başarıyla render edilmelidir', (tester) async {
      final mockInsights = HouseholdFinancialInsights(
        healthScore: FinancialHealthScore(
          score: 85,
          title: 'Mükemmel Uyum',
          description: 'Bütçe kontrol altında.',
          color: const Color(0xFF10B981),
        ),
        totalJointThisMonth: 4500.0,
        totalJointLastMonth: 5000.0,
        overallDifference: -500.0,
        overallPercentageChange: -10.0,
        categoryTrends: [
          CategoryTrend(
            category: ExpenseCategory.market,
            thisMonthAmount: 2500.0,
            lastMonthAmount: 3000.0,
            difference: -500.0,
            percentageChange: -16.6,
          ),
        ],
        advices: [
          FinancialAdvice(
            id: 'overall_savings',
            title: 'Geçen Aya Göre Tasarruf',
            description: 'Ortak harcamalarınız geçen aya göre %10 azaldı.',
            type: AdviceType.savings,
            priority: 1,
            potentialSavings: 500.0,
          ),
          FinancialAdvice(
            id: 'category_dominance',
            title: 'Market Gider Yoğunluğu',
            description: 'Bu ay bütçenin büyük kısmı markete harcandı.',
            type: AdviceType.savings,
            priority: 2,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            financialInsightsProvider.overrideWithValue(mockInsights),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: FinancialInsightsCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Başlık ve Skor rozetini doğrula
      expect(find.text('Finansal Uyum & Tasarruf'), findsOneWidget);
      expect(find.text('85/100 • Mükemmel Uyum'), findsOneWidget);

      // Geçen aya göre genel tasarruf rozetini doğrula
      expect(find.textContaining('Geçen aya göre %10.0 tasarruf sağlandı'), findsOneWidget);

      // Kategori çipini doğrula
      expect(find.textContaining('Market -%16.6'), findsOneWidget);

      // Tavsiyeleri doğrula
      expect(find.text('Geçen Aya Göre Tasarruf'), findsOneWidget);
      expect(find.text('Market Gider Yoğunluğu'), findsOneWidget);
    });

    testWidgets('Ücretsiz planda 2\'den fazla tavsiye varsa Evdaş Plus açma rozeti gösterilmelidir', (tester) async {
      final mockInsights = HouseholdFinancialInsights(
        healthScore: FinancialHealthScore(
          score: 72,
          title: 'Dengeli & Sağlıklı',
          description: 'Harcamalar dengeli.',
          color: const Color(0xFF0284C7),
        ),
        totalJointThisMonth: 6000.0,
        totalJointLastMonth: 5500.0,
        overallDifference: 500.0,
        overallPercentageChange: 9.1,
        categoryTrends: [],
        advices: [
          FinancialAdvice(
            id: 'a1',
            title: 'Tavsiye 1',
            description: 'Açıklama 1',
            type: AdviceType.savings,
            priority: 1,
          ),
          FinancialAdvice(
            id: 'a2',
            title: 'Tavsiye 2',
            description: 'Açıklama 2',
            type: AdviceType.trend,
            priority: 2,
          ),
          FinancialAdvice(
            id: 'a3',
            title: 'Tavsiye 3 (Pro)',
            description: 'Açıklama 3',
            type: AdviceType.balance,
            priority: 3,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            financialInsightsProvider.overrideWithValue(mockInsights),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: FinancialInsightsCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 3. tavsiye yerine Pro açma rozeti görülmeli
      expect(find.text('Tavsiye 1'), findsOneWidget);
      expect(find.text('Tavsiye 2'), findsOneWidget);
      expect(find.text('Tavsiye 3 (Pro)'), findsNothing);
      expect(find.textContaining('Evdaş Plus ile 1 ek tasarruf tavsiyesini aç'), findsOneWidget);

      // Rozete tıklandığında paywall açılmalı
      await tester.tap(find.textContaining('Evdaş Plus ile 1 ek tasarruf tavsiyesini aç'));
      await tester.pumpAndSettle();

      // Paywall içeriğini doğrula
      expect(find.text('EVDAS PLUS'), findsOneWidget);
      expect(find.textContaining('Yapay Zeka Destekli Akıllı Tasarruf Analizi'), findsOneWidget);
    });
  });
}
