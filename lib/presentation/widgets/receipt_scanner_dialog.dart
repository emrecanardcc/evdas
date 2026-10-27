import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/receipt_parser.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_member.dart';

/// Akıllı Fiş ve Belge Tarayıcısı & Çoklu Kalem Ayrıştırıcı Modalı
///
/// Sıfır emoji, %100 vektörel ikonlar ve thumb-friendly (>= 48px) ergonomi standardında üretilmiştir.
class ReceiptScannerDialog extends StatefulWidget {
  final List<HouseholdMember>? members;
  final String? currentMemberId;

  const ReceiptScannerDialog({
    super.key,
    this.members,
    this.currentMemberId,
  });

  static Future<ParsedReceipt?> show(
    BuildContext context, {
    List<HouseholdMember>? members,
    String? currentMemberId,
  }) {
    return showModalBottomSheet<ParsedReceipt>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptScannerDialog(
        members: members,
        currentMemberId: currentMemberId,
      ),
    );
  }

  @override
  State<ReceiptScannerDialog> createState() => _ReceiptScannerDialogState();
}

class _ReceiptScannerDialogState extends State<ReceiptScannerDialog> {
  final TextEditingController _rawTextController = TextEditingController();
  ParsedReceipt? _parsed;
  bool _isAnalyzing = false;
  String? _selectedPayerId;

  // Hızlı test için gerçekçi fiş senaryoları
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
  void initState() {
    super.initState();
    _selectedPayerId = widget.currentMemberId ??
        (widget.members != null && widget.members!.isNotEmpty
            ? widget.members!.first.id
            : null);
  }

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

    // Hızlı matematiksel ve çoklu kalem ayrıştırma
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

  void _toggleItemSelection(int index) {
    if (_parsed == null || index >= _parsed!.lineItems.length) return;
    HapticService.selection();
    final updatedList = List<ReceiptLineItem>.from(_parsed!.lineItems);
    final target = updatedList[index];
    updatedList[index] = target.copyWith(isSelected: !target.isSelected);

    setState(() {
      _parsed = _parsed!.copyWith(lineItems: updatedList);
    });
  }

  void _toggleSelectAll() {
    if (_parsed == null || _parsed!.lineItems.isEmpty) return;
    HapticService.selection();
    final allSelected = _parsed!.lineItems.every((i) => i.isSelected);
    final updatedList = _parsed!.lineItems
        .map((i) => i.copyWith(isSelected: !allSelected))
        .toList();

    setState(() {
      _parsed = _parsed!.copyWith(lineItems: updatedList);
    });
  }

  void _changeItemCategory(int index, ExpenseCategory newCat) {
    if (_parsed == null || index >= _parsed!.lineItems.length) return;
    HapticService.selection();
    final updatedList = List<ReceiptLineItem>.from(_parsed!.lineItems);
    updatedList[index] = updatedList[index].copyWith(category: newCat);

    setState(() {
      _parsed = _parsed!.copyWith(lineItems: updatedList);
    });
  }

  void _removeItem(int index) {
    if (_parsed == null || index >= _parsed!.lineItems.length) return;
    HapticService.light();
    final updatedList = List<ReceiptLineItem>.from(_parsed!.lineItems);
    updatedList.removeAt(index);

    setState(() {
      _parsed = _parsed!.copyWith(lineItems: updatedList);
    });
  }

