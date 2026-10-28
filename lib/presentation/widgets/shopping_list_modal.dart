import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/shopping_service.dart';
import '../../data/models/expense.dart';
import '../../data/models/shopping_item.dart';
import '../providers/app_providers.dart';

/// Ortak Alışveriş ve İhtiyaç Listesi Modalı
class ShoppingListModal extends ConsumerStatefulWidget {
  const ShoppingListModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ShoppingListModal(),
    );
  }

  @override
  ConsumerState<ShoppingListModal> createState() => _ShoppingListModalState();
}

class _ShoppingListModalState extends ConsumerState<ShoppingListModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final ExpenseCategory _selectedCategory = ExpenseCategory.market;
  int _quantity = 1;
  String _unit = 'Adet';
  bool _showCompleted = false;

  final List<({String title, ExpenseCategory category, String unit, double est})>
      _quickTemplates = const [
    (title: 'Damacana Su (19L)', category: ExpenseCategory.market, unit: 'Damacana', est: 90.0),
    (title: 'Bulaşık Tableti', category: ExpenseCategory.esya, unit: 'Kutu', est: 220.0),
    (title: 'Çamaşır Deterjanı', category: ExpenseCategory.esya, unit: 'Paket', est: 180.0),
    (title: 'Tuvalet Kağıdı', category: ExpenseCategory.esya, unit: 'Paket', est: 195.0),
    (title: 'Zeytinyağı', category: ExpenseCategory.market, unit: 'Şişe', est: 350.0),
    (title: 'Ekmek', category: ExpenseCategory.mutfak, unit: 'Adet', est: 15.0),
    (title: 'Süt', category: ExpenseCategory.mutfak, unit: 'Kutu', est: 35.0),
    (title: 'Kahve', category: ExpenseCategory.mutfak, unit: 'Paket', est: 95.0),
    (title: 'Çöp Poşeti', category: ExpenseCategory.esya, unit: 'Rulo', est: 45.0),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _addQuickItem(
    String title,
    ExpenseCategory category,
    String unit,
    double est,
  ) {
    final house = ref.read(householdProvider);
    final currentMember = ref.read(currentMemberProvider);
    if (house == null) return;

    HapticService.light();
    ref.read(shoppingListProvider.notifier).addItem(
          householdId: house.id,
          title: title,
          category: category,
          memberId: currentMember?.id ?? 'user',
          memberName: currentMember?.displayName ?? 'Sen',
          estimatedPrice: est,
          quantity: 1,
          unit: unit,
        );
  }

  void _submitCustomItem() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final house = ref.read(householdProvider);
    final currentMember = ref.read(currentMemberProvider);
    if (house == null) return;

    HapticService.selection();
    ref.read(shoppingListProvider.notifier).addItem(
          householdId: house.id,
          title: title,
          category: _selectedCategory,
          memberId: currentMember?.id ?? 'user',
          memberName: currentMember?.displayName ?? 'Sen',
          quantity: _quantity,
          unit: _unit,
        );

    _titleController.clear();
    setState(() {
      _quantity = 1;
      _unit = 'Adet';
    });
  }

  void _showConvertToExpenseDialog(List<ShoppingItem> completedItems) {
    final house = ref.read(householdProvider);
    final currentMember = ref.read(currentMemberProvider);
    if (house == null || completedItems.isEmpty) return;

    double defaultTotal = 0.0;
    for (final item in completedItems) {
      defaultTotal += (item.estimatedPrice ?? 0.0) * item.quantity;
    }
    _amountController.text =
        defaultTotal > 0 ? defaultTotal.toStringAsFixed(0) : '';

    String selectedPayerId = currentMember?.id ?? house.members.first.id;
    final selectedItemIds = completedItems.map((e) => e.id).toSet();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = Theme.of(ctx);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_rounded,
                        color: AppColors.positive, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Harcamaya Dönüştür',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Seçili ${selectedItemIds.length} kalemi ortak harcama olarak kaydet:',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: completedItems.map((i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 16, color: AppColors.positive),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${i.title} (${i.quantity} ${i.unit})',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ödenen Toplam Tutar (TL)',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_lira_rounded),
                        hintText: '0.00',
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ödeyen Ev Arkadaşı',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: house.members.map((m) {
                        final isSel = m.id == selectedPayerId;
                        return ChoiceChip(
                          label: Text(m.displayName),
                          selected: isSel,
                          showCheckmark: false,
                          onSelected: (_) {
                            setDialogState(() {
                              selectedPayerId = m.id;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('İptal'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Ortak Masrafa Yaz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.positive,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final rawAmount =
                        _amountController.text.replaceAll(',', '.').trim();
                    final parsedAmount = double.tryParse(rawAmount) ?? 0.0;
                    if (parsedAmount <= 0) return;

                    Navigator.pop(dialogCtx);

                    await ref
                        .read(shoppingListProvider.notifier)
                        .convertToExpense(
                          householdId: house.id,
                          itemIds: selectedItemIds.toList(),
                          totalAmount: parsedAmount,
                          paidByMemberId: selectedPayerId,
                        );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.cloud_done_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '₺${parsedAmount.toStringAsFixed(2)} ortak harcama olarak kaydedildi.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.positive,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(householdProvider);
    final allItems = ref.watch(shoppingListProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final theme = Theme.of(context);

    final houseItems =
        allItems.where((i) => i.householdId == (house?.id ?? '')).toList();
    final activeItems = houseItems.where((i) => !i.isCompleted).toList();
    final completedItems = houseItems.where((i) => i.isCompleted).toList();
    final displayedItems = _showCompleted ? completedItems : activeItems;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // TUTAMAÇ ŞERİDİ
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // BAŞLIK BÖLÜMÜ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_basket_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ortak İhtiyaç Listesi',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${activeItems.length} bekleyen eksik • ${completedItems.length} alınan',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // SEKME SEÇİCİ (Alınacaklar / Alınanlar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      selected: !_showCompleted,
                      showCheckmark: false,
                      avatar: const Icon(Icons.format_list_bulleted_rounded,
                          size: 16),
                      label: Center(
                        child: Text('Alınacaklar (${activeItems.length})',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      onSelected: (_) => setState(() => _showCompleted = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      selected: _showCompleted,
                      showCheckmark: false,
                      avatar:
                          const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: Center(
                        child: Text('Alınanlar (${completedItems.length})',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      onSelected: (_) => setState(() => _showCompleted = true),
                    ),
                  ),
                ],
              ),
            ),

            // HIZLI ŞABLON EKSİKLER (Sadece Alınacaklar modunda)
            if (!_showCompleted) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickTemplates.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final t = _quickTemplates[index];
                    return ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 14),
                      label: Text(t.title,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () => _addQuickItem(
                        t.title,
                        t.category,
                        t.unit,
                        t.est,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // YENİ ÖZEL EKSİK GİRİŞ ALANI
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        onSubmitted: (_) => _submitCustomItem(),
                        decoration: InputDecoration(
                          hintText: 'Evde ne bitti? (Örn: Zeytinyağı)',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.edit_note_rounded,
                              size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Listeye Ekle',
                      onPressed: _submitCustomItem,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // KALEMLER LİSTESİ
            Expanded(
              child: displayedItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showCompleted
                                ? Icons.shopping_bag_outlined
                                : Icons.playlist_add_check_rounded,
                            size: 48,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showCompleted
                                ? 'Henüz alınan bir eksik yok.'
                                : 'Harika! Evde bekleyen eksik bulunmuyor.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: displayedItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = displayedItems[index];
                        final isDone = item.isCompleted;

                        return Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDone
                                  ? AppColors.positive.withValues(alpha: 0.3)
                                  : theme.dividerColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            leading: IconButton(
                              icon: Icon(
                                isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isDone
                                    ? AppColors.positive
                                    : theme.disabledColor,
                                size: 24,
                              ),
                              tooltip: isDone ? 'Geri Al' : 'Alındı Olarak İşaretle',
                              onPressed: () {
                                HapticService.selection();
                                ref
                                    .read(shoppingListProvider.notifier)
                                    .toggleItem(
                                      item.id,
                                      memberId: currentMember?.id,
                                    );
                              },
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDone
                                    ? theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.5)
                                    : null,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (item.addedByName != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${item.addedByName}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                                if (item.isExpenseConverted) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.positive
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Harcamaya İşlendi',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.positive,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: 'Sil',
                              onPressed: () {
                                HapticService.light();
                                ref
                                    .read(shoppingListProvider.notifier)
                                    .deleteItem(item.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ALT AKSİYON ÇUBUĞU (Eğer Alınanlar varsa tek tıkla Harcamaya Dönüştür)
            if (completedItems.any((i) => !i.isExpenseConverted))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payments_rounded, size: 20),
                        label: Text(
                          'Alınan ${completedItems.where((i) => !i.isExpenseConverted).length} Kalemi Harcamaya Ekle',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.positive,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showConvertToExpenseDialog(
                          completedItems
                              .where((i) => !i.isExpenseConverted)
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
