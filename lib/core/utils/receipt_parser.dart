import '../../data/models/expense.dart';

/// Fişten Ayrıştırılan Tekil Satır Kalemi Modeli (Line Item)
class ReceiptLineItem {
  final String id;
  final String title;
  final double price;
  final int quantity;
  final ExpenseCategory category;
  final bool isSelected;
  final double? lineTotal;

  const ReceiptLineItem({
    required this.id,
    required this.title,
    required this.price,
    this.quantity = 1,
    this.category = ExpenseCategory.market,
    this.isSelected = true,
    this.lineTotal,
  });

  double get totalPrice => lineTotal ?? (price * quantity);

  ReceiptLineItem copyWith({
    String? id,
    String? title,
    double? price,
    int? quantity,
    ExpenseCategory? category,
    bool? isSelected,
    double? lineTotal,
  }) {
    return ReceiptLineItem(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      isSelected: isSelected ?? this.isSelected,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'quantity': quantity,
        'category': category.name,
        'isSelected': isSelected,
        if (lineTotal != null) 'lineTotal': lineTotal,
      };

  factory ReceiptLineItem.fromJson(Map<String, dynamic> json) =>
      ReceiptLineItem(
        id: json['id'] as String,
        title: json['title'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int? ?? 1,
        category: ExpenseCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => ExpenseCategory.market,
        ),
        isSelected: json['isSelected'] as bool? ?? true,
        lineTotal: (json['lineTotal'] as num?)?.toDouble(),
      );
}

/// Fişten Ayrıştırılan Finansal Veri Modeli
class ParsedReceipt {
  final double? amount;
  final String? merchantName;
  final ExpenseCategory? suggestedCategory;
  final DateTime? date;
  final double confidenceScore;
  final List<ReceiptLineItem> lineItems;
  final bool lineItemsSavedDirectly;
  final String? selectedPayerId;

  const ParsedReceipt({
    this.amount,
    this.merchantName,
    this.suggestedCategory,
    this.date,
    this.confidenceScore = 0.0,
    this.lineItems = const [],
    this.lineItemsSavedDirectly = false,
    this.selectedPayerId,
  });

  bool get hasValidData => amount != null && amount! > 0;
  bool get hasLineItems => lineItems.isNotEmpty;

  // Geriye dönük uyumluluk (Önceki string listesini korur)
  List<String> get detectedItems => lineItems.map((e) => e.title).toList();

  double get totalLineItemsAmount =>
      lineItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get selectedLineItemsAmount => lineItems
      .where((i) => i.isSelected)
      .fold(0.0, (sum, item) => sum + item.totalPrice);

  int get selectedCount => lineItems.where((i) => i.isSelected).length;

  ParsedReceipt copyWith({
    double? amount,
    String? merchantName,
    ExpenseCategory? suggestedCategory,
    DateTime? date,
    double? confidenceScore,
    List<ReceiptLineItem>? lineItems,
    bool? lineItemsSavedDirectly,
    String? selectedPayerId,
  }) {
    return ParsedReceipt(
      amount: amount ?? this.amount,
      merchantName: merchantName ?? this.merchantName,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      date: date ?? this.date,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      lineItems: lineItems ?? this.lineItems,
      lineItemsSavedDirectly:
          lineItemsSavedDirectly ?? this.lineItemsSavedDirectly,
      selectedPayerId: selectedPayerId ?? this.selectedPayerId,
    );
  }
}

/// Akıllı Fiş ve Belge Ayrıştırma Motoru (Receipt Parser Engine)
///
/// Türkçe fiş formatlarını, KDV dökümlerini, perakende zincirlerini, faturaları
/// ve satır kalemlerini tek geçişte (O(N)) analiz eden saf matematiksel ve regex algoritması.
class ReceiptParser {
  ReceiptParser._();

