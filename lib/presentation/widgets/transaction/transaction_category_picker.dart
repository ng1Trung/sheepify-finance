import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/l10n.dart';
import '../common/sheep_toggles.dart';
import '../common/sheep_widgets.dart';

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
  State<TransactionCategoryPicker> createState() =>
      _TransactionCategoryPickerState();
}

class _TransactionCategoryPickerState extends State<TransactionCategoryPicker> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Initialize based on the first category's type or fallback to 0
    if (widget.categories.isNotEmpty) {
      _selectedIndex = widget.categories.first.effectiveTypeIndex;
    } else {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final fallbackSelectedColor = AppColors.getInteractiveAccent(
      theme.brightness,
      AppColors.primary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: SheepSpacing.xl,
        horizontal: SheepSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(theme.brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.get('choose_category'),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: SheepSpacing.lg),

          // Triple toggle inside picker to allow switching all 3 types
          SheepTripleToggle(
            selectedIndex: _selectedIndex,
            onChanged: (index) => setState(() => _selectedIndex = index),
            labels: [l10n.expense, l10n.income, l10n.get('goal_label')],
          ),

          const SizedBox(height: SheepSpacing.xl),

          ValueListenableBuilder(
            valueListenable: Hive.box<CategoryModel>(kCatBox).listenable(),
            builder: (context, box, _) {
              final filteredCats = box.values
                  .where((c) => c.effectiveTypeIndex == _selectedIndex)
                  .toList();

              if (filteredCats.isEmpty) {
                String typeName = _selectedIndex == 0
                    ? l10n.get('expense_lower')
                    : (_selectedIndex == 1
                          ? l10n.get('income_lower')
                          : l10n.get('goal_lower'));
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      l10n.get('no_category_type', params: {'type': typeName}),
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
                  final categoryColor = c.colorValue != null
                      ? Color(c.colorValue!)
                      : null;
                  final selectedColor = categoryColor ?? fallbackSelectedColor;
                  final selectedTextColor = selectedColor.computeLuminance() >
                          0.45
                      ? Colors.black
                      : Colors.white;
                  return GestureDetector(
                    onTap: () => widget.onCategorySelected(c.id),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor
                            : (categoryColor != null
                                  ? categoryColor.withOpacity(0.12)
                                  : theme.cardColor),
                        borderRadius: BorderRadius.circular(SheepRadius.lg),
                        border: Border.all(
                          color: isSelected
                              ? selectedColor
                              : (categoryColor != null
                                    ? categoryColor.withOpacity(0.3)
                                    : AppColors.getBorder(theme.brightness)),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SheepCategoryIcon(
                            icon: c.iconData,
                            color: isSelected
                                ? selectedTextColor
                                : selectedColor,
                            size: 28,
                          ),
                          const SizedBox(width: SheepSpacing.sm),
                          Flexible(
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: SheepTypeScale.meta,
                                color: isSelected
                                    ? selectedTextColor
                                    : (categoryColor != null
                                          ? categoryColor
                                          : theme.textTheme.bodyLarge?.color),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: SheepSpacing.xxl),
        ],
      ),
    );
  }
}
