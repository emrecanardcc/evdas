import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/subscription_service.dart';
import '../../data/models/expense.dart';
import '../../data/models/financial_insights.dart';
import '../providers/app_providers.dart';
import 'paywall_modal.dart';

/// Evdaş Akıllı Finansal Tasarruf ve Trend Kartı
class FinancialInsightsCard extends ConsumerStatefulWidget {
  const FinancialInsightsCard({super.key});

  @override
  ConsumerState<FinancialInsightsCard> createState() =>
      _FinancialInsightsCardState();
}

class _FinancialInsightsCardState extends ConsumerState<FinancialInsightsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(financialInsightsProvider);
    final subService = ref.watch(subscriptionProvider);
    final isPro = subService.isPro;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final score = insights.healthScore;
    final trends = insights.categoryTrends;
    final allAdvices = insights.advices;

    // Ücretsiz kullanıcıya en önemli 2 tavsiye gösterilir, fazlası Pro ile açılır
    final visibleAdvices = isPro ? allAdvices : allAdvices.take(2).toList();
    final hasMoreAdvices = allAdvices.length > 2 && !isPro;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: score.color.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: score.color.withValues(alpha: 0.05),
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
                // 1. ÜST BAŞLIK VE SKOR ROZETİ (Ultra duyarlı Wrap + FittedBox)
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
                                color: score.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.insights_rounded,
                                size: 18,
                                color: score.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Finansal Uyum & Tasarruf',
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
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: score.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: score.color.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                size: 14,
                                color: score.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${score.score}/100 • ${score.title}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: score.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 2. GEÇEN AYA GÖRE GENEL TREND ROZETİ
                if (insights.hasPreviousMonthData) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (insights.hasSavedOverall
                              ? AppColors.positive
                              : const Color(0xFFD97706))
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (insights.hasSavedOverall
                                ? AppColors.positive
                                : const Color(0xFFD97706))
                            .withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          insights.hasSavedOverall
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          size: 18,
                          color: insights.hasSavedOverall
                              ? AppColors.positive
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            insights.hasSavedOverall
                                ? 'Geçen aya göre %${insights.overallPercentageChange.abs().toStringAsFixed(1)} tasarruf sağlandı'
                                : 'Geçen aya göre ortak giderler %${insights.overallPercentageChange.toStringAsFixed(1)} yükseldi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: insights.hasSavedOverall
                                  ? AppColors.positive
                                  : const Color(0xFFD97706),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 3. KATEGORİ DEĞİŞİM ÇİPLERİ (Top 3)
                if (trends.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: trends.take(4).map((t) {
                          final isPos = t.isDecrease; // Düşüş = tasarruf (olumlu)
                          final chipColor = isPos
                              ? AppColors.positive
                              : (t.isIncrease
                                  ? const Color(0xFFD97706)
                                  : Colors.grey);

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: chipColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.category.icon,
                                      size: 13, color: chipColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${t.category.displayName} ${t.formattedPercentage}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: chipColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 4. AKILLI TAVSİYELER LİSTESİ
                ...visibleAdvices.map((advice) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: advice.type.color.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: advice.type.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              advice.type.icon,
                              size: 15,
                              color: advice.type.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  advice.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  advice.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    height: 1.3,
                                  ),
                                  maxLines: _isExpanded ? 5 : 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // 5. PRO YÜKSELTME KARTI VEYA GENİŞLET BUTONU
                if (hasMoreAdvices) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticService.light();
                      PaywallModal.show(
                        context,
                        featureTrigger:
                            'Yapay Zeka Destekli Akıllı Tasarruf Analizi',
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Evdaş Plus ile ${allAdvices.length - 2} ek tasarruf tavsiyesini aç',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (allAdvices.length > 2) ...[
                  // Pro kullanıcılar için daralt/genişlet
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                      ),
                      icon: Icon(
                        _isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _isExpanded ? 'Daha Az Göster' : 'Detayları Genişlet',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        HapticService.selection();
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