  // Seviye 1: Birincil Toplam Tutar deseni (Örn: "TOPLAM *124,50", "GENEL TOPLAM: 85.00 TL", "ÖDENECEK: 481,00 TL")
  static final RegExp _primaryTotalPattern = RegExp(
    r'(?:^|[^\wçğıöşü])(?:GENEL\s*TOPLAM|TOPLAM|ÖDENECEK\s*TUTAR|ÖDENECEK|ODENECEK|KDV\s*DAH[İI]L\s*TOPLAM)\s*[:=\*]?\s*(?:TL|₺|TRY)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
    caseSensitive: false,
  );

  // Seviye 2: Ödeme Yöntemi Toplam Tutar deseni (Örn: "ÖDENEN: 224 TL", "KREDİ KARTI: 340 TL", "KDV DAHİL: 150 TL")
  static final RegExp _secondaryPaymentPattern = RegExp(
    r'(?:^|[^\wçğıöşü])(?:ÖDENEN|ODENEN|KREDI\s*KARTI|KREDİ\s*KARTI|KDV\s*DAH[İI]L)\s*[:=\*]?\s*(?:TL|₺|TRY)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
    caseSensitive: false,
  );

  // Seviye 3: Nakit veya genel tutar satırı deseni (Örn: "NAKİT: 150 TL", "TUTAR: 80 TL")
  static final RegExp _tertiaryCashPattern = RegExp(
    r'(?:^|[^\wçğıöşü])(?:NAK[İI]T|TUTAR)\s*[:=\*]?\s*(?:TL|₺|TRY)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
    caseSensitive: false,
  );

  // Tarih desenleri (Örn: 24.10.2026, 24/10/2026, 2026-10-24)
  static final RegExp _datePattern = RegExp(
    r'\b([0-3]?[0-9])[./-]([0-1]?[0-9])[./-](20[2-3][0-9])\b',
  );

  // Satır kalemi ondalıklı tutar deseni (Örn: "SÜT: 38.50 TL", "DETERJAN 98,00 *", "EKMEK 12,50 %01", "PEYNİR 65,50")
  static final RegExp _linePriceDecimalPattern = RegExp(
    r'[:=\*]?\s*(?:TL|₺|TRY)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})|[0-9]+[.,][0-9]{1,2})\s*(?:TL|₺|TRY)?\s*(?:[\*]|%[0-9]{1,2}|[A-Za-z])?\s*$',
    caseSensitive: false,
  );

  // Satır kalemi tamsayı tutar deseni (Örn: "EKMEK: 15 TL", "SU 10 TL", "KAHVE: 85", "SİMİT * 20", "EKMEK 15 *")
  static final RegExp _linePriceIntegerPattern = RegExp(
    r'(?:[:=\*]\s*(?:TL|₺|TRY)?\s*([0-9]{1,6})\s*(?:TL|₺|TRY)?|(?:\s+|^)([0-9]{1,6})\s*(?:TL|₺|TRY)|(?:\s+|^)([0-9]{1,6})\s*[\*]|(?:\s+|^)([0-9]{1,6})\s*%[0-9]{1,2})\s*$',
    caseSensitive: false,
  );

  // Satır kalemi miktar (quantity) desenleri
  // 1. Başlangıç miktar deseni (Örn: "2x FLAT WHITE", "3 ADET EKMEK", "1 AD.", "2 TANE")
  static final RegExp _prefixQuantityPattern = RegExp(
    r'^\s*([0-9]{1,2})\s*(?:x|X|\*|adet|ad\.?|tane)\s+',
    caseSensitive: false,
  );

  // 2. Bitiş miktar deseni (Örn: "FLAT WHITE 2x", "EKMEK 3 ADET", "KAHVE 2 AD.")
  static final RegExp _suffixQuantityPattern = RegExp(
    r'\s+([0-9]{1,2})\s*(?:x|X|\*|adet|ad\.?|tane)\s*$',
    caseSensitive: false,
  );

