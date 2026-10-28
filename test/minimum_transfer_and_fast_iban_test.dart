import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evdas_mobile/core/utils/fast_transfer_helper.dart';
import 'package:evdas_mobile/data/models/expense.dart';
import 'package:evdas_mobile/data/models/household_member.dart';
import 'package:evdas_mobile/data/models/partnership.dart';
import 'package:evdas_mobile/data/models/payment_request.dart';
import 'package:evdas_mobile/data/repositories/expense_repository.dart';
import 'package:evdas_mobile/domain/debt_engine.dart';
import 'package:evdas_mobile/presentation/providers/app_providers.dart';
import 'package:evdas_mobile/presentation/screens/settlement_screen.dart';

class _MockHouseholdNotifier extends HouseholdNotifier {
  final Partnership? _initial;
  _MockHouseholdNotifier(this._initial);

  @override
  Partnership? build() => _initial;
}

class _MockCurrentMemberNotifier extends CurrentMemberNotifier {
  final HouseholdMember? _initial;
  _MockCurrentMemberNotifier(this._initial);

  @override
  HouseholdMember? build() => _initial;
}

class _MockExpensesNotifier extends ExpensesNotifier {
  final List<Expense> _initial;
  _MockExpensesNotifier(this._initial);

  @override
  List<Expense> build() => _initial;
}

class _MockPaymentsNotifier extends PaymentRequestsNotifier {
  final List<PaymentRequest> _initial;
  _MockPaymentsNotifier(this._initial);

  @override
  List<PaymentRequest> build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FastTransferHelper Birim Testleri', () {
    test('cleanIban bosluklari silmeli ve buyuk harfe cevirmelidir', () {
      expect(
        FastTransferHelper.cleanIban(' tr12 3456  7890 1234 5678 9012 34 '),
        'TR123456789012345678901234',
      );
    });

    test('formatIban dort haneli bloklar halinde bicimlendirmelidir', () {
      final raw = 'TR123456789012345678901234';
      final formatted = FastTransferHelper.formatIban(raw);
      expect(formatted, 'TR12 3456 7890 1234 5678 9012 34');
    });

    test('buildRemittanceDescription standart dekont aciklamasi uretmelidir', () {
      final desc = FastTransferHelper.buildRemittanceDescription(
        fromName: 'Ahmet',
        toName: 'Mehmet',
        amount: 350.50,
      );
      expect(desc, 'Evdas Odesme - Ahmet -> Mehmet (350.50 TL)');
    });

    test('buildFullFastSummary banka uygulamasina yapistirilacak sablonu eksiksiz olusturmalidir', () {
      final summary = FastTransferHelper.buildFullFastSummary(
        recipientName: 'Zeynep Kaya',
        iban: 'TR99 0001 0002 0003 0004 0005 06',
        amount: 720.00,
        fromName: 'Can Tekin',
      );
      expect(summary.contains('Alıcı: Zeynep Kaya'), isTrue);
      expect(summary.contains('IBAN: TR990001000200030004000506'), isTrue);
      expect(summary.contains('Tutar: 720.00 TL'), isTrue);
      expect(summary.contains('Açıklama: Evdas Odesme - Can Tekin'), isTrue);
    });

