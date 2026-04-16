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
          
          // Triple toggle inside picker to allow switching all 3 types
          SheepTripleToggle(
            selectedIndex: _selectedIndex,
            onChanged: (index) => setState(() => _selectedIndex = index),
            labels: const ["Chi tiêu", "Thu nhập", "Mục tiêu"],
          ),
          
          const SizedBox(height: 25),
          
          ValueListenableBuilder(
            valueListenable: Hive.box<CategoryModel>(kCatBox).listenable(),
            builder: (context, box, _) {
              final filteredCats = box.values
                  .where((c) => c.effectiveTypeIndex == _selectedIndex)
                  .toList();

              if (filteredCats.isEmpty) {
                String typeName = _selectedIndex == 0 ? "chi tiêu" : (_selectedIndex == 1 ? "thu nhập" : "mục tiêu");
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Chưa có danh mục $typeName nào',
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
                        color: isSelected
                            ? (c.colorValue != null ? Color(c.colorValue!) : AppColors.primary)
                            : (c.colorValue != null ? Color(c.colorValue!).withOpacity(0.12) : Colors.grey[50]),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? (c.colorValue != null ? Color(c.colorValue!) : AppColors.primary)
                              : (c.colorValue != null ? Color(c.colorValue!).withOpacity(0.3) : Colors.grey[200]!),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : (c.colorValue != null ? Color(c.colorValue!) : AppColors.textPrimary),
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
