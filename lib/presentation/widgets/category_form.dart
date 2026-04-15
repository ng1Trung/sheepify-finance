import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter/services.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../core/theme/app_colors.dart';
import 'common/sheep_toggles.dart';
import 'common/sheep_widgets.dart';

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
  late Color _selectedColor;

  final List<Color> _pastelColors = [
    const Color(0xFFFFB7B2), // Pastel Pink
    const Color(0xFFFFDAC1), // Pastel Orange
    const Color(0xFFE2F0CB), // Pastel Yellow
    const Color(0xFFB5EAD7), // Pastel Green
    const Color(0xFFC7CEEA), // Pastel Purple
    const Color(0xFFF9D5E5), // Soft Rose
    const Color(0xFFE0BBE4), // Lavender
    const Color(0xFFAEC6CF), // Pastel Blue
    const Color(0xFF77DD77), // Pastel Green 2
    const Color(0xFFFF9AA2), // Soft Red
    const Color(0xFFC7F9CC), // Mint
    const Color(0xFFFFE5D9), // Peach
  ];

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
      _budgetController.text = cat.budget != null
          ? cat.budget!.toStringAsFixed(0)
          : '';
      _selectedColor = cat.colorValue != null
          ? Color(cat.colorValue!)
          : _pastelColors[0];
    } else {
      _nameController.text = '';
      _isExpense = true;
      _selectedIcon = _iconList[0].codePoint;
      _selectedColor = _pastelColors[0];
    }
  }

  void _submit() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter category name!'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final enteredBudget = double.tryParse(_budgetController.text);
    HapticFeedback.mediumImpact();

    if (widget.category != null) {
      final cat = widget.category!;
      cat.name = _nameController.text;
      cat.iconCode = _selectedIcon;
      cat.isExpense = _isExpense;
      cat.budget = enteredBudget;
      cat.colorValue = _selectedColor.value;
      cat.save();
    } else {
      final newCat = CategoryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        iconCode: _selectedIcon,
        isExpense: _isExpense,
        budget: enteredBudget,
        colorValue: _selectedColor.value,
      );
      _catBox.add(newCat);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildDragHandle()),
            const SizedBox(height: 25),

            _buildHeaderPreview(),
            const SizedBox(height: 30),

            _buildSectionTitle('Basic Information'),
            const SizedBox(height: 12),
            SheepTypeToggle(
              isExpense: _isExpense,
              leftLabel: "Expense",
              rightLabel: "Income",
              onChanged: (val) => setState(() => _isExpense = val),
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _nameController,
              hint: 'Category Name',
              icon: LineIcons.tag,
            ),
            if (_isExpense) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _budgetController,
                hint: 'Monthly Budget (Optional)',
                icon: LineIcons.coins,
                isNumber: true,
                suffix: 'đ',
              ),
            ],

            const SizedBox(height: 30),
            _buildSectionTitle('Color'),
            const SizedBox(height: 12),
            _buildColorPicker(),

            const SizedBox(height: 30),
            _buildSectionTitle('Icon'),
            const SizedBox(height: 12),
            _buildIconPicker(),

            const SizedBox(height: 30),
            SheepButton(
              label: widget.category == null
                  ? 'CREATE CATEGORY'
                  : 'SAVE CHANGES',
              onPressed: _submit,
              isFullWidth: true,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeaderPreview() {
    return Row(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: _selectedColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: _selectedColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            IconData(_selectedIcon, fontFamily: 'MaterialIcons'),
            color: _selectedColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameController.text.isEmpty
                    ? 'CATEGORY NAME'
                    : _nameController.text.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _budgetController.text.isEmpty
                    ? 'No monthly budget'
                    : 'Budget: ${_budgetController.text}đ',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixText: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pastelColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final color = _pastelColors[i];
          final isSelected = _selectedColor.value == color.value;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.grey[800]! : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconPicker() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: _iconList.length,
        itemBuilder: (context, index) {
          final icon = _iconList[index];
          final isSelected = _selectedIcon == icon.codePoint;
          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = icon.codePoint),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? _selectedColor : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _selectedColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : AppColors.softShadow,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 20,
              ),
            ),
          );
        },
      ),
    );
  }
}
