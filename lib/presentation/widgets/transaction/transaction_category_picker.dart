import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';

class TransactionCategoryPicker extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final Function(String) onCategorySelected;

  const TransactionCategoryPicker({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'SELECT CATEGORY',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 20),
          if (categories.isEmpty)
            const Center(child: Text('No categories available'))
          else
            GridView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (ctx, i) {
                final c = categories[i];
                final isSelected = selectedCategoryId == c.id;
                return GestureDetector(
                  onTap: () => onCategorySelected(c.id),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
