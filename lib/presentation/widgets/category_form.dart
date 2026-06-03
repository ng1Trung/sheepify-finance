import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  final int? fixedTypeIndex;

  const CategoryForm({super.key, this.category, this.fixedTypeIndex});

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
  String? _activePicker;

  DateTime? _selectedTargetDate;
  late int _selectedIcon;
  late Color _selectedColor;

  final List<Color> _vibrantColors = [
    Colors.black, // Màu đen hệ thống làm mặc định
    const Color(0xFF374151),
    const Color(0xFF6B7280),
    const Color(0xFF94A3B8),
    const Color(0xFF8B5E3C),
    const Color(0xFFB91C1C),
    const Color(0xFFEF4444),
    const Color(0xFFFB7185),
    const Color(0xFFF97316),
    const Color(0xFFFB923C),
    const Color(0xFFF59E0B),
    const Color(0xFFFACC15),
    const Color(0xFFA3E635),
    const Color(0xFF65A30D),
    const Color(0xFF22C55E),
    const Color(0xFF10B981),
    const Color(0xFF0F766E),
    const Color(0xFF14B8A6),
    const Color(0xFF06B6D4),
    const Color(0xFF0EA5E9),
    const Color(0xFF3B82F6),
    const Color(0xFF1D4ED8),
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFFA855F7),
    const Color(0xFFD946EF),
    const Color(0xFFEC4899),
    const Color(0xFFF472B6),
    const Color(0xFFBE123C),
    const Color(0xFF7C3AED),
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
      _selectedTypeIndex = widget.fixedTypeIndex ?? cat.effectiveTypeIndex;
      _selectedIcon = cat.iconCode;
      final budget = cat.budget;
      _budgetController.text = budget != null && budget > 0
          ? CurrencyUtil.formatNumber(budget)
          : '';
      _goalAmountController.text = cat.targetAmount != null
          ? CurrencyUtil.formatNumber(cat.targetAmount!)
          : '';
      _selectedTargetDate = cat.targetDate;
      // Merge 2 (short-term) and 3 (long-term) into 2 (Goal)
      int gType = cat.goalTypeIndex ?? 1;
      _selectedGoalTypeIndex = (gType == 3) ? 2 : (gType == 0 ? 1 : gType);

      _selectedReminderDay = cat.reminderDay ?? DateTime.now().day;
      _selectedTargetMonth =
          cat.targetMonth ?? (cat.targetDate?.month ?? DateTime.now().month);
      _selectedTargetYear =
          cat.targetYear ?? (cat.targetDate?.year ?? DateTime.now().year + 1);

      _selectedColor = cat.colorValue != null
          ? Color(cat.colorValue!)
          : _vibrantColors[0];
    } else {
      _nameController.text = '';
      _selectedTypeIndex = widget.fixedTypeIndex ?? 0; // Default Expense
      _selectedIcon = _iconList[0].codePoint;
      _selectedColor = _vibrantColors[0];

      // Default for goals
      _selectedTargetMonth = DateTime.now().month;
      _selectedTargetYear = DateTime.now().year + 1;
    }
  }

  void _submit() {
    final l10n = L10n.of(context);
    if (_nameController.text.isEmpty) {
      SheepNotifications.showError(
        context,
        L10n.of(context).get('enter_cat_name'),
      );
      return;
    }

    final parsedBudget = _budgetController.text.trim().isEmpty
        ? null
        : CurrencyParsing.parseAmount(_budgetController.text);
    final enteredBudget = parsedBudget != null && parsedBudget > 0
        ? parsedBudget
        : null;
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
        } else {
          // Mục tiêu (combined): Month + Year
          cat.reminderDay = null;
          cat.targetMonth = _selectedTargetMonth;
          cat.targetYear = _selectedTargetYear;
          cat.targetDate = DateTime(
            _selectedTargetYear,
            _selectedTargetMonth + 1,
            0,
          ); // Last day of month
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
        reminderDay: (_selectedTypeIndex == 2 && _selectedGoalTypeIndex == 1)
            ? _selectedReminderDay
            : null,
        targetMonth: (_selectedTypeIndex == 2 && _selectedGoalTypeIndex == 2)
            ? _selectedTargetMonth
            : null,
        targetYear: (_selectedTypeIndex == 2 && _selectedGoalTypeIndex == 2)
            ? _selectedTargetYear
            : null,
        targetDate: (_selectedTypeIndex == 2 && _selectedGoalTypeIndex == 2)
            ? DateTime(_selectedTargetYear, _selectedTargetMonth + 1, 0)
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
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
                    const SizedBox(height: SheepSpacing.xxl),

                    if (widget.fixedTypeIndex == null) ...[
                      SheepTripleToggle(
                        selectedIndex: _selectedTypeIndex,
                        labels: [l10n.expense, l10n.income],
                        onChanged: (val) =>
                            setState(() => _selectedTypeIndex = val),
                      ),
                      const SizedBox(height: SheepSpacing.xl),
                    ],
                    if (_selectedTypeIndex == 0) ...[
                      _buildTextField(
                        controller: _budgetController,
                        hint: l10n.get('budget_monthly'),
                        icon: LineIcons.coins,
                        isNumber: true,
                        suffix: 'đ',
                      ),
                    ],
                    if (_selectedTypeIndex == 2) ...[
                      _buildGoalTypeToggle(l10n),
                      const SizedBox(height: SheepSpacing.xl),
                      _buildTextField(
                        controller: _goalAmountController,
                        hint: _selectedGoalTypeIndex == 1
                            ? l10n.get('goal_amount')
                            : l10n.get('target_amount'),
                        icon: Icons.flag_outlined,
                        isNumber: true,
                        suffix: 'đ',
                      ),
                      const SizedBox(height: SheepSpacing.lg),
                      if (_selectedGoalTypeIndex == 1)
                        _buildReminderDayPicker(l10n)
                      else
                        _buildGoalDatePicker(l10n),
                    ],

                    if (_selectedTypeIndex != 1)
                      const SizedBox(height: SheepSpacing.lg),
                    _buildColorPicker(),
                    const SizedBox(height: SheepSpacing.xxl),
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
      padding: const EdgeInsets.symmetric(vertical: SheepSpacing.xl),
      color: AppColors.getSurface(Theme.of(context).brightness),
      child: Center(child: _buildDragHandle()),
    );
  }

  Widget _buildStickyFooter() {
    final l10n = L10n.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: SheepSpacing.xl,
        right: SheepSpacing.xl,
        top: SheepSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.xl,
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
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: SheepButton(
          label: widget.category == null
              ? (_selectedTypeIndex == 2
                    ? l10n.get('create_savings')
                    : l10n.get('create_category'))
              : l10n.get('save_changes'),
          onPressed: _submit,
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
        borderRadius: BorderRadius.circular(SheepRadius.sm),
      ),
    );
  }

  Widget _buildHeaderPreview(L10n l10n) {
    final theme = Theme.of(context);
    final accent = _effectiveSelectedColor(context);
    return Row(
      children: [
        InkWell(
          onTap: _showIconPicker,
          borderRadius: BorderRadius.circular(SheepRadius.md),
          child: SheepCategoryIcon(
            icon: IconData(_selectedIcon, fontFamily: 'MaterialIcons'),
            color: accent,
            size: 48,
          ),
        ),
        const SizedBox(width: SheepSpacing.xl),
        Expanded(
          child: TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 1,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: widget.category == null
                  ? (_selectedTypeIndex == 2
                        ? l10n.get('new_savings')
                        : l10n.get('new_category'))
                  : l10n.get('category_name'),
              hintStyle: theme.textTheme.titleLarge?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalTypeToggle(L10n l10n) {
    return SheepTripleToggle(
      selectedIndex: _selectedGoalTypeIndex == 1 ? 0 : 1,
      labels: [l10n.recurringMonthly, l10n.goal],
      onChanged: (index) {
        setState(() => _selectedGoalTypeIndex = index == 0 ? 1 : 2);
      },
    );
  }

  Widget _buildReminderDayPicker(L10n l10n) {
    return _buildPickerField(
      label: l10n.get(
        'day_of_month',
        params: {'day': _selectedReminderDay.toString()},
      ),
      pickerId: 'reminder-day',
      onTap: () => _openPicker('reminder-day', () => _showDayPicker(l10n)),
    );
  }

  Future<void> _showDayPicker(L10n l10n) async {
    final theme = Theme.of(context);
    final dayController = FixedExtentScrollController(
      initialItem: _selectedReminderDay - 1,
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(SheepSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.getSurface(theme.brightness),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SheepRadius.sheet),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            const SizedBox(height: SheepSpacing.xl),
            Text(
              l10n.get('reminder_day').toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(height: SheepSpacing.xxl),
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                scrollController: dayController,
                itemExtent: 45,
                onSelectedItemChanged: (index) {
                  setState(() => _selectedReminderDay = index + 1);
                },
                children: List.generate(
                  31,
                  (i) => Center(
                    child: Text(
                      '${l10n.get('day')} ${i + 1}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: SheepSpacing.xxl),
            SheepButton(
              label: l10n.confirm,
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: SheepSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalDatePicker(L10n l10n) {
    final monthLabel = l10n.locale.languageCode == 'vi'
        ? 'Tháng ${_selectedTargetMonth.toString().padLeft(2, '0')}'
        : DateFormat.MMMM(
            l10n.locale.languageCode,
          ).format(DateTime(2024, _selectedTargetMonth));

    return _buildPickerField(
      label: '$monthLabel, $_selectedTargetYear',
      pickerId: 'target-date',
      onTap: () => _openPicker('target-date', () => _showMonthYearPicker(l10n)),
    );
  }

  Widget _buildPickerField({
    required String label,
    required String pickerId,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isActive = _activePicker == pickerId;
    final accent = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SheepRadius.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(theme.brightness).withOpacity(0.5),
          borderRadius: BorderRadius.circular(SheepRadius.xl),
          border: Border.all(
            color: isActive ? accent : AppColors.getBorder(theme.brightness),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(LineIcons.calendar, color: theme.hintColor, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: SheepTypeScale.item,
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, color: theme.hintColor),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(
    String pickerId,
    Future<void> Function() openPicker,
  ) async {
    setState(() => _activePicker = pickerId);
    await openPicker();
    if (mounted) setState(() => _activePicker = null);
  }

  Future<void> _showMonthYearPicker(L10n l10n) async {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final years = List.generate(2100 - now.year + 1, (i) => now.year + i);

    // Initial scroll positions
    final monthController = FixedExtentScrollController(
      initialItem: _selectedTargetMonth - 1,
    );
    final yearController = FixedExtentScrollController(
      initialItem: years.indexOf(_selectedTargetYear),
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPickerState) {
          // Initialize local selection state
          int tempMonth = _selectedTargetMonth;
          int tempYear = _selectedTargetYear;

          // Search current year index
          int yearIndex = years.indexOf(tempYear);
          if (yearIndex == -1) yearIndex = 0;

          // Duration calculation (re-calculate on every build)
          int totalMonths =
              (tempYear - now.year) * 12 + (tempMonth - now.month);
          if (totalMonths < 0) totalMonths = 0;

          return Container(
            padding: const EdgeInsets.all(SheepSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.getSurface(theme.brightness),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SheepRadius.sheet),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDragHandle(),
                const SizedBox(height: SheepSpacing.xl),
                Text(
                  l10n.get('target_date').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: SheepSpacing.xxl),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      // Month Column
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: monthController,
                          itemExtent: 45,
                          onSelectedItemChanged: (index) {
                            int m = index + 1;
                            // Validation: avoid past months
                            if (tempYear == now.year && m < now.month) {
                              monthController.animateToItem(
                                now.month - 1,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.ease,
                              );
                              m = now.month;
                            }
                            setState(() => _selectedTargetMonth = m);
                            setPickerState(
                              () {},
                            ); // Refresh local UI (duration text)
                          },
                          children: List.generate(12, (i) {
                            final m = i + 1;
                            final isPast =
                                tempYear == now.year && m < now.month;
                            return Center(
                              child: Text(
                                l10n.locale.languageCode == 'vi'
                                    ? 'Tháng ${m.toString().padLeft(2, '0')}'
                                    : DateFormat.MMMM(
                                        l10n.locale.languageCode,
                                      ).format(DateTime(2024, m)),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: isPast ? Colors.grey[300] : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Year Column
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: yearController,
                          itemExtent: 45,
                          onSelectedItemChanged: (index) {
                            int y = years[index];
                            int m = tempMonth;
                            // Validation: if year is current, ensures month is not past
                            if (y == now.year && m < now.month) {
                              monthController.animateToItem(
                                now.month - 1,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.ease,
                              );
                              m = now.month;
                            }
                            setState(() {
                              _selectedTargetYear = y;
                              _selectedTargetMonth = m;
                            });
                            setPickerState(() {}); // Refresh local UI
                          },
                          children: years
                              .map(
                                (y) => Center(
                                  child: Text(
                                    '$y',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SheepSpacing.xl),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.savings.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(SheepRadius.lg),
                  ),
                  child: Text(
                    l10n.get(
                      'goal_duration_months',
                      params: {'count': totalMonths.toString()},
                    ),
                    style: TextStyle(
                      color: AppColors.savings,
                      fontWeight: FontWeight.bold,
                      fontSize: SheepTypeScale.label,
                    ),
                  ),
                ),
                const SizedBox(height: SheepSpacing.xxl),
                SheepButton(
                  label: l10n.confirm,
                  onPressed: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: SheepSpacing.sm),
              ],
            ),
          );
        },
      ),
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
    final accent = _effectiveSelectedColor(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.getSurface(theme.brightness).withOpacity(0.5),
        borderRadius: BorderRadius.circular(SheepRadius.xl),
        border: Border.all(color: AppColors.getBorder(theme.brightness)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: (_) => setState(() {}),
        inputFormatters: isNumber ? [CurrencyInputFormatter()] : null,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: SheepTypeScale.item,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.hintColor.withOpacity(0.4),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, color: accent.withOpacity(0.8), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixText: suffix,
          suffixStyle: TextStyle(color: theme.hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(SheepRadius.xl),
        border: Border.all(color: theme.dividerColor),
      ),
      child: GridView.count(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: _vibrantColors.map((color) {
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
                border:
                    color == Colors.black && theme.brightness == Brightness.dark
                    ? Border.all(color: AppColors.getBorder(theme.brightness))
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showIconPicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 360,
        padding: const EdgeInsets.all(SheepSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.getSurface(theme.brightness),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SheepRadius.sheet),
          ),
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            const SizedBox(height: SheepSpacing.xl),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: SheepSpacing.md,
                  mainAxisSpacing: SheepSpacing.md,
                ),
                itemCount: _iconList.length,
                itemBuilder: (context, index) {
                  final icon = _iconList[index];
                  final isSelected = _selectedIcon == icon.codePoint;
                  final accent = _effectiveSelectedColor(context);
                  final onAccent = AppColors.getOnAccent(
                    theme.brightness,
                    accent,
                  );
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIcon = icon.codePoint);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? accent : theme.cardColor,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? null
                            : Border.all(color: theme.dividerColor),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? onAccent
                            : theme.textTheme.labelSmall?.color,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _effectiveSelectedColor(BuildContext context) {
    return AppColors.getInteractiveAccent(
      Theme.of(context).brightness,
      _selectedColor,
    );
  }
}
