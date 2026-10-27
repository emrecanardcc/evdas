import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/recurring_expense_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_member.dart';
import '../../data/models/partnership.dart';
import '../../data/models/recurring_expense.dart';
import '../providers/app_providers.dart';
import 'paywall_modal.dart';
import 'staggered_fade_slide.dart';

/// Düzenli ve Sabit Giderler Yönetim Modalı
class RecurringExpensesModal extends ConsumerStatefulWidget {
  const RecurringExpensesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RecurringExpensesModal(),
    );
  }

  @override
  ConsumerState<RecurringExpensesModal> createState() =>
      _RecurringExpensesModalState();
}

class _RecurringExpensesModalState
    extends ConsumerState<RecurringExpensesModal> {
  final _uuid = const Uuid();

  static String _monthName(int month) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(householdProvider);
    final allRecurring = ref.watch(recurringExpensesProvider);
    final recurringList =
        allRecurring.where((r) => r.householdId == house?.id).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Tutamaç
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Başlık ve Yeni Ekle Butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_repeat_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sabit ve Düzenli Giderler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        recurringList.isEmpty
                            ? 'Otomatik aylık masraf planı'
                            : '${recurringList.length} kayıtlı sabit gider',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openAddDialog(context, house),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Yeni Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Liste veya Boş Durum
          Expanded(
            child: recurringList.isEmpty
                ? _buildEmptyState(context, house, isDark)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: recurringList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = recurringList[index];
                      return StaggeredFadeSlide(
                        index: index,
                        child: _buildRecurringCard(context, house, item, isDark),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Partnership? house,
    bool isDark,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_repeat_rounded,
                size: 48,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Düzenli Gider Tanımlanmadı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Kira, aidat, internet veya faturaları takvime bağlayarak her ay otomatik hesaplanmasını sağlayabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildPresetChip('Kira', ExpenseCategory.kira, Icons.home_work_rounded, house),
                _buildPresetChip('Site Aidatı', ExpenseCategory.kira, Icons.apartment_rounded, house),
                _buildPresetChip('İnternet', ExpenseCategory.fatura, Icons.wifi_rounded, house),
                _buildPresetChip('Elektrik', ExpenseCategory.fatura, Icons.bolt_rounded, house),
                _buildPresetChip('Abonelik', ExpenseCategory.diger, Icons.subscriptions_rounded, house),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    String title,
    ExpenseCategory cat,
    IconData icon,
    Partnership? house,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(title),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      onPressed: () {
        HapticService.light();
        _openAddDialog(context, house, presetTitle: title, presetCategory: cat);
      },
    );
  }

  Widget _buildRecurringCard(
    BuildContext context,
    Partnership? house,
    RecurringExpense item,
    bool isDark,
  ) {
    final membersList = house?.members ?? <HouseholdMember>[];
    final payer = membersList.firstWhere(
      (m) => m.id == item.paidByMemberId,
      orElse: () => HouseholdMember(
        id: item.paidByMemberId,
        householdId: house?.id ?? '',
        displayName: 'Ortak',
      ),
    );
    final payerName = payer.displayName;

    final nextDate = item.nextDueDate(DateTime.now());
    final dateStr = '${nextDate.day} ${_monthName(nextDate.month)}';

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? (item.isActive ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
            : (item.isActive ? Colors.white : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isActive
              ? item.category.color.withValues(alpha: 0.3)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
        boxShadow: item.isActive
            ? [
                BoxShadow(
                  color: item.category.color.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.category.icon,
                    size: 20,
                    color: item.category.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: item.isActive ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Her ayın ${item.dayOfMonth}. günü • Ödeyen: $payerName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatClean(item.amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: item.isActive ? AppColors.primary : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isActive
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: item.isActive ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sonraki: $dateStr',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.isActive ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      tooltip: 'Sil',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () {
                        HapticService.light();
                        _confirmDelete(context, item);
                      },
                    ),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: item.isActive,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        HapticService.selection();
                        ref
                            .read(recurringExpensesProvider.notifier)
                            .toggleActive(item.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, RecurringExpense item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sabit Gideri Sil'),
        content: Text('"${item.title}" sabit gideri listeden kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(recurringExpensesProvider.notifier).deleteRecurring(item.id);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _openAddDialog(
    BuildContext context,
    Partnership? house, {
    String? presetTitle,
    ExpenseCategory? presetCategory,
  }) {
    if (house == null || house.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce aktif bir ortaklık grubu seçmelisiniz.')),
      );
      return;
    }

    // Freemium Pro Limit Kontrolü
    final subState = ref.read(subscriptionProvider);
    final allRecurring = ref.read(recurringExpensesProvider);
    final activeCount = allRecurring.where((r) => r.householdId == house.id && r.isActive).length;

    if (!subState.canCreateRecurringExpense(activeCount)) {
      PaywallModal.show(context);
      return;
    }

    final titleController = TextEditingController(text: presetTitle ?? '');
    final amountController = TextEditingController();
    ExpenseCategory selectedCategory = presetCategory ?? ExpenseCategory.kira;
    String selectedPayerId = house.members.first.id;
    int selectedDay = 1;
    bool autoPost = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Yeni Sabit Gider Planı',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),

                    // Başlık
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Gider Başlığı',
                        hintText: 'Örn: Ev Kirası, Fiber İnternet',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tutar
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Tutar (TL)',
                        hintText: '0,00',
                        prefixIcon: Icon(Icons.payments_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kategori Seçici
                    const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ExpenseCategory.values.map((cat) {
                        final isSel = cat == selectedCategory;
                        return ChoiceChip(
                          selected: isSel,
                          showCheckmark: false,
                          avatar: Icon(cat.icon, size: 16, color: isSel ? Colors.white : cat.color),
                          label: Text(cat.displayName),
                          selectedColor: cat.color,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : null,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (_) {
                            setModalState(() {
                              selectedCategory = cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Ödeyen Üye
                    const Text('Masrafı Ödeyecek Kişi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPayerId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Ödeyen Üye',
                      ),
                      items: house.members.map((m) {
                        return DropdownMenuItem(
                          value: m.id,
                          child: Text(m.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedPayerId = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ayın Günü (1-28)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Her Ayın Günü:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('Ayın $selectedDay. günü', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                    Slider(
                      value: selectedDay.toDouble(),
                      min: 1,
                      max: 28,
                      divisions: 27,
                      label: '$selectedDay',
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          selectedDay = val.round();
                        });
                      },
                    ),

                    // Otomatik Ekleme Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Günü Geldiğinde Otomatik Ekle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Vade günü geldiğinde harcamalara otomatik ortak masraf olarak işlenir.', style: TextStyle(fontSize: 12)),
                      value: autoPost,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          autoPost = val;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final amountParsed = double.tryParse(
                            amountController.text.replaceAll('.', '').replaceAll(',', '.'),
                          );

                          if (title.isEmpty || amountParsed == null || amountParsed <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lütfen geçerli bir başlık ve tutar girin.')),
                            );
                            return;
                          }

                          final newRecurring = RecurringExpense(
                            id: _uuid.v4(),
                            householdId: house.id,
                            title: title,
                            amount: amountParsed,
                            category: selectedCategory,
                            paidByMemberId: selectedPayerId,
                            dayOfMonth: selectedDay,
                            autoPost: autoPost,
                            isActive: true,
                          );

                          await ref
                              .read(recurringExpensesProvider.notifier)
                              .addRecurring(newRecurring);

                          HapticService.success();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Sabit Gideri Kaydet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
