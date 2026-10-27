import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/subscription_service.dart';

/// Evdaş Pro Abonelik ve Paywall Modalı
///
/// Sıfır emoji, keskin vektörel ikonlar ve thumb-friendly ergonomi standardında üretilmiştir.
class PaywallModal extends ConsumerStatefulWidget {
  final String? featureTrigger;

  const PaywallModal({super.key, this.featureTrigger});

  static Future<void> show(BuildContext context, {String? featureTrigger}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallModal(featureTrigger: featureTrigger),
    );
  }

  @override
  ConsumerState<PaywallModal> createState() => _PaywallModalState();
}

class _PaywallModalState extends ConsumerState<PaywallModal> {
  SubscriptionTier _selectedTier = SubscriptionTier.proYearly;
  bool _isLoading = false;

  final List<({IconData icon, String title, String subtitle})> _proFeatures = const [
    (
      icon: Icons.home_work_rounded,
      title: 'Ev Ortak Lisansı & Otomatik Bölüşüm',
      subtitle: 'Tüm ev için tek lisans, 3 kişilik evde kişi başı yalnızca ₺100/ay',
    ),
    (
      icon: Icons.all_inclusive_rounded,
      title: 'Sınırsız Ortaklık ve Ev',
      subtitle: 'Dilediğiniz kadar ev, ofis veya tatil grubu oluşturun',
    ),
    (
      icon: Icons.table_chart_rounded,
      title: 'Finansal Raporlar & Excel/PDF Dışa Aktarım',
      subtitle: 'Detaylı muhasebe dökümlerini tek tıkla paylaşın',
    ),
    (
      icon: Icons.event_repeat_rounded,
      title: 'Otomatik Talimatlar & Sabit Giderler',
      subtitle: 'Kira, aidat ve faturaların otomatik kaydı ve asgari transfer',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final subService = ref.watch(subscriptionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'EVDAS PLUS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Ev Masraflarında Tam Özgürlük',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.textTheme.titleLarge?.color,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.featureTrigger != null
                  ? '${widget.featureTrigger} özelliğini sınırsız kullanmak için Evdaş Plus paketine geçiş yapın.'
                  : 'Sınırları kaldırın, tüm finansal geçmişinizi ve ortaklıklarınızı profesyonelce yönetin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // Özellik Listesi (Vektörel & Minimal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: _proFeatures.map((feat) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(feat.icon, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feat.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                feat.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Plan Seçiciler (Yıllık vs Aylık)
            Row(
              children: [
                Expanded(
                  child: _buildPlanOption(
                    context,
                    tier: SubscriptionTier.proMonthly,
                    title: 'Aylık Plan',
                    price: '₺39,99',
                    period: '/ ay',
                    badge: null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPlanOption(
                    context,
                    tier: SubscriptionTier.proYearly,
                    title: 'Yıllık Plan',
                    price: '₺24,99',
                    period: '/ ay',
                    badge: '%37 TASARRUF',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Satın Alma Butonu (Thumb Zone - 52px yükseklik)
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            subService.isPro ? 'Planınız Zaten Aktif' : 'Evdaş Plus\'a Yükselt',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // Geri Yükle ve Koşullar Butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _handleRestore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Satın Alımları Geri Yükle',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const Text(' • ', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Şimdilik Atla',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Abonelikler dilediğiniz zaman uygulama mağazası üzerinden iptal edilebilir. Gizli ücretlendirme yoktur.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOption(
    BuildContext context, {
    required SubscriptionTier tier,
    required String title,
    required String price,
    required String period,
    required String? badge,
  }) {
    final isSelected = _selectedTier == tier;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        HapticService.light();
        setState(() => _selectedTier = tier);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.primary : theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? AppColors.primary : theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      period,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -18,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.positive,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);
    HapticService.medium();

    final success = await ref.read(subscriptionProvider.notifier).purchase(_selectedTier);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      HapticService.success();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evdaş Plus üyeliğiniz başarıyla aktif edildi!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    HapticService.light();

    final isPro = await ref.read(subscriptionProvider.notifier).restorePurchases();
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPro
              ? 'Satın alımlarınız başarıyla geri yüklendi.'
              : 'Aktif bir Evdaş Plus aboneliği bulunamadı.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
