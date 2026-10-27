import 'package:flutter_test/flutter_test.dart';
import 'package:evdas_mobile/core/utils/receipt_parser.dart';
import 'package:evdas_mobile/data/models/expense.dart';

void main() {
  group('ReceiptParser Engine Unit Tests', () {
    test('Boş veya geçersiz metinlerde güvenle varsayılan nesne döndürmelidir', () {
      final empty = ReceiptParser.parse('');
      expect(empty.hasValidData, isFalse);
      expect(empty.amount, isNull);

      final whitespace = ReceiptParser.parse('   \n\n  ');
      expect(whitespace.hasValidData, isFalse);
    });

    test('Migros Market fişini doğru ayrıştırmalıdır (Tutar, Kategori, Tarih)', () {
      const receiptText = '''
MİGROS T.A.Ş.
KADIKÖY RIHTIM ŞUBESİ
TARİH: 26.10.2026 18:42
FİŞ NO: 0042
SÜT 1L: 38.50 TL
YUMURTA 15Lİ: 75.00 TL
EKMEK: 12.50 TL
DETERJAN: 98.00 TL
KDV TOPLAM: 35.00 TL
TOPLAM: 224.00 TL
ÖDENEN: 224.00 TL
''';

      final result = ReceiptParser.parse(receiptText);
      expect(result.hasValidData, isTrue);
      expect(result.amount, equals(224.00));
      expect(result.merchantName, contains('MİGROS'));
      expect(result.suggestedCategory, equals(ExpenseCategory.market));
      expect(result.date?.year, equals(2026));
      expect(result.date?.month, equals(10));
      expect(result.date?.day, equals(26));
      expect(result.confidenceScore, greaterThan(0.7));
    });

    test('BİM / ŞOK yıldızlı ve virgüllü formatları çözümlemelidir (*145,50 TL)', () {
      const receiptText = '''
BİM BİRLEŞİK MAĞAZALAR A.Ş.
ÜSKÜDAR ŞUBESİ
TARİH: 15.09.2026
PEYNİR: 65,50
ÇAY: 80,00
TOPLAM *145,50 TL
KREDI KARTI
''';

      final result = ReceiptParser.parse(receiptText);
      expect(result.hasValidData, isTrue);
      expect(result.amount, equals(145.50));
      expect(result.merchantName, contains('BİM'));
      expect(result.suggestedCategory, equals(ExpenseCategory.market));
    });

    test('Enerjisa Elektrik faturasını doğru kategori (fatura) ve tutarla ayrıştırmalıdır', () {
      const billText = '''
ENERJİSA İSTANBUL ANADOLU YAKASI
ELEKTRİK PERAKENDE SATIŞ A.Ş.
SÖZLEŞME HESAP NO: 100234567
FATURA TARİHİ: 22.10.2026
TÜKETİM: 412.30 TL
KDV: 68.70 TL
ÖDENECEK TUTAR: 481.00 TL
''';

      final result = ReceiptParser.parse(billText);
      expect(result.hasValidData, isTrue);
      expect(result.amount, equals(481.00));
      expect(result.suggestedCategory, equals(ExpenseCategory.fatura));
      expect(result.merchantName, contains('ENERJİSA'));
    });

    test('Kafe / Restoran fişini (yemek kategorisi) doğru tespit etmelidir', () {
      const cafeText = '''
ESPRESSO LAB COFFEE ROASTERS
TARİH: 24.10.2026
2x FLAT WHITE: 180.00 TL
1x SAN SEBASTIAN CHEESECAKE: 160.00 TL
KREDI KARTI: 340.00 TL
AFİYET OLSUN
''';

      final result = ReceiptParser.parse(cafeText);
      expect(result.hasValidData, isTrue);
      expect(result.amount, equals(340.00));
      expect(result.suggestedCategory, equals(ExpenseCategory.mutfak));
      expect(result.merchantName, contains('ESPRESSO LAB'));
    });

    test('Binlik ayracı olan büyük tutarları (1.450,75 TL) doğru hesaplamalıdır', () {
      const bigReceipt = '''
VATAN BİLGİSAYAR
TARİH: 10.10.2026
LOGITECH MOUSE
TOPLAM: 1.450,75 TL
KREDI KARTI
''';

      final result = ReceiptParser.parse(bigReceipt);
      expect(result.hasValidData, isTrue);
      expect(result.amount, equals(1450.75));
    });
  });
}
