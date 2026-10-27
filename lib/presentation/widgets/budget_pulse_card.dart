import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/haptic_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/household_budget.dart';

/// Aylık Bütçe İlerleme ve Finansal Nabız Kartı
class BudgetPulseCard extends ConsumerWidget {
  const BudgetPulseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetProvider);
    final currentSpent = ref.watch(currentMonthJointSpendProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (budget == null) return const SizedBox.shrink();

    final health = budget.getHealth(currentSpent);
    final ratio = budget.ratio(currentSpent);
    final remaining = budget.remaining(currentSpent);

    Color healthColor;
    String healthLabel;
    IconData healthIcon;

    switch (health) {
      case BudgetHealth.safe:
        healthColor = AppColors.positive;
        healthLabel = 'Bütçe Dengede';
        healthIcon = Icons.check_circle_outline_rounded;
        break;
      case BudgetHealth.warning:
        healthColor = const Color(0xFFD97706); // Amber
        healthLabel = 'Sınıra Yaklaşıldı';
        healthIcon = Icons.warning_amber_rounded;
        break;
      case BudgetHealth.exceeded:
        healthColor = AppColors.negative;
        healthLabel = 'Limit Aşıldı';
        healthIcon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: healthColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: healthColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst Kısım: Başlık, Durum Rozeti ve Düzenleme Butonu (Ultra duyarlı Wrap + FittedBox)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: healthColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.pie_chart_rounded,
                                size: 18,
                                color: healthColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Aylık Ortak Bütçe',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: healthColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(healthIcon, size: 12, color: healthColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    healthLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: healthColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              tooltip: 'Bütçe Hedefini Düzenle',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                HapticService.light();
                                _openBudgetSettingsDialog(context, ref, budget);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tutar ve Oran Satırı (Wrap ile dar ekran ve büyük font koruması)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              CurrencyFormatter.formatClean(currentSpent),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: healthColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ ${CurrencyFormatter.formatClean(budget.monthlyLimit)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '%${(ratio * 100).toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: healthColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // İlerleme Çubuğu (Animated Progress Bar)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        width: double.infinity,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFF1F5F9),
                      ),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0.0, end: ratio.clamp(0.0, 1.0)),
                        builder: (context, val, _) {
                          return FractionallySizedBox(
                            widthFactor: val,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: healthColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Alt Bilgi: Kalan veya Aşılan Tutar
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      health == BudgetHealth.exceeded
                          ? 'Hedef ${CurrencyFormatter.formatClean(currentSpent - budget.monthlyLimit)} aşıldı'
                          : 'Kalan Kullanılabilir Bütçe: ${CurrencyFormatter.formatClean(remaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: health == BudgetHealth.exceeded
                            ? AppColors.negative
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openBudgetSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    HouseholdBudget budget,
  ) {
    final controller = TextEditingController(
      text: budget.monthlyLimit.toStringAsFixed(0),
    );
    bool alert80 = budget.alertAt80Percent;
    bool alert100 = budget.alertAt100Percent;

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
                      'Aylık Ortak Bütçe Hedefi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ev veya ortaklığınız için aylık toplam gider tavanını belirleyin. Yaklaşıldığında ortaklara uyarı gönderilir.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hızlı Seçim Çipleri
                    Wrap(
                      spacing: 8,
                      children: [15000.0, 25000.0, 35000.0, 50000.0].map((val) {
                        return ActionChip(
                          label: Text(CurrencyFormatter.formatClean(val)),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          onPressed: () {
                            HapticService.light();
                            setModalState(() {
                              controller.text = val.toStringAsFixed(0);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Tutar Girişi
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Aylık Hedef Tutar (TL)',
                        prefixIcon: Icon(Icons.savings_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Uyarı Ayarları
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('%80 Sınır Uyarısı', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Bütçenin %80 seviyesine ulaşıldığında nazik bildirim gönder.', style: TextStyle(fontSize: 12)),
                      value: alert80,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          alert80 = val;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('%100 Aşım Bildirimi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Bütçe aşıldığında bildirim merkezinde yüksek öncelikli uyarı oluştur.', style: TextStyle(fontSize: 12)),
                      value: alert100,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          alert100 = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final parsed = double.tryParse(
                            controller.text.replaceAll('.', '').replaceAll(',', '.'),
                          );
                          if (parsed != null && parsed > 0) {
                            await ref.read(budgetProvider.notifier).updateMonthlyLimit(parsed);
                            await ref.read(budgetProvider.notifier).updateAlertSettings(
                              alert80: alert80,
                              alert100: alert100,
                            );
                            HapticService.success();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
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
                        child: const Text('Bütçeyi Güncelle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