  // Satır kalemlerinden elenecek meta, vergi, adres, para üstü ve toplam satırları
  static final List<String> _skipLineKeywords = [
    'toplam',
    'kredi karti',
    'kredi kartı',
    'nakit',
    'nakıt',
    'ödenen',
    'odenen',
    'ödenecek',
    'odenecek',
    'kdv dahil',
    'kdv dahıl',
    'kdv haric',
    'kdv hariç',
    'kdv toplam',
    'kdv',
    'vergi',
    'tarih:',
    'tarih :',
    'saat:',
    'saat :',
    'fatura tarihi',
    'son ödeme',
    'son odeme',
    'fiş no',
    'fis no',
    'fişno',
    'fisno',
    'z no',
    'eku no',
    'tckn',
    'vkn',
    'mersis',
    'kasiyer',
    'teşekkür',
    'tesekkur',
    'afiyet olsun',
    'yine bekleriz',
    'iyi günler',
    'iyi gunler',
    'şube',
    'sube',
    'sözleşme',
    'sozlesme',
    't.a.ş.',
    'a.ş.',
    'ltd.',
    'şti.',
    // Adres ve İletişim Satırları Filtresi
    'cad.',
    'caddesi',
    'sok.',
    'sokak',
    'mah.',
    'mahallesi',
    'bulvar',
    'blv.',
    'no:',
    'kapı no',
    'kapi no',
    'apt.',
    'kat:',
    'daire:',
    'tel:',
    'telefon',
    'gsm',
    'fax',
    'web:',
    // Gürültü ve İade/İndirim Filtreleri
    'indirim',
    'ındırım',
    'iskonto',
    'ıskonto',
    'promosyon',
    'kupon',
    'iade',
    'para üstü',
    'para ustu',
    'banka kartı',
    'banka karti',
    'matrah',
    'yuvarlama',
    'ara toplam',
    'temassız',
    'temassiz',
    'bonus',
    'puan',
  ];

  // Kategori Anahtar Kelimeleri Haritası
  static final Map<ExpenseCategory, List<String>> _categoryKeywords = {
    ExpenseCategory.market: [
      'migros', 'bim', 'şok', 'sok', 'a101', 'carrefour', 'file', 'tarim kredi',
      'gida', 'süt', 'ekmek', 'peynir', 'market', 'bakkal', 'manav', 'kasap',
      'deterjan', 'yumusatici', 'domestos', 'fairy', 'temizlik', 'kagit havlu',
    ],
    ExpenseCategory.mutfak: [
      'restoran', 'restaurant', 'cafe', 'kafe', 'kahve', 'starbucks', 'espresso',
      'burger', 'pizza', 'döner', 'kebap', 'lokanta', 'pastane', 'tatli', 'yemek',
      'yemeksepeti', 'getir',
    ],
    ExpenseCategory.fatura: [
      'enerjisa', 'tedaş', 'iski', 'aski', 'igdaş', 'turkcell', 'vodafone',
      'turk telekom', 'superonline', 'elektrik', 'su', 'dogalgaz', 'internet', 'fatura',
    ],
    ExpenseCategory.kira: [
      'kira', 'aidat', 'apartman', 'site yonetimi', 'yonetim', 'depozito',
    ],
    ExpenseCategory.esya: [
      'mobilya', 'ikea', 'koctas', 'tekzen', 'ev esyasi', 'yatak', 'masa', 'sandalye',
    ],
    ExpenseCategory.ulasim: [
      'akbil', 'istanbulkart', 'metro', 'otobus', 'taksi', 'uber', 'marti', 'binbin',
      'benzin', 'mazot', 'shell', 'opet', 'bp', 'petrol',
    ],
    ExpenseCategory.diger: [
      'kirtasiye', 'fotokopi', 'eczane', 'saglik', 'ilac', 'sinema', 'biletix',
    ],
  };

