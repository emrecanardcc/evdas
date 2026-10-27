import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/financial_insights.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/domain/reporting_engine.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/providers/customization_provider.dart';
import 'package:evdas_mobile/presentation/widgets/financial_report_card_modal.dart';

void main() {
  group('FinancialReportCardModal Widget Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Finansal karne modalı doğru veriler ve metriklerle render edilmelidir', (tester) async {
      final member1 = HouseholdMember(id: 'm-1', householdId: 'h-1', displayName: 'Ahmet');
      final member2 = HouseholdMember(id: 'm-2', householdId: 'h-1', displayName: 'Mehmet');

      final mockHouse = Partnership(
        id: 'h-1',
        name: 'Kadıköy Evi',
        type: PartnershipType.home,
        inviteCode: 'EV-1234',
        members: [member1, member2],
      );

      final mockInsights = HouseholdFinancialInsights(
        healthScore: FinancialHealthScore(
          score: 88,
          title: 'Mükemmel Uyum',
          description: 'Harcamalar bütçe dahilinde.',
          color: const Color(0xFF10B981),
        ),
        totalJointThisMonth: 6000.0,
        totalJointLastMonth: 7000.0,
        overallDifference: -1000.0,
        overallPercentageChange: -14.2,
        categoryTrends: [],
        advices: [],
      );

      final mockReport = PartnershipReport(
        timeRange: ReportTimeRange.thisMonth,
        totalJointExpenses: 6000.0,
        totalPersonalDebts: 0.0,
        grandTotal: 6000.0,
        perMemberAverage: 3000.0,
        categorySpends: [
          CategorySpend(
            category: ExpenseCategory.market,
            amount: 3600.0,
            percentage: 60.0,
            count: 4,
          ),
        ],
        memberSpends: [
          MemberSpend(
            member: member1,
            amount: 4000.0,
            percentage: 66.6,
          ),
          MemberSpend(
            member: member2,
            amount: 2000.0,
            percentage: 33.3,
          ),
        ],
        totalTransactionCount: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            householdProvider.overrideWith(() => _MockHouseholdNotifier(mockHouse)),
            financialInsightsProvider.overrideWithValue(mockInsights),
            partnershipReportProvider.overrideWithValue(mockReport),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FinancialReportCardModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Başlık ve ortaklık adı
      expect(find.text('Ortaklık Finansal Karnesi'), findsOneWidget);
      expect(find.textContaining('Kadıköy Evi'), findsOneWidget);

      // Sağlık Skoru
      expect(find.text('88/100 • Mükemmel Uyum'), findsOneWidget);

      // Metrikler
      expect(find.text('Toplam Ortak Gider'), findsOneWidget);
      expect(find.text('Kişi Başı Pay'), findsOneWidget);
      expect(find.text('Aylık Trend'), findsOneWidget);
      expect(find.text('-%14.2 Tasarruf'), findsOneWidget);

      // Lider kategori ve en çok harcayan
      expect(find.textContaining('Market (%60)'), findsOneWidget);
      expect(find.textContaining('Ahmet (%67 pay)'), findsOneWidget);

      // Aksiyon butonları
      expect(find.text('Karneyi Paylaş (WhatsApp / Mesaj)'), findsOneWidget);
      expect(find.text('Detaylı CSV / Excel Tablosu Al'), findsOneWidget);
    });
  });
}

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership _house;
  _MockHouseholdNotifier(this._house);

  @override
  Partnership? build() => _house;
}
