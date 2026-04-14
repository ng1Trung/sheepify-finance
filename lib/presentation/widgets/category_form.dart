import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import 'common/sheep_toggles.dart';

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
      _budgetController.text =
          cat.budget != null ? cat.budget!.toStringAsFixed(0) : '';
    } else {
      _nameController.text = '';
      _isExpense = true;
      _selectedIcon = _iconList[0].codePoint;
    }
  }

  void _submit() {
    final enteredBudget = double.tryParse(_budgetController.text);

    if (widget.category != null) {
      final cat = widget.category!;
      cat.name = _nameController.text;
      cat.iconCode = _selectedIcon;
      cat.isExpense = _isExpense;
      cat.budget = enteredBudget;
      cat.save();
    } else {
      final newCat = CategoryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        iconCode: _selectedIcon,
        isExpense: _isExpense,
        budget: enteredBudget,
      );
      _catBox.add(newCat);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
              widget.category == null ? 'Create Category' : 'Edit Category',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),

          // Type Toggle
          SheepTypeToggle(
            isExpense: _isExpense,
            leftLabel: "Expense",
            rightLabel: "Income",
            onChanged: (val) => setState(() => _isExpense = val),
          ),
          const SizedBox(height: 25),

          const Text('Category Name:',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Enter name...',
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
              'Planned Budget (VND):',
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

          const Text('Icon:', style: TextStyle(color: Colors.grey)),
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
                widget.category == null ? 'CREATE NEW' : 'SAVE CHANGES',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
