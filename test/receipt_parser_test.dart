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

    test('Migros fişindeki tüm satır kalemlerini doğru isim, tutar ve kategorilerle ayrıştırmalıdır', () {
      const receiptText = '''
MİGROS T.A.Ş.
KADIKÖY ŞUBESİ
TARİH: 26.10.2026
SÜT 1L: 38.50 TL
YUMURTA 15Lİ: 75.00 TL
EKMEK: 12.50 TL
DETERJAN: 98.00 TL
TOPLAM: 224.00 TL
KDV DAHİL
FİŞ NO: 0142
''';

      final result = ReceiptParser.parse(receiptText);
      expect(result.hasLineItems, isTrue);
      expect(result.lineItems.length, equals(4));

      final sut = result.lineItems.firstWhere((i) => i.title.contains('SÜT'));
      expect(sut.price, equals(38.50));
      expect(sut.quantity, equals(1));
      expect(sut.totalPrice, equals(38.50));
      expect(sut.category, equals(ExpenseCategory.market));

      final yumurta = result.lineItems.firstWhere((i) => i.title.contains('YUMURTA'));
      expect(yumurta.price, equals(75.00));
      expect(yumurta.totalPrice, equals(75.00));

      final ekmek = result.lineItems.firstWhere((i) => i.title.contains('EKMEK'));
      expect(ekmek.price, equals(12.50));

      final deterjan = result.lineItems.firstWhere((i) => i.title.contains('DETERJAN'));
      expect(deterjan.price, equals(98.00));
      expect(deterjan.category, equals(ExpenseCategory.market));

      expect(result.totalLineItemsAmount, equals(224.00));
      expect(result.selectedCount, equals(4));
      expect(result.selectedLineItemsAmount, equals(224.00));
    });

    test('Kafe fişindeki miktar (quantity 2x) ve birim fiyatları doğru ayrıştırmalıdır', () {
      const cafeText = '''
ESPRESSO LAB COFFEE
MODA SAHİL
TARİH: 25.10.2026 14:35
2x FLAT WHITE: 180.00 TL
1x SAN SEBASTIAN: 160.00 TL
KREDI KARTI TOPLAM: 340.00 TL
TEŞEKKÜR EDERİZ
''';

      final result = ReceiptParser.parse(cafeText);
      expect(result.hasLineItems, isTrue);
      expect(result.lineItems.length, equals(2));

      final flatWhite = result.lineItems.firstWhere((i) => i.title.contains('FLAT WHITE'));
      expect(flatWhite.quantity, equals(2));
      expect(flatWhite.price, equals(90.00)); // 180 / 2
      expect(flatWhite.totalPrice, equals(180.00));
      expect(flatWhite.category, equals(ExpenseCategory.mutfak));

      final cake = result.lineItems.firstWhere((i) => i.title.contains('SAN SEBASTIAN'));
      expect(cake.quantity, equals(1));
      expect(cake.price, equals(160.00));
      expect(cake.totalPrice, equals(160.00));
      expect(cake.category, equals(ExpenseCategory.mutfak));

      expect(result.totalLineItemsAmount, equals(340.00));
    });

    test('ReceiptLineItem serialization ve copyWith metotları doğru çalışmalıdır', () {
      const item = ReceiptLineItem(
        id: 'item-101',
        title: 'Organik Yumurta',
        price: 85.50,
        quantity: 2,
        category: ExpenseCategory.market,
        isSelected: true,
      );

      expect(item.totalPrice, equals(171.00));

      final json = item.toJson();
      expect(json['id'], equals('item-101'));
      expect(json['title'], equals('Organik Yumurta'));
      expect(json['price'], equals(85.50));
      expect(json['quantity'], equals(2));
      expect(json['category'], equals('market'));
      expect(json['isSelected'], isTrue);

      final deserialized = ReceiptLineItem.fromJson(json);
      expect(deserialized.id, equals(item.id));
      expect(deserialized.totalPrice, equals(171.00));

      final deselected = item.copyWith(isSelected: false);
      expect(deselected.isSelected, isFalse);
      expect(deselected.price, equals(85.50));
    });

    test('ParsedReceipt seçili kalem hesaplamaları ve filtreleri deterministik olmalıdır', () {
      final items = [
        const ReceiptLineItem(id: '1', title: 'Süt', price: 40.0, isSelected: true),
        const ReceiptLineItem(id: '2', title: 'Kahve', price: 120.0, isSelected: true),
        const ReceiptLineItem(id: '3', title: 'Dergi', price: 50.0, isSelected: false),
      ];

      final receipt = ParsedReceipt(
        amount: 210.0,
        merchantName: 'Bakkal',
        lineItems: items,
      );

      expect(receipt.hasLineItems, isTrue);
      expect(receipt.totalLineItemsAmount, equals(210.0));
      expect(receipt.selectedCount, equals(2));
      expect(receipt.selectedLineItemsAmount, equals(160.0));
      expect(receipt.detectedItems, containsAll(['Süt', 'Kahve', 'Dergi']));
    });

    test('Satır kalemi filtreleri fiş başlığı, dipnotu ve KDV satırlarını elemelidir', () {
      const noisyReceipt = '''
MİGROS T.A.Ş.
KADIKÖY RIHTIM CAD. NO:12
TARİH: 26.10.2026 SAAT: 15:30
FİŞ NO: 0841
KASİYER: CAN
SÜT 1L: 38.50 TL
%10 KDV: 3.50 TL
TOPLAM: 38.50 TL
TEŞEKKÜR EDERİZ YİNE BEKLERİZ
''';

      final result = ReceiptParser.parse(noisyReceipt);
      expect(result.lineItems.length, equals(1));
      expect(result.lineItems.first.title, contains('SÜT'));
      expect(result.lineItems.first.price, equals(38.50));
    });
  });
}
