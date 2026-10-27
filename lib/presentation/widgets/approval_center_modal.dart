import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/approval_request.dart';
import '../../data/models/household_member.dart';
import '../../data/models/payment_request.dart';
import '../providers/app_providers.dart';

class ApprovalCenterModal extends ConsumerWidget {
  const ApprovalCenterModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ApprovalCenterModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvals = ref.watch(approvalRequestsProvider);
    final payments = ref.watch(paymentRequestsProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final house = ref.watch(householdProvider);

    final pendingApprovals = approvals.where((a) => a.isPending).toList();
    final pendingPayments = payments
        .where((p) => p.status == PaymentStatus.pending)
        .toList();

    final totalMembers = house?.members.length ?? 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Tutamaç ve Başlık
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.how_to_vote_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Grup Kararları & Onay Merkezi',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Kapat',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: (pendingApprovals.isEmpty && pendingPayments.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 64,
                            color: AppColors.positive.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Tüm Kararlar Güncel!',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Onayınızı bekleyen herhangi bir harcama silme, ortaklıktan ayrılma veya ödeme bildirimi bulunmuyor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. ORTAK KARAR & SİLME TALEPLERİ
                      if (pendingApprovals.isNotEmpty) ...[
                        _buildSectionHeader(
                            context,
                            'Ortak Karar Talepleri',
                            pendingApprovals.length,
                            Icons.how_to_vote_rounded),
                        const SizedBox(height: 8),
                        ...pendingApprovals.map((req) => _buildApprovalCard(
                            context, ref, req, currentMember, totalMembers)),
                        const SizedBox(height: 16),
                      ],

                      // 2. ÖDEME VE TAHSİLAT ONAYLARI
                      if (pendingPayments.isNotEmpty) ...[
                        _buildSectionHeader(
                            context,
                            'Ödeme ve Tahsilat Onayları',
                            pendingPayments.length,
                            Icons.payments_rounded),
                        const SizedBox(height: 8),
                        ...pendingPayments.map((pay) => _buildPaymentCard(
                            context, ref, pay, currentMember)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalCard(
    BuildContext context,
    WidgetRef ref,
    ApprovalRequest req,
    HouseholdMember? currentMember,
    int totalMembers,
  ) {
    final currentId = currentMember?.id ?? '';
    final hasVoted = req.hasVoted(currentId);
    final approvedByMe = req.approvals.contains(currentId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    req.type.displayName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormatter.formatSmart(req.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              req.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Talep Eden: ${req.requestedByName}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),

            // Onay İlerlemesi (Örn: 2/3 Onaylandı)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (req.approvals.length / req.requiredCount)
                          .clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.positive),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${req.approvals.length}/${req.requiredCount} Onay',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Oy Verme Butonları veya Kullanıcının Oyu
            if (hasVoted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: (approvedByMe
                          ? AppColors.positive
                          : AppColors.negative)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      approvedByMe ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: approvedByMe ? AppColors.positive : AppColors.negative,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      approvedByMe
                          ? 'Bu talebi onayladınız'
                          : 'Bu talebi reddettiniz',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: approvedByMe
                            ? AppColors.positive
                            : AppColors.negative,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                            .read(approvalRequestsProvider.notifier)
                            .voteRequest(
                              requestId: req.id,
                              memberId: currentId,
                              approve: false,
                              totalMembersCount: totalMembers,
                            );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.negative,
                        side: const BorderSide(color: AppColors.negative),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reddet'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(approvalRequestsProvider.notifier)
                            .voteRequest(
                              requestId: req.id,
                              memberId: currentId,
                              approve: true,
                              totalMembersCount: totalMembers,
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.positive,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Onayla'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    WidgetRef ref,
    PaymentRequest pay,
    HouseholdMember? currentMember,
  ) {
    final isRecipient = currentMember?.id == pay.toMemberId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.settlement.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Ödeme Bildirimi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.settlement,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.formatClean(pay.amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.settlement,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${pay.fromMemberName} ➔ ${pay.toMemberName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            if (pay.note != null && pay.note!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Not: ${pay.note}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
            const SizedBox(height: 12),

            if (isRecipient)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                            .read(paymentRequestsProvider.notifier)
                            .rejectPayment(pay.id);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.negative,
                        side: const BorderSide(color: AppColors.negative),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Almadım / Reddet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(paymentRequestsProvider.notifier)
                            .confirmPayment(pay.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.settlement,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Ödemeyi Aldım (Onayla)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${pay.toMemberName} tarafından onay bekleniyor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
