import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/customization_models.dart';
import '../../core/utils/calculator_engine.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/expense.dart';
import '../../data/models/household_member.dart';
import '../../data/models/partnership.dart';
import '../providers/app_providers.dart';
import '../providers/customization_provider.dart';
import '../widgets/approval_center_modal.dart';
import '../widgets/category_selector.dart';
import '../widgets/custom_numpad.dart';
import '../widgets/instant_saved_dialog.dart';
import '../widgets/receipt_scanner_dialog.dart';

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

  // Eşit Olmayan / Ağırlıklı Bölüşüm ve Muafiyet Durumu
  bool _isCustomSplit = false;
  bool _isCustomSplitExpanded = false;
  final Map<String, double> _splitWeights = {};
  final Set<String> _excludedMemberIds = {};

  final List<({String title, ExpenseCategory category, IconData icon})>
      _smartTags = const [
    (title: 'Market', category: ExpenseCategory.market, icon: Icons.shopping_cart_outlined),
    (title: 'Fatura', category: ExpenseCategory.fatura, icon: Icons.bolt_outlined),
    (title: 'Ekmek', category: ExpenseCategory.mutfak, icon: Icons.bakery_dining_outlined),
    (title: 'Kahve', category: ExpenseCategory.mutfak, icon: Icons.coffee_outlined),
    (title: 'Ulaşım', category: ExpenseCategory.ulasim, icon: Icons.directions_car_outlined),
    (title: 'Yemek', category: ExpenseCategory.mutfak, icon: Icons.restaurant_outlined),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    setState(() {
      final lastToken = _amountStr.split(' ').last;
      if (digit == '.') {
        if (!lastToken.contains('.')) {
          if (lastToken.isEmpty) {
            _amountStr += '0.';
          } else {
            _amountStr += '.';
          }
        }
      } else {
        if (_amountStr == '0') {
          _amountStr = digit;
        } else {
          if (lastToken.contains('.')) {
            final parts = lastToken.split('.');
            if (parts.length > 1 && parts[1].length >= 2) return;
          }
          if (_amountStr.length < 24) {
            _amountStr += digit;
          }
        }
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      final trimmed = _amountStr.trim();
      if (trimmed.endsWith('+') ||
          trimmed.endsWith('-') ||
          trimmed.endsWith('×') ||
          trimmed.endsWith('÷') ||
          trimmed.endsWith('%')) {
        _amountStr = '${trimmed.substring(0, trimmed.length - 1)} $op ';
      } else {
        _amountStr = '$trimmed $op ';
      }
    });
  }

  void _onEquals() {
    final res = CalculatorEngine.evaluate(_amountStr);
    setState(() {
      _amountStr = res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(2);
    });
  }

  void _onDelete() {
    setState(() {
      final trimmed = _amountStr.trim();
      if (trimmed.length <= 1) {
        _amountStr = '0';
      } else {
        _amountStr = trimmed.substring(0, trimmed.length - 1).trim();
        if (_amountStr.isEmpty) _amountStr = '0';
      }
    });
  }

  void _onClear() {
    setState(() {
      _amountStr = '0';
    });
  }

  void _addQuickAmount(double delta) {
    HapticService.selection();
    SoundService.playNumpadTick();
    final current = CalculatorEngine.evaluate(_amountStr);
    final next = current + delta;
    setState(() {
      _amountStr = next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(2);
    });
  }

  void _roundToNearest10() {
    HapticService.selection();
    SoundService.playNumpadTick();
    final current = CalculatorEngine.evaluate(_amountStr);
    final rounded = (current / 10).round() * 10;
    setState(() {
      _amountStr = rounded.toString();
    });
  }

  void _applySmartTag(
      ({String title, ExpenseCategory category, IconData icon}) tag) {
    HapticService.selection();
    SoundService.playNumpadTick();
    setState(() {
      _titleController.text = tag.title;
      _selectedCategory = tag.category;
    });
  }

  Future<void> _saveExpense({bool shouldClose = false}) async {
    final amount = CalculatorEngine.evaluate(_amountStr);
    if (amount <= 0) {
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

    // Özel bölüşüm ağırlıklarını hazırla
    Map<String, double>? finalWeights;
    if (_selectedType == ExpenseType.joint && _isCustomSplit) {
      finalWeights = {};
      for (final m in house.members) {
        if (!_excludedMemberIds.contains(m.id)) {
          finalWeights[m.id] = _splitWeights[m.id] ?? 1.0;
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
      splitMemberWeights: finalWeights,
    );

    await ref.read(expensesProvider.notifier).addExpense(newExpense);

    HapticService.success();
    SoundService.playKaChing();

    if (!mounted) return;

    final paidByName = house.members
        .firstWhere((m) => m.id == paidBy, orElse: () => currentMember)
        .displayName;
    final debtorName = debtor != null
        ? house.members
            .firstWhere((m) => m.id == debtor, orElse: () => currentMember)
            .displayName
        : null;

    if (shouldClose) {
      // Kasa Modu Kapatma Protokolu
      if (defaultTargetPlatform == TargetPlatform.android) {
        await SystemNavigator.pop();
      } else {
        await InstantSavedDialog.show(
          context,
          amount: amount,
          title: title,
          paidByName: paidByName,
          debtorName: debtorName,
          isPersonal: isPersonal,
        );
      }
    } else {
      final message = isPersonal
          ? '${CurrencyFormatter.formatClean(amount)} şahsi borç kaydedildi ($debtorName ➔ $paidByName)'
          : '$paidByName ${CurrencyFormatter.formatClean(amount)} ortak ev masrafı kaydetti!';

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
    }

    setState(() {
      _amountStr = '0';
      _titleController.clear();
      _selectedType = ExpenseType.joint;
      _selectedCategory = ExpenseCategory.market;
      _isCustomSplit = false;
      _isCustomSplitExpanded = false;
      _splitWeights.clear();
      _excludedMemberIds.clear();
    });
  }

  Future<void> _openReceiptScanner() async {
    HapticService.light();
    final result = await ReceiptScannerDialog.show(context);
    if (result != null && result.hasValidData && mounted) {
      setState(() {
        _amountStr = result.amount!.toStringAsFixed(2).replaceAll('.00', '');
        if (result.merchantName != null && result.merchantName!.isNotEmpty) {
          _titleController.text = result.merchantName!;
        }
        if (result.suggestedCategory != null) {
          _selectedCategory = result.suggestedCategory!;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.merchantName ?? "Fiş"} verileri harcamaya aktarıldı.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(householdProvider);
    final allPartnerships = ref.watch(allPartnershipsProvider);
    final currentMember = ref.watch(currentMemberProvider);
    final pendingCount = ref.watch(pendingApprovalsCountProvider);
    final isPrivacy = ref.watch(privacyModeProvider);
    final numpadLayout = ref.watch(numpadLayoutProvider);

    final amount = CalculatorEngine.evaluate(_amountStr);
    final otherMembers = (house?.members ?? [])
        .where((m) => m.id != currentMember?.id)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
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
              ),
            );
          },
        ),
        actions: [
          // AKILLI FİŞ VE BELGE OKUYUCU
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Akıllı Fiş / Belge Oku',
            onPressed: _openReceiptScanner,
          ),
          // GİZLİ BAKİYE MODU BUTONU (Tek Tıkla •••• Maskeleme)
          IconButton(
            icon: Icon(
              isPrivacy ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: isPrivacy ? AppColors.personalDebt : null,
            ),
            tooltip: isPrivacy ? 'Bakiyeleri Göster' : 'Bakiyeleri Gizle',
            onPressed: () {
              HapticService.selection();
              ref.read(privacyModeProvider.notifier).toggle();
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
          if (currentMember != null)
            Builder(
              builder: (ctx) {
                final isNarrow = MediaQuery.sizeOf(ctx).width < 340;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, left: 4),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 6 : 10,
                        vertical: 5,
                      ),
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
                          if (!isNarrow) ...[
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 64),
                              child: Text(
                                currentMember.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
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
                      const SizedBox(height: 8),
                      _buildDebtorChips(otherMembers),
                    ],

                    const SizedBox(height: 8),

                    // Fiş Tarama Hızlı Erişim Çipi
                    Center(
                      child: ActionChip(
                        avatar: const Icon(Icons.document_scanner_rounded, size: 15, color: AppColors.primary),
                        label: const Text('Akıllı Fiş Oku', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                        onPressed: _openReceiptScanner,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // 2. TUTAR ALANI (HESAP MAKİNESİ VE GİZLİLİK DESTEKLİ)
                    isPrivacy
                        ? Text(
                            CurrencyFormatter.formatMasked(),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: _selectedType == ExpenseType.personalDebt
                                  ? AppColors.personalDebt
                                  : house.type.color,
                            ),
                          )
                        : Text(
                            CurrencyFormatter.activePlacement ==
                                    CurrencyPlacement.before
                                ? '${CurrencyFormatter.activeSymbol} ${_amountStr == '0' ? '0' : _amountStr}'
                                : '${_amountStr == '0' ? '0' : _amountStr} ${CurrencyFormatter.activeSymbol}',
                            style: TextStyle(
                              fontSize: _amountStr.length > 9 ? 30 : 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: _selectedType == ExpenseType.personalDebt
                                  ? AppColors.personalDebt
                                  : house.type.color,
                            ),
                          ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 2.0),
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

                    // 2b. AKILLI ETİKETLER (Klavye Açmadan Tek Tıkla Seçim)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _smartTags.map((tag) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ActionChip(
                              avatar: Icon(tag.icon, size: 14),
                              label: Text(tag.title),
                              labelStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 0),
                              onPressed: () => _applySmartTag(tag),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // 2c. HIZLI TUTAR ÇİPLERİ (+50, +100, +250, Yuvarla)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickAmountChip(
                              CurrencyFormatter.activePlacement == CurrencyPlacement.before
                                  ? '+${CurrencyFormatter.activeSymbol}50'
                                  : '+50 ${CurrencyFormatter.activeSymbol}',
                              () => _addQuickAmount(50)),
                          const SizedBox(width: 6),
                          _buildQuickAmountChip(
                              CurrencyFormatter.activePlacement == CurrencyPlacement.before
                                  ? '+${CurrencyFormatter.activeSymbol}100'
                                  : '+100 ${CurrencyFormatter.activeSymbol}',
                              () => _addQuickAmount(100)),
                          const SizedBox(width: 6),
                          _buildQuickAmountChip(
                              CurrencyFormatter.activePlacement == CurrencyPlacement.before
                                  ? '+${CurrencyFormatter.activeSymbol}250'
                                  : '+250 ${CurrencyFormatter.activeSymbol}',
                              () => _addQuickAmount(250)),
                          const SizedBox(width: 6),
                          _buildQuickAmountChip('En Yakın 10\'a Yuvarla',
                              _roundToNearest10, isRound: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 3. KATEGORİ SEÇİCİ
                    if (_selectedType == ExpenseType.joint) ...[
                      CategorySelector(
                        selectedCategory: _selectedCategory,
                        onSelect: (cat) => setState(() => _selectedCategory = cat),
                      ),
                      const SizedBox(height: 8),

                      // 3b. EŞİT OLMAYAN MASRAF BÖLÜŞÜMÜ (Ağırlıklı Pay & Muafiyet)
                      if (house.members.length > 1) ...[
                        _buildUnequalSplitSection(house),
                        const SizedBox(height: 8),
                      ],
                    ],

                    // 4. SAYISAL TUŞ TAKIMI (HESAP MAKİNESİ VE ATM DÜZENİ DESTEKLİ)
                    CustomNumpad(
                      onDigitPressed: _onDigit,
                      onDeletePressed: _onDelete,
                      onClearPressed: _onClear,
                      onOperatorPressed: _onOperator,
                      onEqualsPressed: _onEquals,
                      layout: numpadLayout,
                      showCalculator: true,
                    ),

                    const SizedBox(height: 12),

                    // 5. ÇİFT FONKSİYONLU KAYDET BUTONLARI (KASA MODU)
                    Row(
                      children: [
                        // Ana Buton: "Kaydet ve Kapat"
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: amount > 0
                                ? () => _saveExpense(shouldClose: true)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedType == ExpenseType.personalDebt
                                      ? AppColors.personalDebt
                                      : house.type.color,
                              disabledBackgroundColor:
                                  Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.flash_on_rounded, size: 20),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    amount > 0
                                        ? 'Kaydet ve Kapat'
                                        : 'Tutar Girin',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // İkincil Buton: "Kaydet & Devam Et"
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: amount > 0
                                ? () => _saveExpense(shouldClose: false)
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              side: BorderSide(
                                color: amount > 0
                                    ? (_selectedType == ExpenseType.personalDebt
                                        ? AppColors.personalDebt
                                        : house.type.color)
                                    : Colors.grey.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Kaydet & Devam Et',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, VoidCallback onTap, {bool isRound = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isRound
              ? AppColors.primary.withValues(alpha: 0.12)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRound
                ? AppColors.primary.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isRound ? AppColors.primary : null,
          ),
        ),
      ),
    );
  }

  Widget _buildUnequalSplitSection(Partnership house) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCustomSplit
              ? AppColors.primary.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Row(
              children: [
                Icon(
                  Icons.balance_rounded,
                  size: 16,
                  color: _isCustomSplit ? AppColors.primary : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isCustomSplit
                        ? 'Özel / Ağırlıklı Bölüşüm Aktif'
                        : 'Masraf Bölüşümü: Eşit (Tüm Ortaklar)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          _isCustomSplit ? FontWeight.w800 : FontWeight.w600,
                      color: _isCustomSplit ? AppColors.primary : null,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Icon(
              _isCustomSplitExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
            ),
            onTap: () {
              setState(() {
                _isCustomSplitExpanded = !_isCustomSplitExpanded;
              });
            },
          ),
          if (_isCustomSplitExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Özel Bölüşüm Kullan:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      Switch.adaptive(
                        value: _isCustomSplit,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _isCustomSplit = val;
                            if (val && _splitWeights.isEmpty) {
                              for (final m in house.members) {
                                _splitWeights[m.id] = 1.0;
                              }
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_isCustomSplit) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Ortakları masraftan muaf tutabilir veya pay çarpanı belirleyebilirsiniz:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...house.members.map((m) {
                      final isExcluded = _excludedMemberIds.contains(m.id);
                      final weight = _splitWeights[m.id] ?? 1.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: !isExcluded,
                              activeColor: AppColors.primary,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _excludedMemberIds.remove(m.id);
                                    _splitWeights[m.id] = 1.0;
                                  } else {
                                    if (house.members.length -
                                            _excludedMemberIds.length >
                                        1) {
                                      _excludedMemberIds.add(m.id);
                                      _splitWeights.remove(m.id);
                                    }
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                m.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isExcluded
                                      ? FontWeight.w400
                                      : FontWeight.w700,
                                  decoration: isExcluded
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (!isExcluded) ...[
                              _buildWeightChoice(m.id, 1.0, weight == 1.0),
                              const SizedBox(width: 4),
                              _buildWeightChoice(m.id, 2.0, weight == 2.0),
                              const SizedBox(width: 4),
                              _buildWeightChoice(m.id, 3.0, weight == 3.0),
                            ] else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.negative
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'MUAF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.negative,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightChoice(String memberId, double weight, bool isSelected) {
    return InkWell(
      onTap: () {
        HapticService.selection();
        setState(() {
          _splitWeights[memberId] = weight;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          '${weight.toInt()}x Pay',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : null,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : activeColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
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
          OutlinedButton(
            onPressed: () {
              HapticService.light();
              setState(() {
                _iAmCreditor = !_iAmCreditor;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.personalDebt,
              side: BorderSide(
                color: AppColors.personalDebt.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Yön Değiştir ⇄',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
            const SizedBox(height: 8),
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
                const SizedBox(height: 8),
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
    ).then((_) {
      nameController.dispose();
      creatorNameController.dispose();
      ibanController.dispose();
    });
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
    ).then((_) {
      codeController.dispose();
      nameController.dispose();
      ibanController.dispose();
    });
  }
}
