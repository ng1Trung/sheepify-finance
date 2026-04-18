import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import 'common/sheep_toggles.dart';
import 'common/sheep_widgets.dart';
import 'common/sheep_notifications.dart';
import '../../core/utils/l10n.dart';

class CategoryForm extends StatefulWidget {
  final CategoryModel? category;
  const CategoryForm({super.key, this.category});

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _goalAmountController = TextEditingController(); // NEW
  final _catBox = Hive.box<CategoryModel>(kCatBox);

  late int _selectedTypeIndex; // 0: expense, 1: income, 2: savings
  int _selectedGoalTypeIndex = 1; // 1: monthly, 2: short-term, 3: long-term
  int _selectedReminderDay = DateTime.now().day;
  int _selectedTargetMonth = DateTime.now().month;
  int _selectedTargetYear = DateTime.now().year + 1;
  
  DateTime? _selectedTargetDate;
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
      _selectedTypeIndex = cat.effectiveTypeIndex;
      _selectedIcon = cat.iconCode;
      _budgetController.text = cat.budget != null
          ? CurrencyUtil.formatNumber(cat.budget!)
          : '';
      _goalAmountController.text = cat.targetAmount != null
          ? CurrencyUtil.formatNumber(cat.targetAmount!)
          : '';
      _selectedTargetDate = cat.targetDate;
      _selectedGoalTypeIndex = (cat.goalTypeIndex != null && cat.goalTypeIndex != 0) ? cat.goalTypeIndex! : 1;
      _selectedReminderDay = cat.reminderDay ?? DateTime.now().day;
      _selectedTargetMonth = cat.targetMonth ?? (cat.targetDate?.month ?? DateTime.now().month);
      _selectedTargetYear = cat.targetYear ?? (cat.targetDate?.year ?? DateTime.now().year + 1);
      
