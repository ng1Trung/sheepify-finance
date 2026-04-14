import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../core/constants/constants.dart';
import '../common/sheep_toggles.dart';

class TransactionCategoryPicker extends StatefulWidget {
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
  State<TransactionCategoryPicker> createState() => _TransactionCategoryPickerState();
}

class _TransactionCategoryPickerState extends State<TransactionCategoryPicker> {
  late bool _isExpense;

  @override
  void initState() {
    super.initState();
    // Use widget.categories to determine initial state if possible
    _isExpense = widget.categories.isEmpty || widget.categories.first.isExpense;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SELECT CATEGORY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              )
            ],
          ),
          const SizedBox(height: 15),
          
          // Toggle inside picker to allow switching types
          SheepTypeToggle(
            isExpense: _isExpense,
            leftLabel: "Expense",
            rightLabel: "Income",
            onChanged: (val) => setState(() => _isExpense = val),
          ),
          
          const SizedBox(height: 25),
          
          ValueListenableBuilder(
            valueListenable: Hive.box<CategoryModel>(kCatBox).listenable(),
            builder: (context, box, _) {
              final filteredCats = box.values
                  .where((c) => c.isExpense == _isExpense)
                  .toList();

              if (filteredCats.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No ${_isExpense ? "expense" : "income"} categories yet',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCats.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.2,
                ),
                itemBuilder: (ctx, i) {
                  final c = filteredCats[i];
                  final isSelected = widget.selectedCategoryId == c.id;
                  return GestureDetector(
                    onTap: () => widget.onCategorySelected(c.id),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