  /// Ham OCR metnini analiz ederek yapısal finansal veriye ve satır kalemlerine dönüştürür
  static ParsedReceipt parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ParsedReceipt();
    }

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double? detectedAmount;
    String? merchant;
    DateTime? detectedDate;
    ExpenseCategory? suggestedCategory;
    double confidence = 0.0;

    // 1. İşletme Adı Tespiti (Fişin ilk 5 satırındaki en anlamlı başlık; mali bilgi başlıklarını atlar)
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i];
      if (_isValidMerchantCandidate(line)) {
        merchant = _cleanMerchantName(line);
        confidence += 0.25;
        break;
      }
    }

    // 2. Tutar Tespiti (Satır bazlı önceliklendirme)
    // Seviye 1: Açık genel toplam satırları ("TOPLAM", "GENEL TOPLAM", "ÖDENECEK TUTAR" - "ARA TOPLAM" hariç!)
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('ara toplam') || lower.contains('kdv toplam') || lower.contains('nakit')) {
        continue;
      }
      final match = _primaryTotalPattern.firstMatch(line);
      if (match != null) {
        final valStr = match.group(1);
        if (valStr != null) {
          final val = _normalizeAmount(valStr);
          if (val != null && val > 0) {
            detectedAmount = val;
          }
        }
      }
    }

    // Seviye 2: Eğer açık TOPLAM yoksa, ödeme satırları ("ÖDENEN", "KREDİ KARTI", "KDV DAHİL")
    if (detectedAmount == null) {
      for (final line in lines) {
        final lower = line.toLowerCase();
        if (lower.contains('ara toplam') || lower.contains('nakit')) continue;
        final match = _secondaryPaymentPattern.firstMatch(line);
        if (match != null) {
          final valStr = match.group(1);
          if (valStr != null) {
            final val = _normalizeAmount(valStr);
            if (val != null && val > 0) {
              detectedAmount = val;
            }
          }
        }
      }
    }

    // Seviye 3: Eğer hala yoksa, nakit veya tutar satırı
    if (detectedAmount == null) {
      for (final line in lines) {
        final match = _tertiaryCashPattern.firstMatch(line);
        if (match != null) {
          final valStr = match.group(1);
          if (valStr != null) {
            final val = _normalizeAmount(valStr);
            if (val != null && val > 0) {
              detectedAmount = val;
            }
          }
        }
      }
    }

    // 3. Tarih Tespiti
    final dateMatch = _datePattern.firstMatch(rawText);
    if (dateMatch != null) {
      try {
        final day = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final year = int.parse(dateMatch.group(3)!);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          detectedDate = DateTime(year, month, day);
          confidence += 0.15;
        }
      } catch (_) {
        // Geçersiz tarih tolere edilir
      }
    }

    // 4. Kategori Eşleştirmesi (Kelime frekans analizi)
    final lowerText = rawText.toLowerCase();
    int maxMatches = 0;
    for (final entry in _categoryKeywords.entries) {
      int currentMatches = 0;
      for (final kw in entry.value) {
        if (lowerText.contains(kw)) {
          currentMatches++;
        }
      }
      if (currentMatches > maxMatches) {
        maxMatches = currentMatches;
        suggestedCategory = entry.key;
      }
    }

    if (suggestedCategory != null) {
      confidence += 0.15;
    } else {
      suggestedCategory =
          ExpenseCategory.market; // Varsayılan en yaygın ev kategorisi
    }

    // 5. Satır Kalemlerinin Ayrıştırılması (Line Items Parsing Engine)
    final List<ReceiptLineItem> lineItems = [];
    int itemCounter = 0;

    for (final line in lines) {
      if (_shouldSkipLine(line, merchant)) continue;

      Match? priceMatch = _linePriceDecimalPattern.firstMatch(line);
      String? priceStr;
      if (priceMatch != null) {
        priceStr = priceMatch.group(1);
      } else {
        priceMatch = _linePriceIntegerPattern.firstMatch(line);
        if (priceMatch != null) {
          priceStr = priceMatch.group(1) ??
              priceMatch.group(2) ??
              priceMatch.group(3) ??
              priceMatch.group(4);
        }
      }

      if (priceMatch != null && priceStr != null) {
        final rawPrice = _normalizeAmount(priceStr);
        if (rawPrice == null || rawPrice <= 0 || rawPrice > 100000) continue;

        // Metin kısmını ayıkla (Fiyat deseni öncesi)
        String rawTitle = line.substring(0, priceMatch.start).trim();
        // İki nokta, yıldız, tire veya eşittir işaretlerini temizle
        rawTitle = rawTitle.replaceAll(RegExp(r'[:=\*\-_]+$'), '').trim();

        if (rawTitle.isEmpty || rawTitle.length < 2) continue;

        // Miktar (quantity) tespiti: Önce baştaki ("2x FLAT WHITE"), sonra sondaki ("EKMEK 2 ADET")
        int quantity = 1;
        final qMatchPrefix = _prefixQuantityPattern.firstMatch(rawTitle);
        if (qMatchPrefix != null) {
          final qVal = int.tryParse(qMatchPrefix.group(1) ?? '1');
          if (qVal != null && qVal > 0 && qVal < 100) {
            quantity = qVal;
            rawTitle = rawTitle.substring(qMatchPrefix.end).trim();
          }
        } else {
          final qMatchSuffix = _suffixQuantityPattern.firstMatch(rawTitle);
          if (qMatchSuffix != null) {
            final qVal = int.tryParse(qMatchSuffix.group(1) ?? '1');
            if (qVal != null && qVal > 0 && qVal < 100) {
              quantity = qVal;
              rawTitle = rawTitle.substring(0, qMatchSuffix.start).trim();
            }
          }
        }

        // KDV yüzdelerini başlıktan temizle (Örn: "DETERJAN %18" -> "DETERJAN")
        rawTitle = rawTitle.replaceAll(RegExp(r'%\s*[0-9]{1,2}'), '').trim();
        if (rawTitle.isEmpty) continue;

        final itemCat = _categorizeItem(rawTitle, suggestedCategory);
        // Fiş satırındaki tutar satırın toplam tutarıdır; birim fiyat = toplam / miktar
        final unitPrice = quantity > 1 ? (rawPrice / quantity) : rawPrice;

        lineItems.add(
          ReceiptLineItem(
            id: 'item_${itemCounter++}',
            title: rawTitle,
            price: double.parse(unitPrice.toStringAsFixed(2)),
            quantity: quantity,
            category: itemCat,
            isSelected: true,
            lineTotal: rawPrice,
          ),
        );
      }
    }

    // Matematiksel Sağlama ve Toplam Uzlaştırma
    if (lineItems.isNotEmpty) {
      final lineItemsSum =
          lineItems.fold(0.0, (sum, i) => sum + i.totalPrice);
      if (detectedAmount != null) {
        if ((lineItemsSum - detectedAmount).abs() <= 1.0) {
          confidence += 0.15;
        } else {
          confidence += 0.05;
        }
      } else {
        // Eğer açık bir "TOPLAM" satırı yoksa ama kalemler tespit edildiyse,
        // kalemlerin toplamı doğal fiş toplamıdır!
        detectedAmount = lineItemsSum;
        confidence += 0.35;
      }
    } else if (detectedAmount == null) {
      // Kalem yoksa ve regex bulamadıysa, metindeki en büyük mantıklı para formatını yakala
      final fallbackRegex = RegExp(
          r'\b([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})|[0-9]+[.,][0-9]{2})\b');
      final matches = fallbackRegex.allMatches(rawText);
      double maxFound = 0.0;
      for (final m in matches) {
        final val = _normalizeAmount(m.group(1)!);
        if (val != null && val > maxFound && val < 500000) {
          maxFound = val;
        }
      }
      if (maxFound > 0) {
        detectedAmount = maxFound;
        confidence += 0.20;
      }
    }

    if (detectedAmount != null && confidence < 0.45) {
      confidence += 0.45;
    }

    return ParsedReceipt(
      amount: detectedAmount,
      merchantName: merchant ?? 'Market / Mağaza',
      suggestedCategory: suggestedCategory,
      date: detectedDate ?? DateTime.now(),
      confidenceScore: confidence.clamp(0.0, 1.0),
      lineItems: lineItems,
    );
  }

  static bool _shouldSkipLine(String line, String? merchant) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) return true;

    // İşletme adı ile aynıysa atla
    if (merchant != null && lower.contains(merchant.toLowerCase())) {
      return true;
    }

    // Tarih veya tek başına sayı ise atla
    if (_isDateOrNumeric(line)) return true;

    // Fiş başlığı, alt bilgi veya toplam satırları
    for (final kw in _skipLineKeywords) {
      if (lower.startsWith(kw) || lower.contains(kw)) {
        return true;
      }
    }

    return false;
  }

  static ExpenseCategory _categorizeItem(
      String title, ExpenseCategory fallback) {
    final lower = title.toLowerCase();

    // 1. Faturalar ve Abonelikler
    if (lower.contains('elektrik') ||
        lower.contains('su') ||
        lower.contains('dogalgaz') ||
        lower.contains('doğalgaz') ||
        lower.contains('internet') ||
        lower.contains('fatura') ||
        lower.contains('tüketim') ||
        lower.contains('enerjisa') ||
        lower.contains('iski') ||
        lower.contains('igdaş') ||
        lower.contains('telekom') ||
        lower.contains('turkcell') ||
        lower.contains('vodafone')) {
      return ExpenseCategory.fatura;
    }

    // 2. Mutfak, Kafe & Restoran (Hazır Yiyecek & İçecekler)
    if (lower.contains('kahve') ||
        lower.contains('espresso') ||
        lower.contains('flat white') ||
        lower.contains('latte') ||
        lower.contains('cappuccino') ||
        lower.contains('çay') ||
        lower.contains('cay') ||
        lower.contains('cheesecake') ||
        lower.contains('san sebastian') ||
        lower.contains('pasta') ||
        lower.contains('tatli') ||
        lower.contains('tatlı') ||
        lower.contains('burger') ||
        lower.contains('pizza') ||
        lower.contains('döner') ||
        lower.contains('doner') ||
        lower.contains('kebap') ||
        lower.contains('sandviç') ||
        lower.contains('sandvic') ||
        lower.contains('tost') ||
        lower.contains('restoran') ||
        lower.contains('kafe') ||
        lower.contains('cafe')) {
      return ExpenseCategory.mutfak;
    }

    // 3. Market Temizlik & Ev Sarf Malzemeleri
    if (lower.contains('deterjan') ||
        lower.contains('domestos') ||
        lower.contains('fairy') ||
        lower.contains('temizlik') ||
        lower.contains('havlu') ||
        lower.contains('peçete') ||
        lower.contains('pecete') ||
        lower.contains('sabun') ||
        lower.contains('şampuan') ||
        lower.contains('sampuan') ||
        lower.contains('yumuşatıcı') ||
        lower.contains('yumusatici') ||
        lower.contains('çamaşır suyu') ||
        lower.contains('diş macunu') ||
        lower.contains('dis macunu') ||
        lower.contains('çöp torbası') ||
        lower.contains('cop torbasi')) {
      return ExpenseCategory.market;
    }

    // 4. Temel Gıda (Market alışverişinde süt, yumurta, ekmek vb.)
    if (lower.contains('süt') ||
        lower.contains('sut') ||
        lower.contains('yumurta') ||
        lower.contains('ekmek') ||
        lower.contains('peynir') ||
        lower.contains('yoğurt') ||
        lower.contains('yogurt') ||
        lower.contains('et') ||
        lower.contains('tavuk') ||
        lower.contains('kıyma') ||
        lower.contains('yağ') ||
        lower.contains('yag') ||
        lower.contains('un') ||
        lower.contains('şeker') ||
        lower.contains('seker') ||
        lower.contains('makarna') ||
        lower.contains('pirinç') ||
        lower.contains('pirinc') ||
        lower.contains('meyve') ||
        lower.contains('sebze') ||
        lower.contains('domates') ||
        lower.contains('patates') ||
        lower.contains('soğan') ||
        lower.contains('sogan') ||
        lower.contains('bisküvi') ||
        lower.contains('çikolata') ||
        lower.contains('su')) {
      return fallback == ExpenseCategory.mutfak
          ? ExpenseCategory.mutfak
          : ExpenseCategory.market;
    }

    // 5. Ulaşım
    if (lower.contains('akbil') ||
        lower.contains('istanbulkart') ||
        lower.contains('metro') ||
        lower.contains('otobüs') ||
        lower.contains('otobus') ||
        lower.contains('taksi') ||
        lower.contains('uber') ||
        lower.contains('benzin') ||
        lower.contains('mazot') ||
        lower.contains('yakıt') ||
        lower.contains('yakit') ||
        lower.contains('bilet')) {
      return ExpenseCategory.ulasim;
    }

    // 6. Ev Eşyası
    if (lower.contains('mobilya') ||
        lower.contains('masa') ||
        lower.contains('sandalye') ||
        lower.contains('yatak') ||
        lower.contains('tabak') ||
        lower.contains('bardak') ||
        lower.contains('tava') ||
        lower.contains('tencere') ||
        lower.contains('ampul') ||
        lower.contains('pil') ||
        lower.contains('koli bandı') ||
        lower.contains('bant')) {
      return ExpenseCategory.esya;
    }

    // 7. Kira / Aidat
    if (lower.contains('kira') ||
        lower.contains('aidat') ||
        lower.contains('depozito')) {
      return ExpenseCategory.kira;
    }

    return fallback;
  }

  static double? _normalizeAmount(String raw) {
    var clean = raw
        .replaceAll(' ', '')
        .replaceAll('TL', '')
        .replaceAll('₺', '')
        .replaceAll('TRY', '')
        .replaceAll('try', '');
    if (clean.contains(',') && clean.contains('.')) {
      // 1.250,50 -> 1250.50
      if (clean.indexOf('.') < clean.indexOf(',')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // 1,250.50 -> 1250.50
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      // 125,50 -> 125.50
      clean = clean.replaceAll(',', '.');
    }
    return double.tryParse(clean);
  }

  static bool _isDateOrNumeric(String s) {
    final clean = s.replaceAll(RegExp(r'[\s./:-]'), '');
    return double.tryParse(clean) != null || _datePattern.hasMatch(s);
  }

  static bool _isValidMerchantCandidate(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.length < 3) return false;
    if (_isDateOrNumeric(line)) return false;
    final nonMerchants = [
      'mali degeri yoktur',
      'mali değeri yoktur',
      'bilgi fişi',
      'bilgi fisi',
      'e-arşiv',
      'e-arsiv',
      'e-fatura',
      'hoşgeldiniz',
      'hosgeldiniz',
      'yeni nesil',
      'vergi no',
      'mersis',
      'tckn',
      'vkn',
      'fatura no',
      'fis no',
      'fiş no',
      'tarih',
      'saat',
    ];
    for (final nm in nonMerchants) {
      if (lower.contains(nm)) return false;
    }
    return true;
  }

  static String _cleanMerchantName(String s) {
    var clean = s.replaceAll(RegExp(r'[*=_\-#]'), '').trim();
    if (clean.length > 28) {
      clean = clean.substring(0, 28).trim();
    }
    return clean;
  }
}