  void _saveSelectedItemsDirectly() {
    if (_parsed == null) return;
    final selectedItems =
        _parsed!.lineItems.where((i) => i.isSelected).toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen ortaklığa kaydedilecek en az 1 kalem seçin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticService.success();
    Navigator.of(context).pop(
      _parsed!.copyWith(
        lineItemsSavedDirectly: true,
        selectedPayerId: _selectedPayerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final members = widget.members ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
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
                  child: const Icon(Icons.document_scanner_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akıllı Fiş & Belge Okuyucu',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Fişi tarayın; tutar, satıcı ve çoklu kalemler anında dolsun.',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color),
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
                    avatar: const Icon(Icons.content_paste_rounded,
                        size: 16, color: AppColors.primary),
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
                hintText:
                    'Fiş üzerindeki yazıları buraya yapıştırın veya yazın...\n(Örn: SÜT: 38.50, DETERJAN: 98.00, TOPLAM: 136.50 TL)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
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
                  border: Border.all(
                      color: AppColors.positive.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 6,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 16, color: AppColors.positive),
                              const SizedBox(width: 6),
                              Text(
                                'Ayrıştırılan Finansal Veri',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.positive
                                      : Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.positive.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '%${(_parsed!.confidenceScore * 100).toInt()} Güven Skoru',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.positive
                                  : Colors.green.shade900,
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
                                'Ayrıştırılan Toplam',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.textTheme.bodyMedium?.color),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.formatClean(
                                      _parsed!.amount!),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _parsed!.suggestedCategory!.color
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_parsed!.suggestedCategory!.icon,
                                    size: 16,
                                    color: _parsed!.suggestedCategory!.color),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _parsed!.suggestedCategory!.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _parsed!.suggestedCategory!.color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_rounded,
                                  size: 15,
                                  color: theme.textTheme.bodyMedium?.color),
                              const SizedBox(width: 6),
                              Text(
                                _parsed!.merchantName ?? 'Mağaza',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        if (_parsed!.date != null) ...[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_month_rounded,
                                    size: 15,
                                    color: theme.textTheme.bodyMedium?.color),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormatter.formatSmart(_parsed!.date!),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodyMedium?.color),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Harcamaya Aktar ve Doldur Butonu (52px Thumb Zone - Tek Tıkla Numpad'e Doldurur)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticService.success();
                    Navigator.of(context).pop(_parsed);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Harcamaya Aktar ve Doldur',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ÇOKLU SATIR KALEMLERİ BÖLÜMÜ (Multi-Item Breakdown)
              if (_parsed!.hasLineItems) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Kalemler Başlığı & Tümünü Seç/Kaldır
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 6,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.format_list_bulleted_rounded,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Ayrıştırılan Kalemler (${_parsed!.lineItems.length})',
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _toggleSelectAll,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                _parsed!.lineItems.every((i) => i.isSelected)
                                    ? 'Seçimi Kaldır'
                                    : 'Tümünü Seç',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Ödeyen Üye Seçici (Ortaklıkta birden fazla üye varsa)
                      if (members.length > 1) ...[
                        Text(
                          'Ödeyen Üye:',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodyMedium?.color,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: members.map((m) {
                              final isSelected =
                                  (_selectedPayerId ?? members.first.id) ==
                                      m.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  avatar: Icon(Icons.person_rounded,
                                      size: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : theme.textTheme.bodyMedium?.color),
                                  label: Text(m.displayName),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    HapticService.selection();
                                    setState(() => _selectedPayerId = m.id);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Kalem Listesi
                      ...List.generate(_parsed!.lineItems.length, (index) {
                        final item = _parsed!.lineItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (item.isSelected
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.02))
                                : (item.isSelected
                                    ? AppColors.primary.withValues(alpha: 0.04)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: item.isSelected
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.withValues(alpha: 0.2)),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _toggleItemSelection(index),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  // Seçim Kutusu (>=48x48 ergonomi)
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: Checkbox(
                                        value: item.isSelected,
                                        onChanged: (_) =>
                                            _toggleItemSelection(index),
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Kalem Adı & Miktar
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (item.quantity > 1) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1),
                                                margin: const EdgeInsets.only(
                                                    right: 5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${item.quantity}x',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: item.isSelected
                                                      ? null
                                                      : theme.textTheme.bodyMedium
                                                          ?.color,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        // Kategori Değiştirici Popup Menüsü
                                        PopupMenuButton<ExpenseCategory>(
                                          initialValue: item.category,
                                          onSelected: (cat) =>
                                              _changeItemCategory(index, cat),
                                          tooltip: 'Kategori Değiştir',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(item.category.icon,
                                                  size: 13,
                                                  color: item.category.color),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  item.category.displayName,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: item.category.color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(Icons.arrow_drop_down_rounded,
                                                  size: 14,
                                                  color: item.category.color),
                                            ],
                                          ),
                                          itemBuilder: (context) {
                                            return ExpenseCategory.values
                                                .map((c) {
                                              return PopupMenuItem<
                                                  ExpenseCategory>(
                                                value: c,
                                                child: Row(
                                                  children: [
                                                    Icon(c.icon,
                                                        size: 16,
                                                        color: c.color),
                                                    const SizedBox(width: 8),
                                                    Text(c.displayName,
                                                        style: const TextStyle(
                                                            fontSize: 13)),
                                                  ],
                                                ),
                                              );
                                            }).toList();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 6),
                                  // Fiyat (FittedBox ile ölçeklenir, asla taşmaz)
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            CurrencyFormatter.formatClean(
                                                item.totalPrice),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: item.isSelected
                                                  ? AppColors.primary
                                                  : theme.textTheme.bodyMedium
                                                      ?.color,
                                            ),
                                          ),
                                        ),
                                        if (item.quantity > 1) ...[
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '${CurrencyFormatter.formatClean(item.price)}/ad',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: theme
                                                    .textTheme.bodyMedium?.color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    onPressed: () => _removeItem(index),
                                    tooltip: 'Kalemi Kaldır',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 48, minHeight: 48),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 6),
                      // Seçili Kalemlerin Özeti
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Seçili: ${_parsed!.selectedCount} / ${_parsed!.lineItems.length} Kalem',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyFormatter.formatClean(
                                      _parsed!.selectedLineItemsAmount),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Aksiyon: Çoklu Kalemleri Ayrı Ayrı Kaydet (52px Thumb Zone)
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _parsed!.selectedCount > 0
                        ? _saveSelectedItemsDirectly
                        : null,
                    icon: const Icon(Icons.playlist_add_check_rounded,
                        size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Seçili ${_parsed!.selectedCount} Kalemi Ortaklığa Kaydet',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ] else if (_rawTextController.text.isNotEmpty &&
                !_isAnalyzing) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fişte belirgin bir tutar tespit edilemedi. Lütfen "TOPLAM: 120 TL" gibi tutar bilgisinin yer aldığından emin olun.',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
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
