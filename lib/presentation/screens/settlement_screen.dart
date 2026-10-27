import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/share_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/settlement_item.dart';
import '../providers/app_providers.dart';
import '../providers/customization_provider.dart';
import '../widgets/animated_rolling_number.dart';
import '../widgets/confetti_overlay.dart';

class SettlementScreen extends ConsumerWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(householdProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final debtResult = ref.watch(debtEngineResultProvider);
    final allPayments = ref.watch(paymentRequestsProvider);
    final isPrivacy = ref.watch(privacyModeProvider);

    final myBalance = (currentMember != null)
        ? (debtResult.netBalanceByMember[currentMember.id] ?? 0.0)
        : 0.0;

    final isCreditor = myBalance > 0.01;
    final isDebtor = myBalance < -0.01;
    final isSettled = !isCreditor && !isDebtor;

    // Bekleyen ödemeler (Çift taraflı onay bekleyenler)
    final pendingForMe = allPayments.where((p) =>
        p.status == PaymentStatus.pending && p.toMemberId == currentMember?.id);
    final pendingByMe = allPayments.where((p) =>
        p.status == PaymentStatus.pending && p.fromMemberId == currentMember?.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Hesaplaşma & Ödeşme',
            style: TextStyle(fontWeight: FontWeight.w700)),
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
            // 0. AYLIK HESAPLAŞMA GÜNÜ HATIRLATICI KARTI
            if (house != null) ...[
              _buildSettlementDayCard(context, house.settlementDay),
              const SizedBox(height: 14),
            ],

            // 1. ONAY BEKLEYEN ÖDEMELER KARTI (GÜVENLİK & ÇİFT TARAFLI ONAY)
            if (pendingForMe.isNotEmpty) ...[
              _buildIncomingApprovalBanner(context, ref, pendingForMe.toList()),
              const SizedBox(height: 14),
            ],

            if (pendingByMe.isNotEmpty) ...[
              _buildOutgoingPendingBanner(context, pendingByMe.toList()),
              const SizedBox(height: 14),
            ],

            // 2. NET BAKİYE DURUM KARTI
            _buildBalanceCard(context, myBalance, isCreditor, isDebtor, isSettled,
                currentMember?.displayName ?? 'Sen', isPrivacy),

            const SizedBox(height: 16),

            // 3. ÖDEŞME LİSTESİ (KISMİ VEYA TAM ÖDEME DESTEKLİ)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Ödeşme Listesi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${debtResult.settlements.length} transfer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (debtResult.settlements.isEmpty)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    SoundService.playSettlementChime();
                    ConfettiOverlay.show(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: AppColors.positive, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'Hesaplar Tamamen Denk 🎉',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Şu an kimsenin kimseye borcu bulunmuyor. Kutlamak için dokun!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...debtResult.settlements.map((s) {
                final toMember = house?.members.firstWhere(
                  (m) => m.id == s.toMemberId,
                  orElse: () => house.members.first,
                );
                final isMyDebt = s.fromMemberId == currentMember?.id;

                return _buildSettlementCard(
                  context,
                  ref,
                  s,
                  toMember?.iban,
                  isMyDebt,
                  currentMember?.id,
                  isPrivacy,
                );
              }),

            const SizedBox(height: 20),

            // 4. HESAPLAŞMA ÖZETİNİ PAYLAŞ
            ElevatedButton.icon(
              onPressed: () {
                final ibanInfo = house?.members
                    .where((m) => m.iban != null && m.iban!.trim().isNotEmpty)
                    .map((m) => '${m.displayName}: ${m.iban}')
                    .join('\n');

                ShareService.shareSettlementSummary(
                  householdName: house?.name ?? 'Ortaklığımız',
                  totalExpenses: debtResult.totalJointExpenses,
                  settlements: debtResult.settlements,
                  ibanInfo: ibanInfo,
                );
              },
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Özeti Ortaklarla Paylaş'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 24),

            // 5. ŞAHSİ BORÇLAR DETAYI
            if (debtResult.directPersonalDebts.isNotEmpty) ...[
              const Text(
                'Şahsi Borçlar Detayı (Birebir)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Bu kalemler ortak havuza bölünmeden şahıslar arasında doğrudan hesaplanmıştır.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              ...debtResult.directPersonalDebts.map((e) {
                final creditor = house?.members
                    .firstWhere((m) => m.id == e.paidByMemberId,
                        orElse: () => house.members.first)
                    .displayName;
                final debtor = house?.members
                    .firstWhere((m) => m.id == e.debtorMemberId,
                        orElse: () => house.members.first)
                    .displayName;

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEDD5),
                      child: Icon(Icons.person_outline,
                          color: AppColors.personalDebt),
                    ),
                    title: Text(e.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('$debtor ➔ $creditor'),
                    trailing: Text(
                      CurrencyFormatter.formatClean(e.amount, checkPrivacy: true),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.personalDebt,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    ),
  );
}

  /// Gelen Ödeme Bildirimi (Alacaklının Onaylama / Reddetme Kartı)
  Widget _buildIncomingApprovalBanner(
      BuildContext context, WidgetRef ref, List<PaymentRequest> requests) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF), // Soft Blue
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                : const Color(0xFF3B82F6).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_outlined,
                  color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                'Onayınızı Bekleyen Ödemeler',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...requests.map((req) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${req.fromMemberName} ➔ Sen',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.formatClean(req.amount, checkPrivacy: true),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.positive,
                          ),
                        ),
                      ],
                    ),
                    if (req.note != null && req.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Not: ${req.note}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await ref
                                .read(paymentRequestsProvider.notifier)
                                .rejectPayment(req.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Ödeme reddedildi')),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.negative,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Reddet (Gelmedi)'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            await ref
                                .read(paymentRequestsProvider.notifier)
                                .confirmPayment(req.id);
                            SoundService.playSettlementChime();
                            if (context.mounted) {
                              ConfettiOverlay.show(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Ödeme onaylandı ve borçtan düşüldü!'),
                                  backgroundColor: AppColors.positive,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.positive,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Hesaba Geçti (Onayla)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Giden Ödeme Bildirimi (Borçlunun Bekleme Durumu)
  Widget _buildOutgoingPendingBanner(
      BuildContext context, List<PaymentRequest> requests) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Amber Light
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: requests.map((req) {
                return Text(
                  '${req.toMemberName}\'ye ${CurrencyFormatter.formatClean(req.amount, checkPrivacy: true)} ödeme bildirdiniz (Onay bekleniyor)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    double myBalance,
    bool isCreditor,
    bool isDebtor,
    bool isSettled,
    String userName,
    bool isPrivacy,
  ) {
    Color cardColor;
    Color textColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (isCreditor) {
      cardColor = AppColors.positive.withValues(alpha: 0.12);
      textColor = AppColors.positive;
      statusTitle = 'Alacaklısın';
      statusSubtitle = 'Ortaklarından sana ödenecek net tutar.';
      statusIcon = Icons.arrow_downward_rounded;
    } else if (isDebtor) {
      cardColor = AppColors.negative.withValues(alpha: 0.12);
      textColor = AppColors.negative;
      statusTitle = 'Borçlusun';
      statusSubtitle = 'Ortaklarına ödemen gereken net tutar.';
      statusIcon = Icons.arrow_upward_rounded;
    } else {
      cardColor = Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface;
      textColor = AppColors.neutral;
      statusTitle = 'Hesaplar Tamamen Denk';
      statusSubtitle = 'Kimseye borcun veya alacağın bulunmuyor.';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: textColor.withValues(alpha: 0.2),
                child: Icon(statusIcon, color: textColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$userName İçin Durum',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isSettled)
            Text(
              statusTitle,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            )
          else
            AnimatedRollingNumber(
              value: myBalance.abs(),
              isMasked: isPrivacy,
              suffix: ' $statusTitle',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            statusSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(
    BuildContext context,
    WidgetRef ref,
    SettlementItem item,
    String? iban,
    bool isMyDebt,
    String? currentUserId,
    bool isPrivacy,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.fromMemberName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 16, color: AppColors.primary),
                      ),
                      Expanded(
                        child: Text(
                          item.toMemberName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    child: AnimatedRollingNumber(
                      value: item.amount,
                      isMasked: isPrivacy,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (iban != null && iban.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'IBAN: $iban',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: iban));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('IBAN panoya kopyalandı!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Kopyala',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // KISMİ VEYA TAM ÖDEME BİLDİRME BUTONU
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showPaymentDialog(context, ref, item),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text(isMyDebt
                  ? 'Ödeme Yap / Bildir (Kısmi/Tam)'
                  : '${item.fromMemberName} Adına Ödeme Gir'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kısmi veya Tam Ödeme Bildirme Dialogu
  void _showPaymentDialog(
      BuildContext context, WidgetRef ref, SettlementItem item) {
    HapticFeedback.selectionClick();
    final amountController =
        TextEditingController(text: item.amount.toStringAsFixed(2));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${item.toMemberName}\'ye Ödeme Bildir'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toplam Borç: ${CurrencyFormatter.formatClean(item.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Ödenecek Tutar (₺)',
                  hintText: 'Örn: 500 veya 1034.75',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Not (İsteğe bağlı)',
                  hintText: 'Örn: Banka havalesi / FAST yapıldı',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ödeme bildirildiğinde karşı tarafın onayına sunulur. Yalnızca her iki taraf kabul ettiğinde borçtan düşülür.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim());
              if (amt != null && amt > 0) {
                HapticFeedback.mediumImpact();
                Navigator.pop(dialogCtx);
                await ref
                    .read(paymentRequestsProvider.notifier)
                    .createPayment(
                      fromMemberId: item.fromMemberId,
                      fromMemberName: item.fromMemberName,
                      toMemberId: item.toMemberId,
                      toMemberName: item.toMemberName,
                      amount: amt,
                      note: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : null,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${CurrencyFormatter.formatClean(amt)} ödeme bildirildi! Karşı tarafın onayı bekleniyor.'),
                      backgroundColor: AppColors.positive,
                    ),
                  );
                }
              }
            },
            child: const Text('Ödeme Bildir'),
          ),
        ],
      ),
    ).then((_) {
      amountController.dispose();
      noteController.dispose();
    });
  }

  Widget _buildSettlementDayCard(BuildContext context, int settlementDay) {
    final now = DateTime.now();
    final currentDay = now.day;
    final isToday = currentDay == settlementDay;

    int daysRemaining;
    if (currentDay <= settlementDay) {
      daysRemaining = settlementDay - currentDay;
    } else {
      final nextMonth = DateTime(now.year, now.month + 1, settlementDay);
      daysRemaining = nextMonth.difference(now).inDays;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.25),
          width: isToday ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isToday ? Icons.alarm_on_rounded : Icons.calendar_today_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday
                      ? '🔔 Bugün Aylık Hesaplaşma Günü!'
                      : '📅 Aylık Hesaplaşma: Her ayın $settlementDay. günü',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isToday
                      ? 'Ortaklar arasındaki hesapları kapatma ve ödeşme vakti geldi.'
                      : (daysRemaining == 0
                          ? 'Hesaplaşma günü bugün!'
                          : '$daysRemaining gün kaldı.'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
