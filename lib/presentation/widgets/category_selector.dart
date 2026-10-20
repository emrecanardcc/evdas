import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/expense.dart';

class CategorySelector extends StatelessWidget {
  final ExpenseCategory selectedCategory;
  final Function(ExpenseCategory) onSelect;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ExpenseCategory.values.map((cat) {
          final isSelected = cat == selectedCategory;
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
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
              ),
              selectedColor: _getCategoryColor(cat),
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? _getCategoryColor(cat) : Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              onSelected: (_) => onSelect(cat),
            ),
          );
        }).toList(),
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
