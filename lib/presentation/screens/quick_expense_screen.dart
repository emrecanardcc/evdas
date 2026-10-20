import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_member.dart';
import '../../data/models/partnership.dart';
import '../providers/app_providers.dart';
import '../widgets/approval_center_modal.dart';
import '../widgets/category_selector.dart';
import '../widgets/custom_numpad.dart';

class QuickExpenseScreen extends ConsumerStatefulWidget {
  const QuickExpenseScreen({super.key});

  @override
  ConsumerState<QuickExpenseScreen> createState() => _QuickExpenseScreenState();
}

class _QuickExpenseScreenState extends ConsumerState<QuickExpenseScreen> {
  String _amountStr = '0';
  ExpenseType _selectedType = ExpenseType.joint;
  ExpenseCategory _selectedCategory = ExpenseCategory.market;
  final TextEditingController _titleController = TextEditingController();
  final _uuid = const Uuid();

  String? _debtorMemberId;
  bool _iAmCreditor = true;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    setState(() {
      if (digit == '.') {
        if (!_amountStr.contains('.')) {
          _amountStr += '.';
        }
      } else {
        if (_amountStr == '0') {
          _amountStr = digit;
        } else {
          if (_amountStr.contains('.')) {
            final parts = _amountStr.split('.');
            if (parts.length > 1 && parts[1].length >= 2) return;
          }
          if (_amountStr.length < 9) {
            _amountStr += digit;
          }
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_amountStr.length <= 1) {
        _amountStr = '0';
      } else {
        _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _amountStr = '0';
    });
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir tutar girin.'),
          backgroundColor: AppColors.negative,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final house = ref.read(householdProvider);
    final currentMember = ref.read(currentMemberProvider);

    if (house == null || currentMember == null) return;

    final isPersonal = _selectedType == ExpenseType.personalDebt;

    if (isPersonal && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen şahsi borç için bir açıklama girin.'),
          backgroundColor: AppColors.negative,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _selectedCategory.displayName;

    String paidBy = currentMember.id;
    String? debtor;

    if (isPersonal) {
      final otherMembers =
          house.members.where((m) => m.id != currentMember.id).toList();
      if (otherMembers.isNotEmpty) {
        final targetMemberId = _debtorMemberId ?? otherMembers.first.id;
        if (_iAmCreditor) {
          paidBy = currentMember.id;
          debtor = targetMemberId;
        } else {
          paidBy = targetMemberId;
          debtor = currentMember.id;
        }
      }
    }

    final newExpense = Expense(
      id: _uuid.v4(),
      householdId: house.id,
      title: title,
      amount: amount,
      type: _selectedType,
      category: isPersonal ? ExpenseCategory.diger : _selectedCategory,
      paidByMemberId: paidBy,
      debtorMemberId: debtor,
      expenseDate: DateTime.now(),
    );

    await ref.read(expensesProvider.notifier).addExpense(newExpense);

    HapticFeedback.mediumImpact();

    if (!mounted) return;

    final paidByName = house.members
        .firstWhere((m) => m.id == paidBy, orElse: () => currentMember)
        .displayName;
    final debtorName = debtor != null
        ? house.members
            .firstWhere((m) => m.id == debtor, orElse: () => currentMember)
            .displayName
        : null;

    final message = isPersonal
        ? '🔔 ${CurrencyFormatter.formatClean(amount)} şahsi borç kaydedildi ($debtorName ➔ $paidByName)'
        : '🔔 $paidByName ${CurrencyFormatter.formatClean(amount)} ortak ev masrafı kaydetti!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor:
            isPersonal ? AppColors.personalDebt : AppColors.positive,
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    setState(() {
      _amountStr = '0';
      _titleController.clear();
      _selectedType = ExpenseType.joint;
      _selectedCategory = ExpenseCategory.market;
    });
  }

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(householdProvider);
    final allPartnerships = ref.watch(allPartnershipsProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final pendingCount = ref.watch(pendingApprovalsCountProvider);
    final amount = double.tryParse(_amountStr) ?? 0.0;
    final otherMembers = (house?.members ?? [])
        .where((m) => m.id != currentMember?.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<String>(
          tooltip: 'Ortaklık Değiştir',
          onSelected: (pId) {
            final target = allPartnerships.firstWhere((p) => p.id == pId);
            ref.read(householdProvider.notifier).switchPartnership(target);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                house?.type.icon ?? Icons.home_rounded,
                size: 18,
                color: house?.type.color ?? AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  house?.name ?? 'Evdaş',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
          itemBuilder: (context) {
            return allPartnerships.map((p) {
              final isSel = p.id == house?.id;
              return PopupMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Icon(p.type.icon, size: 18, color: p.type.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                          color: isSel ? AppColors.primary : null,
                        ),
                      ),
                    ),
                    if (isSel)
                      const Icon(Icons.check, size: 16, color: AppColors.primary),
                  ],
                ),
              );
            }).toList();
          },
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
          if (currentMember != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          currentMember.displayName.isNotEmpty
                              ? currentMember.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentMember.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: house == null
            ? _buildNoPartnershipEmptyState(context)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                physics: const BouncingScrollPhysics(),
                child: Column(
            children: [
              const SizedBox(height: 8),

              // 1. TÜR SEÇİCİ (Ortak Masraf vs Şahsi Borç)
              _buildTypeSelector(otherMembers.isNotEmpty),

              if (_selectedType == ExpenseType.personalDebt &&
                  otherMembers.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildPersonalDebtDirection(otherMembers),
                const SizedBox(height: 10),
                _buildDebtorChips(otherMembers),
              ],

              const SizedBox(height: 12),

              // 2. TUTAR ALANI
              Text(
                '₺ ${_amountStr == '0' ? '0' : _amountStr}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: _selectedType == ExpenseType.personalDebt
                      ? AppColors.personalDebt
                      : house.type.color,
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32.0, vertical: 2.0),
                child: TextField(
                  controller: _titleController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: _selectedType == ExpenseType.personalDebt
                        ? 'Şahsi Borç Açıklaması (Zorunlu, ör: Sinema, Nakit Borç)'
                        : 'Açıklama (opsiyonel, ör: ${_selectedCategory.displayName})',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),

              const SizedBox(height: 8),

              // 3. KATEGORİ SEÇİCİ (Sadece Ortak Masraflar için - Şahsi borçta tür olmaz)
              if (_selectedType == ExpenseType.joint) ...[
                CategorySelector(
                  selectedCategory: _selectedCategory,
                  onSelect: (cat) => setState(() => _selectedCategory = cat),
                ),
                const SizedBox(height: 10),
              ],

              // 4. SAYISAL TUŞ TAKIMI
              CustomNumpad(
                onDigitPressed: _onDigit,
                onDeletePressed: _onDelete,
                onClearPressed: _onClear,
              ),

              const SizedBox(height: 12),

              // 5. KAYDET BUTONU
              ElevatedButton(
                onPressed: amount > 0 ? _saveExpense : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType == ExpenseType.personalDebt
                      ? AppColors.personalDebt
                      : house.type.color,
                  disabledBackgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      amount > 0
                          ? 'Kaydet (${CurrencyFormatter.formatClean(amount)})'
                          : 'Tutar Girin',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool hasMultipleMembers) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTypePill(
              title: 'Ortak Masraf',
              subtitle: 'Eşit bölünür',
              icon: Icons.people_alt_rounded,
              isSelected: _selectedType == ExpenseType.joint,
              activeColor: AppColors.jointExpense,
              onTap: () => setState(() => _selectedType = ExpenseType.joint),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Opacity(
              opacity: hasMultipleMembers ? 1.0 : 0.5,
              child: _buildTypePill(
                title: 'Şahsi Borç',
                subtitle: hasMultipleMembers
                    ? '1\'e 1 direkt borç'
                    : 'En az 2 üye gerekir',
                icon: hasMultipleMembers
                    ? Icons.person_rounded
                    : Icons.lock_outline_rounded,
                isSelected: _selectedType == ExpenseType.personalDebt,
                activeColor: AppColors.personalDebt,
                onTap: () {
                  if (!hasMultipleMembers) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Şahsi borç kaydı için ortaklıkta en az 2 kişi olmalıdır.'),
                        backgroundColor: AppColors.negative,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  setState(() => _selectedType = ExpenseType.personalDebt);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtorChips(List<HouseholdMember> otherMembers) {
    final selectedId = _debtorMemberId ?? otherMembers.first.id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 16, color: AppColors.personalDebt),
              const SizedBox(width: 6),
              Text(
                _iAmCreditor
                    ? 'Kime borç verdiniz?'
                    : 'Kimden borç aldınız?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.personalDebt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: otherMembers.map((m) {
              final isSelected = m.id == selectedId;
              return ChoiceChip(
                selected: isSelected,
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: isSelected
                      ? Colors.white
                      : AppColors.personalDebt.withValues(alpha: 0.15),
                  child: Text(
                    m.displayName.isNotEmpty
                        ? m.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.personalDebt
                          : AppColors.personalDebt,
                    ),
                  ),
                ),
                label: Text(m.displayName),
                selectedColor: AppColors.personalDebt,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : null,
                ),
                onSelected: (_) {
                  setState(() {
                    _debtorMemberId = m.id;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : activeColor,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white70
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDebtDirection(List<HouseholdMember> otherMembers) {
    final other = otherMembers.firstWhere(
      (m) => m.id == _debtorMemberId,
      orElse: () => otherMembers.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.personalDebt.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.personalDebt.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.personalDebt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _iAmCreditor
                  ? '${other.displayName} bana şahsi borçlandı'
                  : 'Ben ${other.displayName}\'ye şahsi borçlandım',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.personalDebt,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _iAmCreditor = !_iAmCreditor;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Yön Değiştir ⇄',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPartnershipEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hızlı Harcama Girmek İçin Ortaklık Seçin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Masraf ekleyebilmek için lütfen önce yeni bir ortaklık kurun veya davet kodunuzla bir eve katılın.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreatePartnershipDialog(context),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text('Yeni Ortaklık Kur'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showJoinDialog(context),
              icon: const Icon(Icons.vpn_key_outlined, size: 20),
              label: const Text('Davet Kodu İle Katıl'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePartnershipDialog(BuildContext context) {
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
                    hintText: 'Örn: Kadıköy Evi, Yazılım Ofisi',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                const Text('Ortaklık Türü:',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                          Icon(t.icon,
                              size: 14, color: isSel ? Colors.white : t.color),
                          const SizedBox(width: 4),
                          Text(t.displayName),
                        ],
                      ),
                      selectedColor: t.color,
                      onSelected: (_) =>
                          setDialogState(() => selectedType = t),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
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
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
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
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
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
                        content:
                            Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.negative,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
  }
}
