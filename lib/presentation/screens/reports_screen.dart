import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/export_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/expense.dart';
import '../../domain/reporting_engine.dart';
import '../providers/app_providers.dart';
import '../providers/customization_provider.dart';
import '../widgets/animated_rolling_number.dart';
import '../widgets/budget_pulse_card.dart';
import '../widgets/burn_rate_card.dart';
import '../widgets/financial_insights_card.dart';
import '../widgets/financial_report_card_modal.dart';
import '../widgets/paywall_modal.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(householdProvider);
    final report = ref.watch(partnershipReportProvider);
    final currentRange = ref.watch(reportTimeRangeProvider);
    final isPrivacy = ref.watch(privacyModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Gider Raporları & Analiz',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.military_tech_rounded),
            tooltip: 'Aylık Finansal Karne',
            onPressed: () => FinancialReportCardModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Harcamaları CSV Dışa Aktar',
            onPressed: () async {
              final subService = ref.read(subscriptionProvider);
              if (!subService.canExportDetailedReports()) {
                PaywallModal.show(
                  context,
                  featureTrigger: 'Excel / CSV Veri Dışa Aktarımı',
                );
                return;
              }
              final expenses = ref.read(expensesProvider);
              if (expenses.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dışa aktarılacak harcama bulunamadı.')),
                );
                return;
              }
              await ExportService.exportExpensesToCsv(
                expenses: expenses,
                members: house?.members ?? [],
                householdName: house?.name ?? 'Evdaş Ortaklığı',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Detaylı Finansal Raporu Paylaş',
            onPressed: () async {
              if (house != null) {
                await ExportService.exportFormattedReport(
                  report: report,
                  householdName: house.name,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(expenseRepositoryProvider).syncWithCloud();
          ref.read(householdProvider.notifier).refresh();
          ref.read(expensesProvider.notifier).refresh();
          ref.read(paymentRequestsProvider.notifier).refresh();
          ref.read(approvalRequestsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // 1. ZAMAN ARALIĞI SEÇİCİ
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ReportTimeRange.values.map((range) {
                  final isSelected = range == currentRange;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(range.displayName),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      onSelected: (_) {
                        ref
                            .read(reportTimeRangeProvider.notifier)
                            .setRange(range);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // 2. AYLIK BÜTÇE İLERLEME VE FİNANSAL NABIZ KARTI
            const BudgetPulseCard(),

            const SizedBox(height: 16),

            // 2b. AKILLI FİNANSAL TASARRUF & TREND KARTI
            const FinancialInsightsCard(),

            const SizedBox(height: 16),

            // 2c. AY SONU HARCAMA TEMPOSU & PROJEKSİYON KARTI
            const BurnRateCard(),

            const SizedBox(height: 16),

            // 3. NET GİDER ÖZET KARTLARI
            _buildSummaryCard(context, report, isPrivacy),

            const SizedBox(height: 20),

            // 3. KATEGORİ BAZINDA DAĞILIM (KULLANICININ İSTEDİĞİ NET GİDER BÖLÜMÜ)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'Kategori Dağılımı',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${report.categorySpends.length} kategori',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (report.categorySpends.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Bu dönem için henüz harcama kaydı yok.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...report.categorySpends.map((cat) => _buildCategoryCard(context, cat, isPrivacy)),

            const SizedBox(height: 20),

            // 4. KİM NE KADAR HARCADI (ÜYE DAĞILIMI)
            const Text(
              'Ortakların Harcama Payı',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: report.memberSpends.map((mem) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  mem.member.displayName,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedRollingNumber(
                                        value: mem.amount,
                                        isMasked: isPrivacy,
                                        style: const TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '(%${mem.percentage.toStringAsFixed(1)})',
                                        style: const TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: mem.percentage / 100.0,
                              minHeight: 7,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // 4b. ŞAHSİ BORÇLAR DAĞILIMI (KİMİN KİME NE KADAR BORCU VAR)
            if (report.personalDebtsBreakdown.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (MediaQuery.sizeOf(context).width - 32).clamp(120.0, 400.0),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.handshake_rounded,
                            size: 20, color: AppColors.personalDebt),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Şahsi Borçlar',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${report.personalDebtsBreakdown.length} borç ilişkisi',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: report.personalDebtsBreakdown.map((debt) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.personalDebt
                                  .withValues(alpha: 0.15),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: AppColors.personalDebt),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: debt.debtorName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                        const TextSpan(text: ' borçlu ➔ '),
                                        TextSpan(
                                          text: debt.creditorName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${debt.count} işlem kaydedildi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyFormatter.formatClean(debt.amount, checkPrivacy: true),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.personalDebt,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 5. RAPORU ORTAKLARLA PAYLAŞ BUTONU
            ElevatedButton.icon(
              onPressed: () {
                if (house != null) {
                  final text = report.toSummaryString(house.name);
                  SharePlus.instance.share(
                    ShareParams(
                      text: text,
                      subject: '${house.name} Gider Raporu',
                    ),
                  );
                }
              },
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Raporu Ortaklarla Paylaş'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSummaryCard(BuildContext context, PartnershipReport report, bool isPrivacy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dönem Net Harcaması',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedRollingNumber(
                      value: report.grandTotal,
                      isMasked: isPrivacy,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${report.totalTransactionCount} İşlem',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ortak Masraflar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedRollingNumber(
                      value: report.totalJointExpenses,
                      isMasked: isPrivacy,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kişi Başı Düşen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedRollingNumber(
                      value: report.perMemberAverage,
                      isMasked: isPrivacy,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategorySpend cat, bool isPrivacy) {
    final catColor = _getCategoryColor(cat.category);
    final catIcon = _getCategoryIcon(cat.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.category.displayName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${cat.count} harcama',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatClean(cat.amount, checkPrivacy: true),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '%${cat.percentage.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: cat.percentage / 100.0,
                minHeight: 5,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(catColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.market:
        return Icons.shopping_bag_outlined;
      case ExpenseCategory.fatura:
        return Icons.bolt_outlined;
      case ExpenseCategory.kira:
        return Icons.home_outlined;
      case ExpenseCategory.mutfak:
        return Icons.restaurant_outlined;
      case ExpenseCategory.esya:
        return Icons.weekend_outlined;
      case ExpenseCategory.ulasim:
        return Icons.directions_car_outlined;
      case ExpenseCategory.diger:
        return Icons.receipt_outlined;
    }
  }

  Color _getCategoryColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.market:
        return AppColors.categoryMarket;
      case ExpenseCategory.fatura:
        return AppColors.categoryFatura;
      case ExpenseCategory.kira:
        return AppColors.categoryKira;
      case ExpenseCategory.mutfak:
        return AppColors.categoryMutfak;
      case ExpenseCategory.esya:
        return AppColors.categoryEsya;
      case ExpenseCategory.ulasim:
        return AppColors.categoryUlasim;
      case ExpenseCategory.diger:
        return AppColors.categoryDiger;
    }
  }
}
