import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/haptic_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/burn_rate_analysis.dart';

/// Ay Sonu Harcama Temposu ve Projeksiyon Analiz Kartı (Burn Rate Card)
///
/// Sıfır emoji, %100 vektörel Material Symbols, 280px ultra-dar ekranda 1.8x yazı ölçeğinde dahi
/// sıfır piksel taşma (zero RenderFlex overflow) garantili dinamik responsive kart.
class BurnRateCard extends ConsumerStatefulWidget {
  const BurnRateCard({super.key});

  @override
  ConsumerState<BurnRateCard> createState() => _BurnRateCardState();
}

class _BurnRateCardState extends ConsumerState<BurnRateCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final analysis = ref.watch(burnRateAnalysisProvider);
    if (analysis == null || analysis.monthlyLimit <= 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (analysis.status) {
      case BurnRateStatus.onTrack:
        statusColor = AppColors.positive;
        statusLabel = 'Dengeli Tempo';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case BurnRateStatus.warning:
        statusColor = const Color(0xFFD97706); // Amber 600
        statusLabel = 'Hafif Risk';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case BurnRateStatus.critical:
        statusColor = AppColors.negative;
        statusLabel = 'Kritik Hız';
        statusIcon = Icons.speed_rounded;
        break;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. ÜST BAŞLIK VE DURUM ROZETİ (Wrap ile dar ekran korumalı)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
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
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.speed_rounded,
                                size: 18,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Harcama Temposu & Projeksiyon',
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 13, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 2. METRİK IZGARASI (Wrap ile esnek kutular)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricBox(
                      context: context,
                      width: maxW > 340 ? (maxW - 16) / 2 : maxW,
                      icon: Icons.trending_up_rounded,
                      label: 'Günlük Hız',
                      value:
                          '${CurrencyFormatter.formatClean(analysis.dailyVelocity)} / gün',
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    _buildMetricBox(
                      context: context,
                      width: maxW > 340 ? (maxW - 16) / 2 : maxW,
                      icon: Icons.event_available_rounded,
                      label: 'Ay Sonu Tahmini',
                      value: CurrencyFormatter.formatClean(
                        analysis.projectedMonthEndSpend,
                      ),
                      color: statusColor,
                      subText: analysis.projectedVariance > 0
                          ? '+${CurrencyFormatter.formatClean(analysis.projectedVariance)} aşım'
                          : '${CurrencyFormatter.formatClean(analysis.projectedVariance.abs())} tasarruf',
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 3. AKILLI EYLEM TAVSİYESİ (Tinted Box)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          analysis.smartRecommendation,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.9)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 4. GENİŞLETİLEBİLİR DETAYLAR TETİKLEYİCİSİ
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticService.selection();
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insights_rounded, size: 14),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _isExpanded
                                        ? 'Projeksiyon Detaylarını Gizle'
                                        : 'Projeksiyon Parametrelerini İncele',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Geçen Gün / Toplam Gün',
                          '${analysis.daysElapsed} gün / ${analysis.daysInMonth} gün',
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          'Kalan Gün Sayısı',
                          '${analysis.daysRemaining} gün',
                        ),
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          'Güvenli Kalan Günlük Limit',
                          '${CurrencyFormatter.formatClean(analysis.safeDailyRemainingBudget)} / gün',
                          valueColor: AppColors.positive,
                        ),
                        if (analysis.budgetDepletionDay != null) ...[
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            'Öngörülen Bütçe Tükenme Günü',
                            'Ayın ${analysis.budgetDepletionDay}. Günü',
                            valueColor: AppColors.negative,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricBox({
    required BuildContext context,
    required double width,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Theme.of(context).textTheme.bodySmall?.color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
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
          if (subText != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