      _selectedColor = cat.colorValue != null
          ? Color(cat.colorValue!)
          : _vibrantColors[0];
    } else {
      _nameController.text = '';
      _selectedTypeIndex = 0; // Default Expense
      _selectedIcon = _iconList[0].codePoint;
      _selectedColor = _vibrantColors[0];
    }
  }

  void _submit() {
    final l10n = L10n.of(context);
    if (_nameController.text.isEmpty) {
      SheepNotifications.showError(context, L10n.of(context).get('enter_cat_name'));
      return;
    }

    final enteredBudget = CurrencyParsing.parseAmount(_budgetController.text);
    final enteredGoal = CurrencyParsing.parseAmount(_goalAmountController.text);
    HapticFeedback.mediumImpact();

    if (widget.category != null) {
      final cat = widget.category!;
      cat.name = _nameController.text;
      cat.iconCode = _selectedIcon;
      cat.isExpense = _selectedTypeIndex == 0;
      cat.typeIndex = _selectedTypeIndex;
      cat.budget = _selectedTypeIndex == 0 ? enteredBudget : null;
      cat.targetAmount = _selectedTypeIndex == 2 ? enteredGoal : null;
      
      if (_selectedTypeIndex == 2) {
        cat.goalTypeIndex = _selectedGoalTypeIndex;
        if (_selectedGoalTypeIndex == 1) {
          cat.reminderDay = _selectedReminderDay;
          cat.targetMonth = null;
          cat.targetYear = null;
          cat.targetDate = null;
        } else if (_selectedGoalTypeIndex == 2) {
          // Ngắn hạn: Month + Year
          cat.reminderDay = null;
          cat.targetMonth = _selectedTargetMonth;
          cat.targetYear = _selectedTargetYear;
          cat.targetDate = DateTime(_selectedTargetYear, _selectedTargetMonth + 1, 0); // Last day of month
        } else {
          // Dài hạn: Year only
          cat.targetYear = _selectedTargetYear;
          cat.targetDate = DateTime(_selectedTargetYear, 12, 31);
          cat.targetMonth = null;
          cat.reminderDay = null;
        }
      } else {
        cat.goalTypeIndex = 0;
        cat.targetDate = null;
      }
      
      cat.colorValue = _selectedColor.value;
      cat.save();
      
      SheepNotifications.showSuccess(context, l10n.get('tx_updated'));
    } else {
      final catName = _nameController.text;
      final newCat = CategoryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: catName,
        iconCode: _selectedIcon,
        isExpense: _selectedTypeIndex == 0,
        typeIndex: _selectedTypeIndex,
        budget: _selectedTypeIndex == 0 ? enteredBudget : null,
        targetAmount: _selectedTypeIndex == 2 ? enteredGoal : null,
        goalTypeIndex: _selectedTypeIndex == 2 ? _selectedGoalTypeIndex : 0,
        reminderDay: (_selectedTypeIndex == 2 && _selectedGoalTypeIndex == 1) ? _selectedReminderDay : null,
        targetMonth: (_selectedTypeIndex == 2 && _selectedGoalTypeIndex == 2) ? _selectedTargetMonth : null,
        targetYear: (_selectedTypeIndex == 2 && (_selectedGoalTypeIndex == 2 || _selectedGoalTypeIndex == 3)) ? _selectedTargetYear : null,
        targetDate: _selectedTypeIndex == 2 
            ? (_selectedGoalTypeIndex == 2 
                ? DateTime(_selectedTargetYear, _selectedTargetMonth + 1, 0)
                : (_selectedGoalTypeIndex == 3 ? DateTime(_selectedTargetYear, 12, 31) : null))
            : null,
        colorValue: _selectedColor.value,
      );
      _catBox.add(newCat);
      
      SheepNotifications.showSuccess(context, l10n.get('tx_added'));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.getSurface(theme.brightness),
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
                    _buildHeaderPreview(l10n),
                    const SizedBox(height: 30),

                    _buildSectionTitle(l10n.get('basic_info')),
                    const SizedBox(height: 12),
                    SheepTripleToggle(
                      selectedIndex: _selectedTypeIndex,
                      onChanged: (val) => setState(() => _selectedTypeIndex = val),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _nameController,
                      hint: l10n.get('category_name'),
                      icon: LineIcons.tag,
                    ),
                    if (_selectedTypeIndex == 0) ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _budgetController,
                        hint: l10n.get('budget_monthly'),
                        icon: LineIcons.coins,
                        isNumber: true,
                        suffix: 'đ',
                      ),
                    ],
                    if (_selectedTypeIndex == 2) ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _goalAmountController,
                        hint: _selectedGoalTypeIndex == 1 ? l10n.get('goal_amount_monthly') : l10n.get('target_amount'),
                        icon: Icons.flag_outlined,
                        isNumber: true,
                        suffix: 'đ',
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle(l10n.get('goal_type')),
                      const SizedBox(height: 12),
                      _buildGoalTypeToggle(l10n),
                      const SizedBox(height: 12),
                      if (_selectedGoalTypeIndex == 1)
                        _buildReminderDayPicker(l10n)
                      else if (_selectedGoalTypeIndex == 2) ...[
                        _buildMonthPicker(l10n),
                        const SizedBox(height: 12),
                        _buildYearPicker(l10n),
                      ] else
                        _buildYearPicker(l10n),
                    ],

                    const SizedBox(height: 30),
                    _buildSectionTitle(l10n.get('colors')),
                    const SizedBox(height: 12),
                    _buildColorPicker(),

                    const SizedBox(height: 30),
                    _buildSectionTitle(l10n.get('icons')),
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
      color: AppColors.getSurface(Theme.of(context).brightness),
      child: Center(
        child: _buildDragHandle(),
      ),
    );
  }

  Widget _buildStickyFooter() {
    final l10n = L10n.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 15,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(Theme.of(context).brightness),
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
              widget.category == null ? l10n.get('create_category') : l10n.get('save_changes'),
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

  Widget _buildHeaderPreview(L10n l10n) {
    final theme = Theme.of(context);
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
                    ? l10n.get('category_name').toUpperCase()
                    : _nameController.text.toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedTypeIndex != 2 
                    ? (_budgetController.text.isEmpty ? l10n.get('no_tx_month') : '${l10n.get('budget_monthly').split('(')[0].trim()}: ${_budgetController.text}đ')
                    : (_selectedGoalTypeIndex == 1
                        ? '${l10n.get('monthly_goal_label')}: ${_goalAmountController.text.isEmpty ? '0' : _goalAmountController.text} đ'
                        : (_selectedGoalTypeIndex == 2 
                            ? '${l10n.get('target_amount')}: ${_goalAmountController.text.isEmpty ? '0' : _goalAmountController.text} đ - T${_selectedTargetMonth}/${_selectedTargetYear}'
                            : '${l10n.get('target_amount')}: ${_goalAmountController.text.isEmpty ? '0' : _goalAmountController.text} đ - ${l10n.get('year')} ${_selectedTargetYear}')),
                style: theme.textTheme.labelSmall?.copyWith(
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

  Widget _buildGoalTypeToggle(L10n l10n) {
    return Row(
      children: [
        _buildSimplifiedToggleItem(l10n.get('recurring_monthly'), _selectedGoalTypeIndex == 1, () => setState(() => _selectedGoalTypeIndex = 1)),
        const SizedBox(width: 8),
        _buildSimplifiedToggleItem(l10n.get('short_term'), _selectedGoalTypeIndex == 2, () => setState(() => _selectedGoalTypeIndex = 2)),
        const SizedBox(width: 8),
        _buildSimplifiedToggleItem(l10n.get('long_term'), _selectedGoalTypeIndex == 3, () => setState(() => _selectedGoalTypeIndex = 3)),
      ],
    );
  }

  Widget _buildSimplifiedToggleItem(String label, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.savings.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: active ? AppColors.savings : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.savings : theme.textTheme.labelSmall?.color,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderDayPicker(L10n l10n) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.get('reminder_day'), style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final day = index + 1;
              final bool active = _selectedReminderDay == day;
              return GestureDetector(
                onTap: () => setState(() => _selectedReminderDay = day),
                child: Container(
                  width: 45,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.savings : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: active ? AppColors.savings : Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: active ? Colors.white : theme.textTheme.bodyLarge?.color,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthPicker(L10n l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.get('target_month'), style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final bool active = _selectedTargetMonth == month;
              return GestureDetector(
                onTap: () => setState(() => _selectedTargetMonth = month),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.savings : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: active ? AppColors.savings : Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      '${l10n.get('month')} $month',
                      style: TextStyle(
                        color: active ? Colors.white : theme.textTheme.bodyLarge?.color,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearPicker(L10n l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.get('target_year'), 
          style: theme.textTheme.labelSmall
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 20,
            itemBuilder: (context, index) {
              final year = DateTime.now().year + index;
              final bool active = _selectedTargetYear == year;
              return GestureDetector(
                onTap: () => setState(() => _selectedTargetYear = year),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.savings : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AppColors.savings : Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      '$year',
                      style: TextStyle(
                        color: active ? Colors.white : theme.textTheme.bodyLarge?.color,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: (_) => setState(() {}),
        inputFormatters: isNumber ? [CurrencyInputFormatter()] : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: theme.primaryColor, size: 20),
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
    final theme = Theme.of(context);
    return Container(
      height: 145,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: theme.dividerColor),
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
    final theme = Theme.of(context);
    return Container(
      height: 200,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: theme.dividerColor),
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
                color: isSelected ? _selectedColor : theme.cardColor,
                shape: BoxShape.circle,
                border: isSelected ? null : Border.all(color: theme.dividerColor),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : theme.textTheme.labelSmall?.color,
                size: 20,
              ),
            ),
          );
        },
      ),
    );
  }
}
