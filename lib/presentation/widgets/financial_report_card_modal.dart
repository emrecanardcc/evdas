import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/export_service.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/expense.dart';
import '../providers/app_providers.dart';
import 'paywall_modal.dart';

/// Aylık Ortaklık Finansal Karne ve Sosyal Paylaşım Modalı
class FinancialReportCardModal extends ConsumerWidget {
  const FinancialReportCardModal({super.key});

  static Future<void> show(BuildContext context) async {
    HapticService.light();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FinancialReportCardModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(householdProvider);
    final insights = ref.watch(financialInsightsProvider);
    final report = ref.watch(partnershipReportProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final score = insights.healthScore;
    final houseName = house?.name ?? 'Ev Ortaklığı';
    final now = DateTime.now();
    final monthName = _getMonthName(now.month);
    final periodStr = '$monthName ${now.year}';

    // En çok harcayan üye
    final topMember = report.memberSpends.isNotEmpty ? report.memberSpends.first : null;
    // En büyük kategori
    final topCategory = report.categorySpends.isNotEmpty ? report.categorySpends.first : null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tutamaç
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

              // Başlık
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.military_tech_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ortaklık Finansal Karnesi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$houseName • $periodStr Dönem Özeti',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 18),

              // GÖRSEL FİNANSAL KARNE KARTI (Vektörel & Sıfır Emojili)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF8FAFC), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: score.color.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: score.color.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Üst Satır: Skor ve Durum Rozeti
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
                                    Icon(
                                      Icons.insights_rounded,
                                      size: 18,
                                      color: score.color,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Finansal Sağlık Skoru',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: score.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: score.color.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                '${score.score}/100 • ${score.title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: score.color,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // İki Sütunlu Metrik Alanı
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildStatTile(
                              context: context,
                              width: (maxW - 12) / 2,
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Toplam Ortak Gider',
                              value: CurrencyFormatter.formatClean(
                                  report.totalJointExpenses),
                              color: AppColors.primary,
                            ),
                            _buildStatTile(
                              context: context,
                              width: (maxW - 12) / 2,
                              icon: Icons.pie_chart_rounded,
                              label: 'Kişi Başı Pay',
                              value: CurrencyFormatter.formatClean(
                                  report.perMemberAverage),
                              color: const Color(0xFF0284C7),
                            ),
                            _buildStatTile(
                              context: context,
                              width: (maxW - 12) / 2,
                              icon: insights.hasSavedOverall
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_up_rounded,
                              label: 'Aylık Trend',
                              value: insights.hasPreviousMonthData
                                  ? (insights.hasSavedOverall
                                      ? '-%${insights.overallPercentageChange.abs().toStringAsFixed(1)} Tasarruf'
                                      : '+%${insights.overallPercentageChange.toStringAsFixed(1)} Artış')
                                  : 'İlk Ay',
                              color: insights.hasSavedOverall
                                  ? AppColors.positive
                                  : const Color(0xFFD97706),
                            ),
                            _buildStatTile(
                              context: context,
                              width: (maxW - 12) / 2,
                              icon: topCategory?.category.icon ??
                                  Icons.category_rounded,
                              label: 'Lider Kategori',
                              value: topCategory != null
                                  ? '${topCategory.category.displayName} (%${topCategory.percentage.toStringAsFixed(0)})'
                                  : 'Harcama Yok',
                              color: topCategory?.category.color ?? Colors.grey,
                            ),
                          ],
                        ),

                        if (topMember != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dönemin En Çok Katkı Sağlayanı: ${topMember.member.displayName} (%${topMember.percentage.toStringAsFixed(0)} pay)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Evdaş ile oluşturuldu',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // PAYLAŞIM AKSİYONLARI (48px Thumb-Zone Ergonomisi)
              ElevatedButton.icon(
                onPressed: () {
                  HapticService.success();
                  _shareSummaryText(
                    houseName: houseName,
                    periodStr: periodStr,
                    insights: insights,
                    report: report,
                    topMemberName: topMember?.member.displayName,
                    topCategoryName: topCategory?.category.displayName,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Karneyi Paylaş (WhatsApp / Mesaj)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: () async {
                  HapticService.light();
                  final sub = ref.read(subscriptionProvider);
                  if (!sub.canExportDetailedReports()) {
                    PaywallModal.show(
                      context,
                      featureTrigger: 'Detaylı Muhasebe Raporu Dışa Aktarımı',
                    );
                    return;
                  }
                  final expenses = ref.read(expensesProvider);
                  if (expenses.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Dışa aktarılacak harcama yok.')),
                    );
                    return;
                  }
                  await ExportService.exportExpensesToCsv(
                    expenses: expenses,
                    members: house?.members ?? [],
                    householdName: houseName,
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.table_chart_rounded, size: 18),
                label: const Text(
                  'Detaylı CSV / Excel Tablosu Al',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required BuildContext context,
    required double width,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: width.clamp(120.0, double.infinity),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareSummaryText({
    required String houseName,
    required String periodStr,
    required dynamic insights,
    required dynamic report,
    String? topMemberName,
    String? topCategoryName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*$houseName - Aylık Finansal Karne*');
    buffer.writeln('Dönem: $periodStr');
    buffer.writeln('------------------------------------');
    buffer.writeln('*Finansal Sağlık Skoru:* ${insights.healthScore.score}/100 (${insights.healthScore.title})');
    buffer.writeln('*Toplam Ortak Gider:* ${CurrencyFormatter.formatClean(report.totalJointExpenses)}');
    buffer.writeln('*Kişi Başı Düşen Pay:* ${CurrencyFormatter.formatClean(report.perMemberAverage)}');

    if (insights.hasPreviousMonthData) {
      if (insights.hasSavedOverall) {
        buffer.writeln('*Aylık Tasarruf:* Geçen aya göre %${insights.overallPercentageChange.abs().toStringAsFixed(1)} tasarruf sağlandı.');
      } else {
        buffer.writeln('*Aylık Değişim:* Geçen aya göre %${insights.overallPercentageChange.toStringAsFixed(1)} artış görüldü.');
      }
    }

    if (topCategoryName != null) {
      buffer.writeln('*En Çok Harcanan:* $topCategoryName');
    }
    if (topMemberName != null) {
      buffer.writeln('*En Çok Katkı Sağlayan:* $topMemberName');
    }

    buffer.writeln('------------------------------------');
    buffer.writeln('Evdaş ile masraflarınızı kolayca yönetin.');

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: '$houseName Finansal Karne',
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
