import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/legal_texts.dart';
import '../../core/services/export_service.dart';
import '../../core/services/feedback_service.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/customization_models.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/approval_request.dart';
import '../../data/models/household_member.dart';
import '../../data/models/partnership.dart';
import '../providers/app_providers.dart';
import '../providers/customization_provider.dart';
import '../widgets/approval_center_modal.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/legal_document_modal.dart';
import 'auth_screen.dart';
import 'decision_wheel_screen.dart';

class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(householdProvider);
    final allPartnerships = ref.watch(allPartnershipsProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final debtResult = ref.watch(debtEngineResultProvider);

    final isFull = (house?.members.length ?? 0) >= Partnership.maxMembers;
    final pendingCount = ref.watch(pendingApprovalsCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              house?.displayIcon ?? Icons.home_rounded,
              size: 20,
              color: house?.displayColor ?? AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                house?.name ?? 'Ortaklık',
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            tooltip: 'Grup Kararları & Onay Merkezi',
            onPressed: () => ApprovalCenterModal.show(context),
          ),
          // Ortaklık Değiştir / Ekle Menüsü
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Ortaklık Seç / Oluştur',
            onSelected: (val) {
              if (val == 'new') {
                _showCreatePartnershipDialog(context, ref);
              } else if (val == 'join') {
                _showJoinDialog(context, ref);
              } else {
                final selected = allPartnerships.firstWhere((p) => p.id == val);
                ref.read(householdProvider.notifier).switchPartnership(selected);
              }
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'ORTAKLIKLARIN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...allPartnerships.map((p) {
                  final isCurrent = p.id == house?.id;
                  return PopupMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        Icon(p.type.icon, size: 18, color: p.type.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontWeight:
                                  isCurrent ? FontWeight.w800 : FontWeight.w500,
                              color: isCurrent ? AppColors.primary : null,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          const Icon(Icons.check, size: 16, color: AppColors.primary),
                      ],
                    ),
                  );
                }),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'new',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Yeni Ortaklık Kur',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'join',
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_outlined,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Kod ile Katıl',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış Yap',
            onPressed: () => _confirmSignOut(context),
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
        child: house == null
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildNoPartnershipView(context, ref, currentMember),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            // 1. ORTAKLIK BAŞLIĞI & KONTENJAN (Max 6 Üye)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              house.displayColor.withValues(alpha: 0.12),
                          child: Icon(
                            house.displayIcon,
                            color: house.displayColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      house.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    tooltip: 'Ortaklığı Düzenle',
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(
                                        minWidth: 40, minHeight: 40),
                                    onPressed: () => _showEditPartnershipDialog(
                                        context, ref, house),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: house.displayColor
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      house.type.displayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: house.displayColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Kapasite: ${house.members.length} / ${Partnership.maxMembers} Ortak',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isFull
                                            ? AppColors.negative
                                            : Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                      ),
                                    ),
                                  ),
                                  if (isFull) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.negative
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'DOLU',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.negative,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    // Davet Kodu Kutusu
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DAVET KODU',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      house.inviteCode,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        fontFamily: 'monospace',
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20),
                                tooltip: 'Kodu Kopyala',
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: house.inviteCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Davet kodu panoya kopyalandı!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: isFull
                                ? null
                                : () {
                                    ShareService.shareInviteCode(
                                      householdName: house.name,
                                      inviteCode: house.inviteCode,
                                    );
                                  },
                            label: Text(
                                isFull ? 'Ortaklık Dolu' : 'Davet Kodunu Paylaş'),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Aylık Ödeşme Günü Bilgilendirme Kartı
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Aylık Hesaplaşma Günü',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Her ayın ${house.settlementDay}. günü',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showEditPartnershipDialog(
                                context, ref, house),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Değiştir',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 1b. EV KARAR ÇARKI (EĞLENCELİ GÖREV DAĞITICI)
            Card(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DecisionWheelScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.casino_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    '🎯 Ev Karar Çarkı',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'EĞLENCE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Çöpü kim dökecek, bulaşığı kim yıkayacak? Çarkı çevir, şansına razı ol!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. ORTAKLAR LİSTESİ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Ortaklar',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: isFull
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Bu ortaklık maksimum kapasitesine (6/6) ulaştı!'),
                              backgroundColor: AppColors.negative,
                            ),
                          );
                        }
                      : () => _showAddMemberDialog(context, ref),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text(
                      isFull ? 'Kapasite Dolu (6/6)' : 'Yeni Ortak Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...(house.members.map((m) {
              final isCurrent = m.id == currentMember?.id;
              final spent = debtResult.jointSpentByMember[m.id] ?? 0.0;
              final balance = debtResult.netBalanceByMember[m.id] ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isCurrent
                            ? AppColors.primary
                            : const Color(0xFF64748B),
                        child: Text(
                          m.displayName.isNotEmpty
                              ? m.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    m.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Sen',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Ortak Harcaması: ${CurrencyFormatter.formatClean(spent)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                            if (m.iban != null && m.iban!.isNotEmpty)
                              Text(
                                'IBAN: ${m.iban}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            balance > 0.01
                                ? '+ ${CurrencyFormatter.formatClean(balance)}'
                                : balance < -0.01
                                    ? CurrencyFormatter.formatClean(balance)
                                    : '0 ₺',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: balance > 0.01
                                  ? AppColors.positive
                                  : balance < -0.01
                                      ? AppColors.negative
                                      : AppColors.neutral,
                            ),
                          ),
                          Text(
                            balance > 0.01
                                ? 'Alacaklı'
                                : balance < -0.01
                                    ? 'Borçlu'
                                    : 'Denk',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: balance > 0.01
                                  ? AppColors.positive
                                  : balance < -0.01
                                      ? AppColors.negative
                                      : AppColors.neutral,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            })),

            const SizedBox(height: 24),

            // 3. ORTAKLIK YÖNETİMİ VE KARARLAR (Oy Birliği Kuralları)
            Text(
              'ORTAKLIK YÖNETİMİ VE KARARLAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    title: const Text(
                      'Ortaklığı Düzenle (İsim, Renk, Simge, Tarih)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () =>
                        _showEditPartnershipDialog(context, ref, house),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.exit_to_app_rounded,
                          color: AppColors.personalDebt, size: 20),
                    ),
                    title: const Text(
                      'Ortaklıktan Ayrıl (Oy Birliği İle)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Diğer tüm ortakların onayı gerekir',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => _requestLeavePartnership(
                        context, ref, house, currentMember),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.negative.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_sweep_rounded,
                          color: AppColors.negative, size: 20),
                    ),
                    title: const Text(
                      'Ortaklığı Kapat / Sil (Oy Birliği İle)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.negative,
                      ),
                    ),
                    subtitle: const Text(
                      'Tüm ortakların oy birliği gerekir',
                      style: TextStyle(fontSize: 11, color: AppColors.negative),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.negative, size: 20),
                    onTap: () => _requestDeletePartnership(
                        context, ref, house, currentMember),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. DESTEK, YASAL BİLGİLER VE HESAP AYARLARI
            _buildSettingsSection(context, ref, house, currentMember),
          ],
        ),
      ),
    ),
  );
}

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final ibanController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Yeni Ortak Ekle (Maks. 6)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'İsim Soyisim',
                  hintText: 'Örn: Ahmet Yılmaz',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ibanController,
                decoration: const InputDecoration(
                  labelText: 'IBAN (İsteğe bağlı)',
                  hintText: 'TR...',
                ),
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
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogCtx);
                try {
                  await ref.read(householdProvider.notifier).addMember(
                        name,
                        iban: ibanController.text.trim().isNotEmpty
                            ? ibanController.text.trim()
                            : null,
                      );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.negative,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showCreatePartnershipDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final userFullName =
        SupabaseService.currentUser?.userMetadata?['full_name'] as String? ?? '';
    final creatorNameController =
        TextEditingController(text: userFullName.isNotEmpty ? userFullName : '');
    final ibanController = TextEditingController();
    PartnershipType selectedType = PartnershipType.home;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Ortaklık Kur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ortaklık Adı',
                    hintText: 'Örn: Kadıköy Evi, Yazılım Ofisi, Antalya Tatili',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                const Text('Ortaklık Türü:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: PartnershipType.values.map((t) {
                    final isSel = t == selectedType;
                    return ChoiceChip(
                      selected: isSel,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon, size: 14, color: isSel ? Colors.white : t.color),
                          const SizedBox(width: 4),
                          Text(t.displayName),
                        ],
                      ),
                      selectedColor: t.color,
                      onSelected: (_) => setDialogState(() => selectedType = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: creatorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Gruptaki İsminiz',
                    hintText: 'Örn: Adınız Soyadınız',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ibanController,
                  decoration: const InputDecoration(
                    labelText: 'IBAN (İsteğe bağlı)',
                    hintText: 'TR...',
                  ),
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
                final name = nameController.text.trim();
                final creator = creatorNameController.text.trim();
                if (name.isNotEmpty && creator.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  await ref.read(householdProvider.notifier).createNew(
                        name: name,
                        type: selectedType,
                        creatorName: creator,
                        iban: ibanController.text.trim().isNotEmpty
                            ? ibanController.text.trim()
                            : null,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name ortaklığı kuruldu!'),
                        backgroundColor: AppColors.positive,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    final userFullName =
        SupabaseService.currentUser?.userMetadata?['full_name'] as String? ?? '';
    final nameController =
        TextEditingController(text: userFullName.isNotEmpty ? userFullName : '');
    final ibanController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Kod ile Ortaklığa Katıl'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Davet Kodu',
                  hintText: 'Örn: ORTAK-7K9M-2X4V',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Gruptaki İsminiz',
                  hintText: 'Örn: Adınız Soyadınız',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ibanController,
                decoration: const InputDecoration(
                  labelText: 'IBAN (İsteğe bağlı)',
                  hintText: 'TR...',
                ),
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
              final code = codeController.text.trim();
              final name = nameController.text.trim();
              if (code.isNotEmpty && name.isNotEmpty) {
                Navigator.pop(dialogCtx);
                try {
                  await ref.read(householdProvider.notifier).joinByCode(
                        code: code,
                        userName: name,
                        iban: ibanController.text.trim().isNotEmpty
                            ? ibanController.text.trim()
                            : null,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ortaklığa başarıyla katıldınız!'),
                        backgroundColor: AppColors.positive,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.negative,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
  }

  void _showEditPartnershipDialog(
      BuildContext context, WidgetRef ref, Partnership house) {
    final nameController = TextEditingController(text: house.name);
    int settlementDay = house.settlementDay;
    int? selectedColor = house.customColor ?? house.type.color.toARGB32();
    String? selectedIcon = house.customIcon ?? 'home';

    final colorOptions = [
      0xFFF97316, // Coral
      0xFF0284C7, // Sky Blue
      0xFF10B981, // Emerald
      0xFFF59E0B, // Amber
      0xFF8B5CF6, // Purple
      0xFFEC4899, // Pink
      0xFF06B6D4, // Cyan
      0xFF64748B, // Slate
    ];

    final iconOptions = [
      {'name': 'home', 'icon': Icons.home_rounded, 'label': 'Ev'},
      {'name': 'apartment', 'icon': Icons.apartment_rounded, 'label': 'Daire'},
      {'name': 'villa', 'icon': Icons.villa_rounded, 'label': 'Villa'},
      {'name': 'business', 'icon': Icons.business_rounded, 'label': 'Ofis'},
      {'name': 'coffee', 'icon': Icons.local_cafe_rounded, 'label': 'Kafe'},
      {'name': 'flight', 'icon': Icons.flight_takeoff_rounded, 'label': 'Tatil'},
      {'name': 'beach', 'icon': Icons.beach_access_rounded, 'label': 'Seyahat'},
      {'name': 'sports', 'icon': Icons.sports_soccer_rounded, 'label': 'Spor'},
      {'name': 'game', 'icon': Icons.sports_esports_rounded, 'label': 'Oyun'},
      {'name': 'favorite', 'icon': Icons.favorite_rounded, 'label': 'Aile'},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ortaklığı Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ortaklık İsmi',
                    hintText: 'Örn: Kadıköy Evi',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Aylık Ödeşme Günü (1-28):',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: settlementDay.toDouble(),
                        min: 1,
                        max: 28,
                        divisions: 27,
                        label: 'Her ayın $settlementDay. günü',
                        onChanged: (val) {
                          setDialogState(() {
                            settlementDay = val.round();
                          });
                        },
                      ),
                    ),
                    Text('$settlementDay',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Özel Renk Seçimi:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((cVal) {
                    final isSel = selectedColor == cVal;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = cVal;
                        });
                      },
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(cVal),
                        child: isSel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Özel Simge Seçimi:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: iconOptions.map((opt) {
                    final name = opt['name'] as String;
                    final iconData = opt['icon'] as IconData;
                    final isSel = selectedIcon == name;
                    return ChoiceChip(
                      selected: isSel,
                      avatar: Icon(iconData,
                          size: 16,
                          color: isSel ? Colors.white : AppColors.primary),
                      label: Text(opt['label'] as String),
                      selectedColor: AppColors.primary,
                      onSelected: (_) {
                        setDialogState(() {
                          selectedIcon = name;
                        });
                      },
                    );
                  }).toList(),
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
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  await ref.read(householdProvider.notifier).updateDetails(
                        name: newName,
                        settlementDay: settlementDay,
                        customColor: selectedColor,
                        customIcon: selectedIcon,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ortaklık detayları güncellendi!'),
                        backgroundColor: AppColors.positive,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _requestLeavePartnership(
    BuildContext context,
    WidgetRef ref,
    Partnership house,
    HouseholdMember? currentMember,
  ) {
    if (currentMember == null) return;

    if (house.members.length <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ortaklıktan Ayrıl'),
          content: const SingleChildScrollView(
            child: Text(
                'Bu ortaklıkta tek üyesiniz. Ayrılmak ortaklığı kapatacaktır. Devam edilsin mi?'),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(householdProvider.notifier)
                    .deleteCurrentPartnership();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.negative,
                  minimumSize: const Size(0, 48)),
              child: const Text('Kapat ve Ayrıl'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.how_to_vote_rounded, color: AppColors.personalDebt),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ayrılma Talebi',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            '${house.name} ortaklığından ayrılabilmeniz için diğer tüm ortakların (${house.members.length - 1} kişi) oy birliği ile onay vermesi gerekir.\n\nOnay süreci başlatılsın mı?',
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uuid = const Uuid();
              final req = ApprovalRequest(
                id: uuid.v4(),
                partnershipId: house.id,
                type: ApprovalType.leavePartnership,
                targetId: currentMember.id,
                title: '${currentMember.displayName} Ortaklıktan Ayrılma Talebi',
                requestedByMemberId: currentMember.id,
                requestedByName: currentMember.displayName,
                approvals: [currentMember.id],
                requiredCount: house.members.length, // Oy birliği
              );

              await ref
                  .read(approvalRequestsProvider.notifier)
                  .createRequest(req);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Ayrılma talebi oluşturuldu! Diğer tüm ortakların onayı bekleniyor.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Talebi Başlat'),
          ),
        ],
      ),
    );
  }

  void _requestDeletePartnership(
    BuildContext context,
    WidgetRef ref,
    Partnership house,
    HouseholdMember? currentMember,
  ) {
    if (currentMember == null) return;

    if (house.members.length <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ortaklığı Sil'),
          content: SingleChildScrollView(
            child: Text(
                '"${house.name}" ortaklığı ve bağlı tüm kayıtlar silinecek. Emin misiniz?'),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(householdProvider.notifier)
                    .deleteCurrentPartnership();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.negative,
                  minimumSize: const Size(0, 48)),
              child: const Text('Ortaklığı Sil'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.negative),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ortaklığı Kapatma',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            '"${house.name}" ortaklığını tamamen kapatmak ve silmek için tüm ortakların (${house.members.length} kişi) 100% oy birliği gerekir.\n\nKapatma onay talebi başlatılsın mı?',
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uuid = const Uuid();
              final req = ApprovalRequest(
                id: uuid.v4(),
                partnershipId: house.id,
                type: ApprovalType.deletePartnership,
                targetId: house.id,
                title: '${house.name} Ortaklığını Kapatma ve Silme Talebi',
                requestedByMemberId: currentMember.id,
                requestedByName: currentMember.displayName,
                approvals: [currentMember.id],
                requiredCount: house.members.length, // Oy birliği
              );

              await ref
                  .read(approvalRequestsProvider.notifier)
                  .createRequest(req);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Ortaklığı kapatma talebi oluşturuldu! Tüm ortakların onayı bekleniyor.'),
                    backgroundColor: AppColors.negative,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative,
                minimumSize: const Size(0, 48)),
            child: const Text('Kapatma Talebi Başlat'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPartnershipView(
      BuildContext context, WidgetRef ref, HouseholdMember? currentMember) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.roofing_rounded,
              size: 42,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Henüz Bir Ortaklığınız Yok',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ev, ofis veya tatil masraflarını bölüşmek için yeni bir ortaklık kurun veya davet kodunuz varsa hemen katılın.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _showCreatePartnershipDialog(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text('Yeni Ortaklık Kur'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showJoinDialog(context, ref),
            icon: const Icon(Icons.vpn_key_outlined, size: 20),
            label: const Text('Davet Kodu İle Katıl'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 40),
          _buildSettingsSection(context, ref, null, currentMember),
        ],
      ),
    );
  }

  Widget _buildCustomizationSection(
      BuildContext context, WidgetRef ref, Partnership? house) {
    final theme = Theme.of(context);
    final activeTheme = ref.watch(themeModeProvider);
    final activeAccent = ref.watch(accentColorProvider);
    final activeFont = ref.watch(fontFamilyProvider);
    final activeLayout = ref.watch(numpadLayoutProvider);
    final activeCurrency = ref.watch(currencySymbolProvider);
    final activePlacement = ref.watch(currencyPlacementProvider);
    final activeDecimal = ref.watch(decimalRuleProvider);
    final isPrivacy = ref.watch(privacyModeProvider);
    final hapticLvl = ref.watch(hapticLevelProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final activePattern = ref.watch(backgroundPatternProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // GÖRÜNÜM VE ÖZELLEŞTİRME
        Text(
          'GÖRÜNÜM VE ÖZELLEŞTİRME',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tema Modu
                Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Tema Modu',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppThemeType.values.map((t) {
                    final isSel = t == activeTheme;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(t.displayName),
                      onSelected: (_) {
                        HapticService.selection();
                        ref.read(themeModeProvider.notifier).setTheme(t);
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),

                // Canlı Vurgu Rengi
                Row(
                  children: [
                    Icon(Icons.color_lens_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Vurgu Rengi (${activeAccent.displayName})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AccentColorOption.values.map((opt) {
                    final isSel = opt == activeAccent;
                    return GestureDetector(
                      onTap: () {
                        HapticService.selection();
                        ref.read(accentColorProvider.notifier).setColor(opt);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: opt.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: opt.color.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSel
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 24),

                // Tipografi
                Row(
                  children: [
                    Icon(Icons.font_download_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Tipografi (Google Fonts)',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppFontFamily.values.map((f) {
                    final isSel = f == activeFont;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(f.displayName),
                      onSelected: (_) {
                        HapticService.selection();
                        ref.read(fontFamilyProvider.notifier).setFont(f);
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),

                // Arka Plan Deseni (Grid / Dots / Mesh / Düz)
                Row(
                  children: [
                    Icon(Icons.grid_4x4_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Arka Plan Deseni (Grid / Efekt)',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: BackgroundPatternType.values.map((p) {
                    final isSel = p == activePattern;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      avatar: Icon(
                        p.icon,
                        size: 16,
                        color: isSel ? Colors.white : theme.colorScheme.primary,
                      ),
                      label: Text(p.displayName),
                      onSelected: (_) {
                        HapticService.selection();
                        ref.read(backgroundPatternProvider.notifier).setPattern(p);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // KULLANIM VE NUMPAD DÜZENİ
        Text(
          'KULLANIM VE NUMPAD DÜZENİ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Numpad Düzeni
                Row(
                  children: [
                    Icon(Icons.dialpad_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Numpad Düzeni',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: NumpadLayoutType.values.map((l) {
                    final isSel = l == activeLayout;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(l.displayName),
                      onSelected: (_) {
                        HapticService.selection();
                        ref.read(numpadLayoutProvider.notifier).setLayout(l);
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),

                // Para Birimi
                Row(
                  children: [
                    Icon(Icons.attach_money_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Para Birimi Sembolü',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: CurrencySymbol.values.map((s) {
                    final isSel = s == activeCurrency;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text('${s.symbol} ${s.displayName}'),
                      onSelected: (_) {
                        HapticService.selection();
                        ref.read(currencySymbolProvider.notifier).setSymbol(s);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Sembol Konumu
                const Text('Sembol Yerleşimi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: CurrencyPlacement.values.map((p) {
                    final isSel = p == activePlacement;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(p.displayName),
                      onSelected: (_) {
                        HapticService.selection();
                        ref.read(currencyPlacementProvider.notifier).setPlacement(p);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Ondalık Kuralı
                const Text('Ondalık Gösterimi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: DecimalRule.values.map((r) {
                    final isSel = r == activeDecimal;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(r.displayName),
                      onSelected: (_) {
                        HapticService.selection();
                        ref.read(decimalRuleProvider.notifier).setRule(r);
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),

                // Gizli Bakiye Modu
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.visibility_off_outlined,
                        color: theme.colorScheme.primary, size: 20),
                  ),
                  title: const Text('Gizli Bakiye Modu (•••• ₺)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Uygulama genelindeki tutarları maskeler',
                      style: TextStyle(fontSize: 11)),
                  value: isPrivacy,
                  onChanged: (_) {
                    HapticService.light();
                    ref.read(privacyModeProvider.notifier).toggle();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // SES VE DOKUNMATİK TİTREŞİM
        Text(
          'SES VE DOKUNMATİK TİTREŞİM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vibration_outlined, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Haptik Geri Bildirim Şiddeti',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: HapticLevel.values.map((lvl) {
                    final isSel = lvl == hapticLvl;
                    return ChoiceChip(
                      selected: isSel,
                      showCheckmark: false,
                      label: Text(lvl.displayName),
                      onSelected: (_) {
                        ref.read(hapticLevelProvider.notifier).setLevel(lvl);
                        HapticService.light();
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.volume_up_outlined,
                        color: theme.colorScheme.primary, size: 20),
                  ),
                  title: const Text('UI Ses Efektleri',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Numpad tık, Ka-Ching, çark ve ödeşme sesleri',
                      style: TextStyle(fontSize: 11)),
                  value: soundEnabled,
                  onChanged: (val) async {
                    await ref.read(soundEnabledProvider.notifier).setEnabled(val);
                    if (val) {
                      SoundService.playKaChing();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // VERİ VE DIŞA AKTARMA
        Text(
          'VERİ YÖNETİMİ VE DIŞA AKTARMA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.file_download_outlined,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text('Tüm Harcamaları CSV Olarak Dışa Aktar',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: const Text('Excel ve E-Tablolar uyumlu UTF-8 döküm',
                    style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () async {
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
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingsSection(
      BuildContext context, WidgetRef ref, Partnership? house, HouseholdMember? currentMember) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCustomizationSection(context, ref, house),

        // 1. DESTEK VE GERİ BİLDİRİM
        Text(
          'DESTEK VE GERİ BİLDİRİM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mark_email_unread_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Öneri, Hata veya Şikayet Bildir',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text(
                  FeedbackService.supportEmail,
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => FeedbackDialog.show(
                  context,
                  activePartnershipName: house?.name,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. YASAL BİLGİLER VE SÖZLEŞMELER
        Text(
          'YASAL BİLGİLER VE SÖZLEŞMELER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.gavel_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Kullanım Koşulları ve Lisans (EULA)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => LegalDocumentModal.show(
                  context,
                  title: LegalTexts.termsOfServiceTitle,
                  content: LegalTexts.termsOfService,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Gizlilik Politikası ve KVKK Aydınlatması',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text(
                  'Banka şifresi istenmez, verileriniz şifrelenir',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => LegalDocumentModal.show(
                  context,
                  title: LegalTexts.privacyPolicyTitle,
                  content: LegalTexts.privacyPolicy,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. HESAP VE GÜVENLİK
        Text(
          'HESAP VE GÜVENLİK',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Profilimi Düzenle (İsim & IBAN)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  currentMember != null
                      ? '${currentMember.displayName}${currentMember.iban != null ? ' • IBAN tanımlı' : ''}'
                      : 'Ad ve hesap bilgileri',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () =>
                    _showEditProfileDialog(context, ref, currentMember),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 20),
                ),
                title: const Text(
                  'Oturumu Kapat',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _confirmSignOut(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: AppColors.negative, size: 20),
                ),
                title: const Text(
                  'Hesabımı ve Verilerimi Kalıcı Olarak Sil',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.negative,
                  ),
                ),
                subtitle: const Text(
                  'Apple 5.1.1(v) & KVKK: Tüm kayıtları geri dönüşsüz siler',
                  style: TextStyle(fontSize: 11, color: AppColors.negative),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.negative, size: 20),
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'Evdaş v1.0.0 (Build 1)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tüm Hakları Saklıdır • Google Play & App Store Standartlarına Uygundur',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showEditProfileDialog(
      BuildContext context, WidgetRef ref, HouseholdMember? currentMember) {
    if (currentMember == null) return;

    final nameController =
        TextEditingController(text: currentMember.displayName);
    final ibanController =
        TextEditingController(text: currentMember.iban ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_pin_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Profilimi Düzenle',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diğer ev arkadaşlarınız sizi bu isimle görecektir. İsteğe bağlı olarak ortak ödeşmelerde kullanılacak IBAN bilginizi ekleyebilirsiniz.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'İsim Soyisim',
                  hintText: 'Adınız Soyadınız',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ibanController,
                decoration: const InputDecoration(
                  labelText: 'IBAN (İsteğe bağlı)',
                  hintText: 'TR...',
                ),
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
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              Navigator.pop(dialogCtx);
              final newIban = ibanController.text.trim().isNotEmpty
                  ? ibanController.text.trim()
                  : null;

              await ref.read(householdProvider.notifier).updateMemberProfile(
                    memberId: currentMember.id,
                    displayName: newName,
                    iban: newIban,
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profil bilgileriniz başarıyla güncellendi.'),
                    backgroundColor: AppColors.positive,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.negative, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hesabı Kalıcı Olarak Sil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apple App Store ve KVKK/GDPR gereksinimleri uyarınca; hesabınızı sildiğinizde:\n\n'
                '• Kişisel profil bilgileriniz ve oturumunuz,\n'
                '• Ortaklık üyelikleriniz ve kayıtlarınız,\n'
                '• Cihazınızdaki yerel veriler\n\n'
                'sunucularımızdan ve cihazınızdan geri döndürülemez biçimde kalıcı olarak silinecektir.\n\n'
                'Bu işlem kesinlikle geri alınamaz. Devam etmek istiyor musunuz?',
                style: TextStyle(fontSize: 13, height: 1.45),
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
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _showFinalDeletePrompt(context, ref);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative,
                minimumSize: const Size(0, 48)),
            child: const Text('Silmeye Devam Et'),
          ),
        ],
      ),
    );
  }

  void _showFinalDeletePrompt(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isConfirmed =
              textController.text.trim().toUpperCase() == 'SİL' ||
                  textController.text.trim().toUpperCase() == 'SIL';

          return AlertDialog(
            title: const Text(
              'Son Güvenlik Onayı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.negative,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hesabınızı ve tüm verilerinizi derhal kalıcı olarak silmek için lütfen aşağıdaki kutuya "SİL" yazın:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'SİL',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: (!isConfirmed || isDeleting)
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        try {
                          await ref
                              .read(expenseRepositoryProvider)
                              .deleteUserAccount();
                          ref.read(householdProvider.notifier).refresh();
                          ref.read(expensesProvider.notifier).refresh();
                          ref.read(paymentRequestsProvider.notifier).refresh();

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Hesabınız ve tüm verileriniz başarıyla silindi.'),
                                backgroundColor: AppColors.positive,
                              ),
                            );
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const AuthScreen()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isDeleting = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text('Silme işlemi başarısız: $e'),
                                backgroundColor: AppColors.negative,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.negative,
                    minimumSize: const Size(0, 48)),
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Hesabı Kalıcı Olarak Sil'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const SingleChildScrollView(
          child: Text('Oturumunuzu kapatmak istediğinize emin misiniz?'),
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
              Navigator.pop(dialogCtx);
              await SupabaseService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative,
                minimumSize: const Size(0, 48)),
            child: const Text('Çıkış'),
          ),
        ],
      ),
    );
  }
}
