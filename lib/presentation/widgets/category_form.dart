import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter/services.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import 'common/sheep_toggles.dart';
import 'common/sheep_widgets.dart';
import 'common/sheep_notifications.dart';

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

  final List<Color> _vibrantColors = [
    const Color(0xFFFF6B6B), // Coral Red
    const Color(0xFF4ECDC4), // Medium Turquoise
    const Color(0xFF45B7D1), // Sky Blue
    const Color(0xFF96CEB4), // Muted Green
    const Color(0xFFFFD93D), // Sun Yellow
    const Color(0xFFD4A5A5), // Dusty Rose
    const Color(0xFF9B59B6), // Amethyst
    const Color(0xFF2ECC71), // Emerald
    const Color(0xFF3498DB), // Peter River Blue
    const Color(0xFFE67E22), // Carrot
    const Color(0xFF1ABC9C), // Turquoise
    const Color(0xFFF39C12), // Orange
    const Color(0xFFEE5253), // Armor
    const Color(0xFF0FB9B1), // Turquoise 2
    const Color(0xFFFA8231), // Orange 2
    const Color(0xFF8854D0), // Gloomy Purple
    const Color(0xFF45AAF2), // High Blue
    const Color(0xFFEB3B5A), // Desire
    const Color(0xFF26DE81), // Algae Green
    const Color(0xFFF7B731), // Orange Yellow
    const Color(0xFF20C997), // Mint
    const Color(0xFFA55EEA), // Lavender
    const Color(0xFF778CA3), // Blue Grey
    const Color(0xFFFD9644), // Orange 3
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
          ? CurrencyUtil.formatNumber(cat.budget!)
          : '';
      _selectedColor = cat.colorValue != null
          ? Color(cat.colorValue!)
          : _vibrantColors[0];
    } else {
      _nameController.text = '';
      _isExpense = true;
      _selectedIcon = _iconList[0].codePoint;
      _selectedColor = _vibrantColors[0];
    }
  }

  void _submit() {
    if (_nameController.text.isEmpty) {
      SheepNotifications.showError(context, 'Vui lòng nhập tên danh mục!');
      return;
    }

    final enteredBudget = CurrencyParsing.parseAmount(_budgetController.text);
    HapticFeedback.mediumImpact();

    if (widget.category != null) {
      final cat = widget.category!;
      cat.name = _nameController.text;
      cat.iconCode = _selectedIcon;
      cat.isExpense = _isExpense;
      cat.budget = enteredBudget;
      cat.colorValue = _selectedColor.value;
      cat.save();
      
      SheepNotifications.showSuccess(context, 'Đã cập nhật danh mục "${cat.name}"');
    } else {
      final catName = _nameController.text;
      final newCat = CategoryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: catName,
        iconCode: _selectedIcon,
        isExpense: _isExpense,
        budget: enteredBudget,
        colorValue: _selectedColor.value,
      );
      _catBox.add(newCat);
      
      SheepNotifications.showSuccess(context, 'Đã tạo danh mục "$catName"');
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Column(
          children: [
            _buildStickyHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderPreview(),
                    const SizedBox(height: 30),

                    _buildSectionTitle('Thông tin cơ bản'),
                    const SizedBox(height: 12),
                    SheepTypeToggle(
                      isExpense: _isExpense,
                      leftLabel: "Chi phí",
                      rightLabel: "Thu nhập",
                      onChanged: (val) => setState(() => _isExpense = val),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Tên danh mục',
                      icon: LineIcons.tag,
                    ),
                    if (_isExpense) ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _budgetController,
                        hint: 'Ngân sách hàng tháng (Tùy chọn)',
                        icon: LineIcons.coins,
                        isNumber: true,
                        suffix: 'đ',
                      ),
                    ],

                    const SizedBox(height: 30),
                    _buildSectionTitle('Màu sắc'),
                    const SizedBox(height: 12),
                    _buildColorPicker(),

                    const SizedBox(height: 30),
                    _buildSectionTitle('Biểu tượng'),
                    const SizedBox(height: 12),
                    _buildIconPicker(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            _buildStickyFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: AppColors.surface,
      child: Center(
        child: _buildDragHandle(),
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 15,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _submit,
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _selectedColor,
                _selectedColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _selectedColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.category == null ? 'TẠO DANH MỤC' : 'LƯU THAY ĐỔI',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 15,
              ),
            ),
          ),
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
                    ? 'TÊN DANH MỤC'
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
                    ? 'Không có ngân sách'
                    : 'Ngân sách: ${_budgetController.text}đ',
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
        inputFormatters: isNumber ? [CurrencyInputFormatter()] : null,
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
    return Container(
      height: 145,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: _vibrantColors.length,
        itemBuilder: (ctx, i) {
          final color = _vibrantColors[i];
          final isSelected = _selectedColor.value == color.value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedColor = color);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected ? _selectedColor : Colors.white,
                shape: BoxShape.circle,
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