    test('buildIbanRequestMessage nazik ve bilgilendirici mesaj uretmelidir', () {
      final msg = FastTransferHelper.buildIbanRequestMessage(
        debtorName: 'Burak',
        creditorName: 'Selin',
        amount: 450.25,
      );
      expect(msg.contains('Selam Selin'), isTrue);
      expect(msg.contains('450.25 TL'), isTrue);
      expect(msg.contains('FAST ile göndermek istiyorum'), isTrue);
    });
  });

  group('DebtEngine Minimum Transfer Graf Optimizasyonu Testleri', () {
    final members = [
      HouseholdMember(id: 'u1', householdId: 'h1', displayName: 'Ahmet'),
      HouseholdMember(id: 'u2', householdId: 'h1', displayName: 'Mehmet'),
      HouseholdMember(id: 'u3', householdId: 'h1', displayName: 'Ayse'),
    ];

    test('Birebir esit borclu ve alacakliyi Faz 1 tam eslesmeyle tek adimda cozmelidir', () {
      // Ahmet 300 TL odedi (ortak harcama, kisi basi 100 TL)
      // Net bakiye: Ahmet: +200, Mehmet: -100, Ayse: -100
      final expenses = [
        Expense(
          id: 'e1',
          title: 'Market',
          amount: 300.0,
          category: ExpenseCategory.market,
          paidByMemberId: 'u1',
          householdId: 'h1',
          createdAt: DateTime.now(),
        ),
      ];

      final result = DebtEngine.calculate(
        expenses: expenses,
        members: members,
      );

      expect(result.settlements.length, 2);
      expect(result.totalTransfersOptimized, 2);
      expect(result.totalSettlementVolume, 200.0);
      expect(result.transfersSaved, greaterThanOrEqualTo(0));
    });

    test('Karmasik borc dongusunde minimum transfer grafi islemleri normallestirmelidir', () {
      // 4 kisilik ortaklik: u1, u2, u3, u4
      final fourMembers = [
        ...members,
        HouseholdMember(id: 'u4', householdId: 'h1', displayName: 'Fatma'),
      ];

      // u1 400 TL odedi (kisi basi 100) -> u1 net +300
      // u2 200 TL odedi (kisi basi 50) -> u2 net +150
      // u3 ve u4 borclu
      final expenses = [
        Expense(
          id: 'e1',
          title: 'Mutfak',
          amount: 400.0,
          category: ExpenseCategory.market,
          paidByMemberId: 'u1',
          householdId: 'h1',
          createdAt: DateTime.now(),
        ),
        Expense(
          id: 'e2',
          title: 'Internet',
          amount: 200.0,
          category: ExpenseCategory.fatura,
          paidByMemberId: 'u2',
          householdId: 'h1',
          createdAt: DateTime.now(),
        ),
      ];

      final result = DebtEngine.calculate(
        expenses: expenses,
        members: fourMembers,
      );

      // Klasik ikili borclanma yerine minimum transferle cozum
      expect(result.totalTransfersOptimized, lessThanOrEqualTo(4));
      expect(result.transfersSaved, greaterThanOrEqualTo(0));
      expect(result.totalSettlementVolume, greaterThan(0));
    });
  });

  group('SettlementScreen Widget & FAST Entegrasyon Testleri', () {
    late ExpenseRepository repo;
    late Partnership mockHouse;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = ExpenseRepository(prefs);

      mockHouse = Partnership(
        id: 'h1',
        name: 'Kadikoy Evi (Test)',
        inviteCode: 'TEST12',
        settlementDay: 15,
        members: [
          HouseholdMember(
            id: 'u1',
            householdId: 'h1',
            displayName: 'Can Tekin',
            iban: 'TR112233445566778899001122',
          ),
          HouseholdMember(
            id: 'u2',
            householdId: 'h1',
            displayName: 'Ece Acar',
            iban: 'TR998877665544332211009988',
          ),
          HouseholdMember(
            id: 'u3',
            householdId: 'h1',
            displayName: 'Murat Oz',
            iban: null, // IBAN henuz girilmemis
          ),
        ],
      );
    });

    testWidgets('SettlementScreen minimum transfer karti ve IBAN butonlarini gostermelidir',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Ece 300 TL ortak harcama yapti -> Can ve Murat borclu
      final expenses = [
        Expense(
          id: 'e1',
          title: 'Ortak Fatura',
          amount: 300.0,
          category: ExpenseCategory.fatura,
          paidByMemberId: 'u2', // Ece odedi
          householdId: 'h1',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
            householdProvider.overrideWith(() => _MockHouseholdNotifier(mockHouse)),
            currentMemberProvider.overrideWith(
                () => _MockCurrentMemberNotifier(mockHouse.members[0])), // Can Tekin
            expensesProvider.overrideWith(() => _MockExpensesNotifier(expenses)),
            paymentRequestsProvider.overrideWith(() => _MockPaymentsNotifier([])),
          ],
          child: const MaterialApp(
            home: SettlementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Minimum transfer optimizasyon bilgisi ekranda gorunmeli
      expect(find.text('Minimum Transfer Optimizasyonu'), findsOneWidget);

      // Oturum acan Can Tekin'in kendi FAST IBAN karti ekranda gorunmeli
      expect(find.text('Kayıtlı FAST IBAN Numaranız'), findsOneWidget);
      expect(find.textContaining('TR11 2233 4455'), findsOneWidget);

      // Alacakli Ece'nin IBAN'i ve FAST kopyalama butonlari gorunmeli
      expect(find.text('FAST Transfer'), findsWidgets);
      expect(find.text('IBAN Kopyala'), findsWidgets);
      expect(find.text('FAST Bilgisini Kopyala'), findsWidgets);
      expect(find.text('Açıklama'), findsWidgets);
    });

    testWidgets('IBAN tanimlanmamis alacakli icin IBAN Iste butonu gorunmelidir',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Murat 300 TL ortak harcama yapti, Murat'in IBAN'i yok! Can borclu.
      final expenses = [
        Expense(
          id: 'e2',
          title: 'Kira',
          amount: 300.0,
          category: ExpenseCategory.kira,
          paidByMemberId: 'u3', // Murat odedi (iban null)
          householdId: 'h1',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
            householdProvider.overrideWith(() => _MockHouseholdNotifier(mockHouse)),
            currentMemberProvider.overrideWith(
                () => _MockCurrentMemberNotifier(mockHouse.members[0])), // Can
            expensesProvider.overrideWith(() => _MockExpensesNotifier(expenses)),
            paymentRequestsProvider.overrideWith(() => _MockPaymentsNotifier([])),
          ],
          child: const MaterialApp(
            home: SettlementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Murat'in IBAN'i olmadigi uyarisi ve IBAN Iste butonu gorunmeli
      expect(find.textContaining('henüz kayıtlı değil'), findsWidgets);
      expect(find.text('IBAN İste'), findsWidgets);
    });
  });
}
