import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/receipt_parser.dart';
import '../../data/models/expense.dart';

/// Akıllı Fiş ve Belge Tarayıcı Modalı
///
/// Sıfır emoji, %100 vektörel ikonlar ve thumb-friendly ergonomi standardında üretilmiştir.
class ReceiptScannerDialog extends StatefulWidget {
  const ReceiptScannerDialog({super.key});

  static Future<ParsedReceipt?> show(BuildContext context) {
    return showModalBottomSheet<ParsedReceipt>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReceiptScannerDialog(),
    );
  }

  @override
  State<ReceiptScannerDialog> createState() => _ReceiptScannerDialogState();
}

class _ReceiptScannerDialogState extends State<ReceiptScannerDialog> {
  final TextEditingController _rawTextController = TextEditingController();
  ParsedReceipt? _parsed;
  bool _isAnalyzing = false;

  // Hızlı test için örnek gerçekçi fiş senaryoları
  final Map<String, String> _sampleReceipts = {
    'Migros Market': '''
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
''',
    'Enerjisa Elektrik': '''
ENERJİSA İSTANBUL ANADOLU YAKASI
ELEKTRİK PERAKENDE SATIŞ A.Ş.
FATURA TARİHİ: 22.10.2026
SON ÖDEME: 05.11.2026
TÜKETİM BEDELİ: 412.30 TL
VERGİLER: 68.70 TL
ÖDENECEK TUTAR: 481.00 TL
''',
    'Kafe / Restoran': '''
ESPRESSO LAB COFFEE
MODA SAHİL
TARİH: 25.10.2026 14:35
2x FLAT WHITE: 180.00 TL
1x SAN SEBASTIAN: 160.00 TL
KREDI KARTI TOPLAM: 340.00 TL
TEŞEKKÜR EDERİZ
''',
  };

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  void _analyzeText(String text) {
    if (text.trim().isEmpty) {
      setState(() => _parsed = null);
      return;
    }

    setState(() => _isAnalyzing = true);
    HapticService.light();

    // Hızlı matematiksel ayrıştırma
    final result = ReceiptParser.parse(text);

    setState(() {
      _parsed = result;
      _isAnalyzing = false;
    });

    if (result.hasValidData) {
      HapticService.medium();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _rawTextController.text = data.text!;
      _analyzeText(data.text!);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panoda kopyalanmış metin bulunamadı.')),
      );
    }
  }

  void _loadSample(String name) {
    final sample = _sampleReceipts[name];
    if (sample != null) {
      _rawTextController.text = sample;
      _analyzeText(sample);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sürükleme Tutamacı
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Üst Başlık ve Rozet
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akıllı Fiş & Belge Okuyucu',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Fiş metnini yapıştırın veya örnek seçin; tutar ve kategori anında dolsun.',
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hızlı Örnek Yükleme Çipleri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.content_paste_rounded, size: 16, color: AppColors.primary),
                    label: const Text('Panodan Yapıştır'),
                    onPressed: _pasteFromClipboard,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  const SizedBox(width: 8),
                  ..._sampleReceipts.keys.map((name) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.receipt_outlined, size: 16),
                        label: Text(name),
                        onPressed: () => _loadSample(name),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Fiş Metin Girişi
            TextField(
              controller: _rawTextController,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Fiş üzerindeki yazıları buraya yapıştırın veya yazın...\n(Örn: TOPLAM: 245.50 TL, KADIKÖY MARKET)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              ),
              onChanged: _analyzeText,
            ),
            const SizedBox(height: 16),

            // Ayrıştırılan Sonuç Kartı (Varsa)
            if (_parsed != null && _parsed!.hasValidData) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 16, color: AppColors.positive),
                            const SizedBox(width: 6),
                            Text(
                              'Ayrıştırılan Finansal Veri',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.positive : Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.positive.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '%${(_parsed!.confidenceScore * 100).toInt()} Güven Skoru',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.positive : Colors.green.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ayrıştırılan Tutar',
                                style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatClean(_parsed!.amount!),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _parsed!.suggestedCategory!.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_parsed!.suggestedCategory!.icon, size: 16, color: _parsed!.suggestedCategory!.color),
                              const SizedBox(width: 6),
                              Text(
                                _parsed!.suggestedCategory!.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _parsed!.suggestedCategory!.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 15, color: theme.textTheme.bodyMedium?.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _parsed!.merchantName ?? 'Mağaza',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_parsed!.date != null) ...[
                          Icon(Icons.calendar_month_rounded, size: 15, color: theme.textTheme.bodyMedium?.color),
                          const SizedBox(width: 6),
                          Text(
                            DateFormatter.formatSmart(_parsed!.date!),
                            style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Harcamaya Aktar Butonu (52px Thumb Zone)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticService.success();
                    Navigator.of(context).pop(_parsed);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text(
                    'Harcamaya Aktar ve Doldur',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else if (_rawTextController.text.isNotEmpty && !_isAnalyzing) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fişte belirgin bir tutar tespit edilemedi. Lütfen "TOPLAM: 120 TL" gibi tutar bilgisinin yer aldığından emin olun.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
