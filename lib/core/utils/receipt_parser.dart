import '../../data/models/expense.dart';

/// Fişten Ayrıştırılan Finansal Veri Modeli
class ParsedReceipt {
  final double? amount;
  final String? merchantName;
  final ExpenseCategory? suggestedCategory;
  final DateTime? date;
  final double confidenceScore;
  final List<String> detectedItems;

  const ParsedReceipt({
    this.amount,
    this.merchantName,
    this.suggestedCategory,
    this.date,
    this.confidenceScore = 0.0,
    this.detectedItems = const [],
  });

  bool get hasValidData => amount != null && amount! > 0;
}

/// Akıllı Fiş ve Belge Ayrıştırma Motoru (Receipt Parser Engine)
///
/// Türkçe fiş formatlarını, KDV dökümlerini, perakende zincirlerini ve restoran fişlerini
/// tek geçişte (O(N)) analiz eden saf matematiksel ve regex tabanlı algoritma.
class ReceiptParser {
  ReceiptParser._();

  // Toplam Tutar için regex desenleri (Örn: "TOPLAM *124,50", "TUTAR: 85.00 TL", "KREDI KARTI 450,00", "1.450,75 TL")
  static final List<RegExp> _totalPatterns = [
    RegExp(
      r'(?:TOPLAM|TOP|TUTAR|ÖDENEN|ODENEN|KREDI\s*KARTI|NAK[İI]T|GENEL\s*TOPLAM)\s*[:=\*]?\s*(?:TL|₺)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})|[0-9]+[.,][0-9]{2})\s*(?:TL|₺|TRY)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:KDV\s*DAH[İI]L)\s*[:=\*]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    ),
  ];

  // Tarih desenleri (Örn: 24.10.2026, 24/10/2026, 2026-10-24)
  static final RegExp _datePattern = RegExp(
    r'\b([0-3]?[0-9])[./-]([0-1]?[0-9])[./-](20[2-3][0-9])\b',
  );

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

  /// Ham OCR metnini analiz ederek yapısal finansal veriye dönüştürür
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
    final List<String> items = [];
    double confidence = 0.0;

    // 1. İşletme Adı Tespiti (Fişin ilk 3 satırındaki en anlamlı başlık)
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      if (line.length >= 3 && !_isDateOrNumeric(line)) {
        merchant = _cleanMerchantName(line);
        confidence += 0.25;
        break;
      }
    }

    // 2. Tutar Tespiti
    // Öncelik: "TOPLAM" anahtar kelimeli satırlar
    final lowerText = rawText.toLowerCase();

    for (final pattern in _totalPatterns) {
      final matches = pattern.allMatches(rawText);
      for (final m in matches) {
        final valStr = m.group(1);
        if (valStr != null) {
          final parsedVal = _normalizeAmount(valStr);
          if (parsedVal != null && parsedVal > 0) {
            // Fişlerde genelde en yüksek mantıklı tutar toplam tutardır
            if (detectedAmount == null || parsedVal > detectedAmount) {
              detectedAmount = parsedVal;
            }
          }
        }
      }
    }

    // Eğer regex bulamazsa, metindeki en büyük para formatlı sayıyı yakala
    if (detectedAmount == null) {
      final fallbackRegex = RegExp(r'\b([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})|[0-9]+[.,][0-9]{2})\b');
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
        confidence += 0.2;
      }
    } else {
      confidence += 0.45;
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
      suggestedCategory = ExpenseCategory.market; // Varsayılan en yaygın ev kategorisi
    }

    return ParsedReceipt(
      amount: detectedAmount,
      merchantName: merchant ?? 'Market / Mağaza',
      suggestedCategory: suggestedCategory,
      date: detectedDate ?? DateTime.now(),
      confidenceScore: confidence.clamp(0.0, 1.0),
      detectedItems: items,
    );
  }

  static double? _normalizeAmount(String raw) {
    var clean = raw.replaceAll(' ', '').replaceAll('TL', '').replaceAll('₺', '');
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

  static String _cleanMerchantName(String s) {
    var clean = s.replaceAll(RegExp(r'[*=_\-#]'), '').trim();
    if (clean.length > 28) {
      clean = clean.substring(0, 28).trim();
    }
    return clean;
  }
}
