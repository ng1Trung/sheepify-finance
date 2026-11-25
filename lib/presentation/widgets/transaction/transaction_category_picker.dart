import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/l10n.dart';
import '../common/sheep_toggles.dart';
import '../common/sheep_widgets.dart';
import '../common/sheep_kit.dart';

class TransactionCategoryPicker extends StatefulWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final Function(String) onCategorySelected;

  /// Type tab to open on (0 expense, 1 income, 2 savings). Falls back to the
  /// first category's type when omitted.
  final int? initialTypeIndex;

  const TransactionCategoryPicker({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.initialTypeIndex,
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
    if (widget.initialTypeIndex != null) {
      _selectedIndex = widget.initialTypeIndex!;
    } else if (widget.categories.isNotEmpty) {
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
      padding: const EdgeInsets.fromLTRB(
        SheepSpacing.lg,
        SheepSpacing.sm + 2,
        SheepSpacing.lg,
        SheepSpacing.lg,
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
          const SheepDragHandle(),
          const SizedBox(height: SheepSpacing.lg),
          Text(
            l10n.get('choose_category'),
            style: SheepTextStyles.sheetTitle(context),
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
                      style: SheepTextStyles.itemMeta(context),
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
                  childAspectRatio: 2.4,
                ),
                itemBuilder: (ctx, i) {
                  final c = filteredCats[i];
                  final isSelected = widget.selectedCategoryId == c.id;
                  final categoryColor = c.colorValue != null
                      ? Color(c.colorValue!)
                      : fallbackSelectedColor;
                  final brightness = theme.brightness;
                  final fg = isSelected
                      ? AppColors.getOnPrimaryFill(brightness)
                      : AppColors.getTextPrimary(brightness);
                  return Material(
                    color: isSelected
                        ? AppColors.getPrimaryFill(brightness)
                        : AppColors.getSurface(brightness),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SheepRadius.lg),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : AppColors.getBorder(brightness),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(SheepRadius.lg),
                      onTap: () => widget.onCategorySelected(c.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SheepCategoryIcon(
                              icon: c.iconData,
                              color: categoryColor,
                              size: 30,
                              imagePath: c.imagePath,
                              backgroundColor: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : null,
                            ),
                            const SizedBox(width: SheepSpacing.sm),
                            Expanded(
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: SheepTextStyles.itemTitle(context)
                                    .copyWith(
                                      fontSize: SheepTypeScale.label,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: fg,
                                    ),
                              ),
                            ),
                          ],
                        ),
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
