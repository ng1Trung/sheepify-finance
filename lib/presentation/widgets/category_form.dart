import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_model.dart';

class CategoryForm extends StatefulWidget {
  final CategoryModel? category;
  const CategoryForm({super.key, this.category});

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _catBox = Hive.box<CategoryModel>(kCatBox);

  late bool _isExpense;
  String? _selectedParentId;
  late int _selectedIcon;

  final List<IconData> _iconList = [
    Icons.fastfood,
    Icons.restaurant,
    Icons.local_cafe,
    Icons.local_bar,
    Icons.cake,
    Icons.kitchen,
    Icons.directions_car,
    Icons.motorcycle,
    Icons.directions_bus,
    Icons.flight,
    Icons.local_gas_station,
    Icons.shopping_cart,
    Icons.shopping_bag,
    Icons.checkroom,
    Icons.local_mall,
    Icons.card_giftcard,
    Icons.home,
    Icons.build,
    Icons.wifi,
    Icons.electrical_services,
    Icons.local_laundry_service,
    Icons.medical_services,
    Icons.fitness_center,
    Icons.spa,
    Icons.local_pharmacy,
    Icons.movie,
    Icons.sports_esports,
    Icons.school,
    Icons.book,
    Icons.music_note,
    Icons.attach_money,
    Icons.savings,
    Icons.work,
    Icons.pets,
    Icons.child_friendly,
    Icons.category,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      final cat = widget.category!;
      _nameController.text = cat.name;
      _isExpense = cat.isExpense;
      _selectedIcon = cat.iconCode;
      _selectedParentId = cat.parentId;
      _budgetController.text =
          cat.budget != null ? cat.budget!.toStringAsFixed(0) : '';
    } else {
      _nameController.text = '';
      _isExpense = true;
      _selectedIcon = _iconList[0].codePoint;
      _selectedParentId = null;

      final parents = _catBox.values
          .where((c) => c.parentId == null && c.isExpense == _isExpense)
          .toList();
      if (parents.isNotEmpty) _selectedParentId = parents.first.id;
    }
  }

  void _submit() {
    final enteredBudget = double.tryParse(_budgetController.text);

    if (widget.category != null) {
      final cat = widget.category!;
      cat.name = _nameController.text;
      cat.iconCode = _selectedIcon;
      cat.budget = enteredBudget;
      cat.save();
    } else {
      final newCat = CategoryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        iconCode: _selectedIcon,
        isExpense: _isExpense,
        parentId: _selectedParentId == 'new_group' ? null : _selectedParentId,
        budget: enteredBudget,
      );
      _catBox.add(newCat);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final parents = _catBox.values
        .where((c) => c.parentId == null && c.isExpense == _isExpense)
        .toList();

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              widget.category == null ? 'Tạo danh mục' : 'Sửa danh mục',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),

          if (widget.category == null) ...[
            Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeToggleItem("Chi", _isExpense, AppColors.expense),
                  ),
                  Expanded(
                    child: _buildTypeToggleItem("Thu", !_isExpense, AppColors.income),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
          ],

          const Text('Tên danh mục:',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Nhập tên...',
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (_isExpense) ...[
            const Text(
              'Ngân sách dự kiến (vnđ):',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(LineIcons.coins, size: 20),
                suffixText: 'đ',
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (widget.category == null || widget.category!.parentId != null) ...[
            const Text('Thuộc nhóm:',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.category == null)
                  _buildGroupChip(
                    id: 'new_group',
                    name: '+ Nhóm mới',
                    isSelected:
                        _selectedParentId == 'new_group' || _selectedParentId == null,
                    isSpecial: true,
                  ),
                ...parents.map(
                  (p) => _buildGroupChip(
                    id: p.id,
                    name: p.name,
                    isSelected: _selectedParentId == p.id,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          const Text('Biểu tượng:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _iconList.length,
              itemBuilder: (context, index) {
                final icon = _iconList[index];
                final isSelected = _selectedIcon == icon.codePoint;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon.codePoint),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : Colors.grey[700],
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                widget.category == null ? 'TẠO MỚI' : 'LƯU THAY ĐỔI',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggleItem(String title, bool isActive, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpense = (title == "Chi");
          _selectedParentId = null;
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? color : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupChip({
    required String id,
    required String name,
    required bool isSelected,
    bool isSpecial = false,
  }) {
    return FilterChip(
      label: Text(name),
      selected: isSelected,
      onSelected: (val) {
        setState(() => _selectedParentId = val ? id : null);
      },
      showCheckmark: false,
      selectedColor:
          isSpecial ? Colors.blue[50] : AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected
            ? (isSpecial ? Colors.blue : AppColors.primary)
            : Colors.grey[700],
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? (isSpecial ? Colors.blue : AppColors.primary)
              : Colors.transparent,
        ),
      ),
    );
  }
}
