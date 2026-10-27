import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/export_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/approval_request.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_member.dart';
import '../providers/app_providers.dart';
import '../providers/customization_provider.dart';
import '../widgets/approval_center_modal.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _filter = 'all'; // 'all', 'joint', 'personal', 'settlement'
  final _uuid = const Uuid();

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final house = ref.watch(householdProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final pendingCount = ref.watch(pendingApprovalsCountProvider);
    // Watch privacyMode to trigger rebuild on toggle
    ref.watch(privacyModeProvider);

    // TEK GECISTE (O(N)) FILTRELEME VE SAYAC HESAPLAMA
    int jointCount = 0;
    int personalCount = 0;
    int settlementCount = 0;
    final List<Expense> filtered = [];

    for (final e in expenses) {
      if (e.type == ExpenseType.joint) jointCount++;
      if (e.type == ExpenseType.personalDebt) personalCount++;
      if (e.type == ExpenseType.settlement) settlementCount++;

      if (_filter == 'joint') {
        if (e.type == ExpenseType.joint) filtered.add(e);
      } else if (_filter == 'personal') {
        if (e.type == ExpenseType.personalDebt) filtered.add(e);
      } else if (_filter == 'settlement') {
        if (e.type == ExpenseType.settlement) filtered.add(e);
      } else {
        filtered.add(e);
      }
    }

    // O(1) UYE HARITASI
    final Map<String, String> memberNameMap = {
      for (final m in house?.members ?? <HouseholdMember>[]) m.id: m.displayName,
    };
    final defaultMemberName = house?.members.isNotEmpty == true
        ? house!.members.first.displayName
        : 'Biri';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Harcama Geçmişi',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Harcamaları CSV Dışa Aktar',
            onPressed: () async {
              if (expenses.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dışa aktarılacak harcama bulunamadı.')),
                );
                return;
              }
              await ExportService.exportExpensesToCsv(
                expenses: filtered.isNotEmpty ? filtered : expenses,
                members: house?.members ?? [],
                householdName: house?.name ?? 'Evdaş Ortaklığı',
              );
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            tooltip: 'Grup Kararları & Onay Merkezi',
            onPressed: () => ApprovalCenterModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () {
              ref.read(expensesProvider.notifier).refresh();
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
        child: Column(
          children: [
            // Filtre Butonları
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildFilterChip('all', 'Tümü (${expenses.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('joint', 'Ortak ($jointCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('personal', 'Şahsi ($personalCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('settlement', 'Ödeşme ($settlementCount)'),
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Kayıtlı harcama bulunamadı',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final paidBy =
                            memberNameMap[item.paidByMemberId] ?? defaultMemberName;
                        final debtor = item.debtorMemberId != null
                            ? memberNameMap[item.debtorMemberId]
                            : null;

                        return RepaintBoundary(
                          child: _buildExpenseCard(
                              item, paidBy, debtor, currentMember, house?.members.length ?? 1),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      showCheckmark: false,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildExpenseCard(
    Expense item,
    String paidByName,
    String? debtorName,
    HouseholdMember? currentMember,
    int totalMembersCount,
  ) {
    final isJoint = item.type == ExpenseType.joint;
    final isSettlement = item.type == ExpenseType.settlement;

    final typeColor = isSettlement
        ? AppColors.settlement
        : isJoint
            ? AppColors.jointExpense
            : AppColors.personalDebt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isUltraNarrow = constraints.maxWidth < 310;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Kategori / Tip İkonu
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSettlement
                            ? Icons.check_circle_rounded
                            : isJoint
                                ? Icons.people_alt_rounded
                                : Icons.person_rounded,
                        color: typeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Başlık ve Açıklamalar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isJoint
                                      ? 'Ortak Masraf'
                                      : isSettlement
                                          ? 'Ödeşme'
                                          : 'Şahsi ($debtorName ➔ $paidByName)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              if (item.splitMemberWeights != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.purple.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Özel Bölüşüm',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              Text(
                                '• ${DateFormatter.formatSmart(item.expenseDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Tutar ve Silme Butonu
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isUltraNarrow ? 80 : 100),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatClean(item.amount, checkPrivacy: true),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Harcayan: $paidByName',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 2),

                    // Silme / Ortak Karar Butonu
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                        item.isDeletionPending
                            ? Icons.hourglass_top_rounded
                            : Icons.delete_outline_rounded,
                        size: 18,
                        color: item.isDeletionPending
                            ? AppColors.personalDebt
                            : Colors.grey.shade400,
                      ),
                      tooltip: item.isDeletionPending
                          ? 'Silme Onayı Bekleniyor'
                          : 'Ortak Kararla Sil',
                      onPressed: item.isDeletionPending
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Bu harcama için silme onayı süreci zaten başlatılmış.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          : () => _requestExpenseDeletion(
                              item, currentMember, totalMembersCount),
                    ),
                  ],
                );
              },
            ),

            // Rozetler: Çevrimdışı veya Silme Onayı Bekliyor
            if (item.isPendingSync || item.isDeletionPending) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.isPendingSync)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (MediaQuery.sizeOf(context).width - 80).clamp(100.0, 300.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                size: 13, color: Colors.amber.shade900),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Çevrimdışı (Bağlanınca Eşitlenecek)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (item.isDeletionPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.negative.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.negative.withValues(alpha: 0.4)),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (MediaQuery.sizeOf(context).width - 80).clamp(100.0, 300.0),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.how_to_vote_rounded,
                                size: 13, color: AppColors.negative),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Ortak Silme Onayı Bekliyor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.negative,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _requestExpenseDeletion(
    Expense item,
    HouseholdMember? currentMember,
    int totalMembersCount,
  ) {
    if (totalMembersCount <= 1) {
      // Tek kişilik evde doğrudan silinebilir
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          title: const Text('Harcamayı Sil'),
          content: SingleChildScrollView(
            child: Text(
                '"${item.title}" (${CurrencyFormatter.formatClean(item.amount)}) silinecek. Emin misiniz?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(expensesProvider.notifier).deleteExpense(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Harcama silindi.'),
                    backgroundColor: AppColors.positive,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Sil'),
            ),
          ],
        ),
      );
      return;
    }

    // Ortak karar gerektiren durum
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        title: const Row(
          children: [
            Icon(Icons.how_to_vote_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ortak Kararla Silme',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            '"${item.title}" (${CurrencyFormatter.formatClean(item.amount)}) masrafını silmek için evdekilerin onayı gerekir.\n\nSilme onay talebi oluşturulsun mu?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final requester = currentMember?.displayName ?? 'Ortak';
              final requesterId = currentMember?.id ?? '';

              final req = ApprovalRequest(
                id: _uuid.v4(),
                partnershipId: item.householdId,
                type: ApprovalType.expenseDelete,
                targetId: item.id,
                title: '${item.title} (${CurrencyFormatter.formatClean(item.amount)}) Harcamasını Silme',
                requestedByMemberId: requesterId,
                requestedByName: requester,
                approvals: [requesterId], // Talep eden otomatik kabul etmiş sayılır
                requiredCount: item.type == ExpenseType.personalDebt
                    ? 1 // Şahsi borçta diğer tarafın onayı yeterli
                    : ((totalMembersCount / 2).ceil()), // Ortak harcamada çoğunluk
                metadata: {
                  'amount': item.amount,
                  'expense_title': item.title,
                },
              );

              await ref
                  .read(approvalRequestsProvider.notifier)
                  .createRequest(req);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Silme onay talebi oluşturuldu! Diğer ortakların onayı bekleniyor.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Onay Talebi Oluştur'),
          ),
        ],
      ),
    );
  }
}
