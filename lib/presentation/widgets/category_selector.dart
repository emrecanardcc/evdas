import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/expense.dart';
import '../providers/category_provider.dart';

/// Evdaş Gerçek Hayat Frekansına Uygun ve Özelleştirilebilir Kategori Seçicisi
///
/// Sıfır emoji, keskin vektörel Material Symbols standardında üretilmiştir.
class CategorySelector extends ConsumerWidget {
  final ExpenseCategory selectedCategory;
  final Function(ExpenseCategory) onSelect;
  final String? selectedCustomCategory;
  final Function(CustomCategory)? onSelectCustom;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelect,
    this.selectedCustomCategory,
    this.onSelectCustom,
  });

  /// Günlük sık harcanan kategoriler (Kira ayda 1 kez yapıldığı için Sabit Giderler altındadır)
  static const List<ExpenseCategory> dailyCategories = [
    ExpenseCategory.market,
    ExpenseCategory.mutfak,
    ExpenseCategory.esya,
    ExpenseCategory.fatura,
    ExpenseCategory.ulasim,
    ExpenseCategory.diger,
  ];

  List<ExpenseCategory> get _visibleCategories {
    if (dailyCategories.contains(selectedCategory)) {
      return dailyCategories;
    }
    return [...dailyCategories, selectedCategory];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCategories = ref.watch(customCategoriesProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Standart Günlük Kategoriler
          ..._visibleCategories.map((cat) {
            final isSelected = cat == selectedCategory && selectedCustomCategory == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                showCheckmark: false,
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(cat),
                      size: 16,
                      color: isSelected ? Colors.white : _getCategoryColor(cat),
                    ),
                    const SizedBox(width: 6),
                    Text(cat.displayName),
                  ],
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                ),
                selectedColor: _getCategoryColor(cat),
                backgroundColor: theme.cardTheme.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? _getCategoryColor(cat) : theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                onSelected: (_) {
                  HapticService.selection();
                  onSelect(cat);
                },
              ),
            );
          }),

          // 2. Kullanıcı Tanımlı Özel Kategoriler
          ...customCategories.map((customCat) {
            final isSelected = selectedCustomCategory == customCat.name;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onLongPress: () => _confirmDeleteCategory(context, ref, customCat),
                child: FilterChip(
                  showCheckmark: false,
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        customCat.icon,
                        size: 16,
                        color: isSelected ? Colors.white : customCat.color,
                      ),
                      const SizedBox(width: 6),
                      Text(customCat.name),
                    ],
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                  ),
                  selectedColor: customCat.color,
                  backgroundColor: theme.cardTheme.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? customCat.color : theme.colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  onSelected: (_) {
                    HapticService.selection();
                    if (onSelectCustom != null) {
                      onSelectCustom!(customCat);
                    } else {
                      onSelect(ExpenseCategory.diger);
                    }
                  },
                ),
              ),
            );
          }),

          // 3. "+ Özel Kategori" Butonu
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
              label: const Text('Özel Kategori'),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.primary, width: 1),
              ),
              onPressed: () => _showAddCategoryDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    HapticService.light();
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.water_drop_rounded;
    Color selectedColor = AppColors.primary;

    final availableIcons = [
      Icons.water_drop_rounded,
      Icons.pets_rounded,
      Icons.local_cafe_rounded,
      Icons.celebration_rounded,
      Icons.fitness_center_rounded,
      Icons.wifi_rounded,
      Icons.local_gas_station_rounded,
      Icons.cleaning_services_rounded,
      Icons.build_rounded,
      Icons.sports_esports_rounded,
    ];

    final availableColors = [
      AppColors.primary,
      const Color(0xFF0284C7),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF64748B),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.paddingOf(context).bottom + 20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yeni Özel Kategori Ekle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Kategori Adı',
                      hintText: 'Örn: Damacana Su, Kedi Maması',
                      prefixIcon: Icon(selectedIcon, color: selectedColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'İkon Seçin',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableIcons.map((ic) {
                      final isSel = ic == selectedIcon;
                      return InkWell(
                        onTap: () {
                          HapticService.selection();
                          setModalState(() => selectedIcon = ic);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel ? selectedColor.withValues(alpha: 0.2) : theme.cardTheme.color,
                            border: Border.all(color: isSel ? selectedColor : theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(ic, size: 20, color: isSel ? selectedColor : null),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Renk Seçin',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableColors.map((col) {
                      final isSel = col == selectedColor;
                      return InkWell(
                        onTap: () {
                          HapticService.selection();
                          setModalState(() => selectedColor = col);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 2),
                            boxShadow: isSel ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      Navigator.of(ctx).pop();
                      final newCat = await ref.read(customCategoriesProvider.notifier).addCategory(
                            name,
                            icon: selectedIcon,
                            color: selectedColor,
                          );
                      if (onSelectCustom != null) {
                        onSelectCustom!(newCat);
                      } else {
                        onSelect(ExpenseCategory.diger);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kategoriyi Kaydet', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, CustomCategory customCat) {
    HapticService.medium();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Özel Kategoriyi Sil'),
        content: Text('"${customCat.name}" kategorisini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(customCategoriesProvider.notifier).removeCategory(customCat.id);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.negative, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.market:
        return Icons.shopping_basket_rounded;
      case ExpenseCategory.fatura:
        return Icons.bolt_rounded;
      case ExpenseCategory.kira:
        return Icons.home_rounded;
      case ExpenseCategory.mutfak:
        return Icons.restaurant_rounded;
      case ExpenseCategory.esya:
        return Icons.chair_rounded;
      case ExpenseCategory.ulasim:
        return Icons.directions_car_rounded;
      case ExpenseCategory.diger:
        return Icons.receipt_long_rounded;
    }
  }

  Color _getCategoryColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.market:
        return AppColors.categoryMarket;
      case ExpenseCategory.fatura:
        return AppColors.categoryFatura;
      case ExpenseCategory.kira:
        return AppColors.categoryKira;
      case ExpenseCategory.mutfak:
        return AppColors.categoryMutfak;
      case ExpenseCategory.esya:
        return AppColors.categoryEsya;
      case ExpenseCategory.ulasim:
        return AppColors.categoryUlasim;
      case ExpenseCategory.diger:
        return AppColors.categoryDiger;
    }
  }
}
