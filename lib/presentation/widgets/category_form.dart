import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_cropper/image_cropper.dart' as cropper;
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_image_store.dart';
import '../../core/utils/category_icon_resolver.dart';
import '../../core/utils/currency_util.dart';
import 'common/sheep_toggles.dart';
import 'common/sheep_widgets.dart';
import 'common/sheep_notifications.dart';
import 'common/sheep_dialogs.dart';
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

  late int _selectedIcon;
  late Color _selectedColor;
  String? _selectedImagePath;
  final Set<String> _createdImageRefs = {};
  bool _didSubmit = false;

  final List<Color> _vibrantColors = [
    Colors.black, // Màu đen hệ thống làm mặc định
    const Color(0xFF374151),
    const Color(0xFF6B7280),
    const Color(0xFF94A3B8),
    const Color(0xFF8B5E3C),
    const Color(0xFFB91C1C),
    const Color(0xFFEE6055), // AppColors.expense
    const Color(0xFFFB7185),
    const Color(0xFFF97316),
    const Color(0xFFFB923C),
    const Color(0xFFF59E0B),
    const Color(0xFFFACC15),
    const Color(0xFFA3E635),
    const Color(0xFF65A30D),
    const Color(0xFF22C55E),
    const Color(0xFF20C997), // AppColors.income
    const Color(0xFF0F766E),
    const Color(0xFF14B8A6),
    const Color(0xFF06B6D4),
    const Color(0xFF4EA8DE), // AppColors.savings
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
      _selectedImagePath = cat.imagePath;
      final budget = cat.budget;
      _budgetController.text = budget != null && budget > 0
          ? CurrencyUtil.formatNumber(budget)
          : '';
      _goalAmountController.text = cat.targetAmount != null
          ? CurrencyUtil.formatNumber(cat.targetAmount!)
          : '';
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
      _selectedImagePath = null;
      _selectedColor = _vibrantColors[0];

      // Default for goals
      _selectedTargetMonth = DateTime.now().month;
      _selectedTargetYear = DateTime.now().year + 1;
    }
  }

  Future<void> _submit() async {
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
    _didSubmit = true;

    if (widget.category != null) {
      final cat = widget.category!;
      final oldImagePath = cat.imagePath;
      cat.name = _nameController.text;
      cat.iconCode = _selectedIcon;
      cat.imagePath = _selectedImagePath;
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

      cat.colorValue = _selectedColor.toARGB32();
      await cat.save();
      if (oldImagePath != _selectedImagePath) {
        await CategoryImageStore.deleteStoredRef(oldImagePath);
      }
      await _deleteUnusedCreatedImages();

      if (!mounted) return;
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
        colorValue: _selectedColor.toARGB32(),
        imagePath: _selectedImagePath,
      );
      await _catBox.add(newCat);
      await _deleteUnusedCreatedImages();

      if (!mounted) return;
      SheepNotifications.showSuccess(context, l10n.get('tx_added'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    if (!_didSubmit) {
      for (final imageRef in _createdImageRefs) {
        CategoryImageStore.deleteStoredRef(imageRef);
      }
    }
    _nameController.dispose();
    _budgetController.dispose();
    _goalAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.getSurface(theme.brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: SheepSpacing.page,
                ),
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
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          l10n.get('budget_spending'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextSecondary(theme.brightness),
                          ),
                        ),
                      ),
                      _buildTextField(
                        controller: _budgetController,
                        hint: l10n.get('budget_monthly'),
                        icon: LineIcons.coins,
                        isNumber: true,
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
        left: SheepSpacing.page,
        right: SheepSpacing.page,
        top: SheepSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(Theme.of(context).brightness),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
          onTap: _handleImageTap,
          borderRadius: BorderRadius.circular(SheepRadius.md),
          child: SheepCategoryIcon(
            icon: resolveCategoryIcon(_selectedIcon),
            color: accent,
            size: 48,
            imagePath: _selectedImagePath,
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
          color: AppColors.getSurface(theme.brightness).withValues(alpha: 0.5),
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
    FocusManager.instance.primaryFocus?.unfocus();
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
                    color: AppColors.savings.withValues(alpha: 0.1),
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
        color: AppColors.getSurface(theme.brightness).withValues(alpha: 0.5),
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
            color: theme.hintColor.withValues(alpha: 0.4),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, color: accent.withValues(alpha: 0.8), size: 20),
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

  List<Color> get _displayColors {
    final list = List<Color>.from(_vibrantColors);
    final hasSelected = list.any((c) => c.toARGB32() == _selectedColor.toARGB32());
    if (!hasSelected) {
      list.add(_selectedColor);
    }
    return list;
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
        children: _displayColors.map((color) {
          final isSelected = _selectedColor.toARGB32() == color.toARGB32();
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedColor = color);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: isSelected
                  ? Matrix4.diagonal3Values(0.85, 0.85, 1.0)
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: (color == Colors.black && theme.brightness == Brightness.dark)
                    ? Border.all(color: AppColors.getBorder(theme.brightness))
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: ThemeData.estimateBrightnessForColor(color) == Brightness.light
                          ? Colors.black87
                          : Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showVisualPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPickerState) {
          final accent = _effectiveSelectedColor(context);
          return Container(
            height: 520,
            padding: const EdgeInsets.all(SheepSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.getSurface(theme.brightness),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SheepRadius.sheet),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildDragHandle()),
                const SizedBox(height: SheepSpacing.xl),
                Text(
                  L10n.of(context).get('upload_image'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: SheepSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _buildVisualActionButton(
                        icon: Icons.image_outlined,
                        label: L10n.of(context).get('choose_gallery'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _pickCategoryImage();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SheepSpacing.xl),
                Text(
                  L10n.of(context).get('icons'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: SheepSpacing.md),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: SheepSpacing.md,
                          mainAxisSpacing: SheepSpacing.md,
                        ),
                    itemCount: _iconList.length,
                    itemBuilder: (context, index) {
                      final icon = _iconList[index];
                      final isSelected = _selectedIcon == icon.codePoint;
                      final onAccent = AppColors.getOnAccent(
                        theme.brightness,
                        accent,
                      );
                      return GestureDetector(
                        onTap: () {
                          if (_selectedImagePath != null) {
                            showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => SheepConfirmDialog(
                                title: 'Thay đổi bằng biểu tượng?',
                                content: 'Sau khi đổi qua biểu tượng thì ảnh hiện tại sẽ bị mất, bạn vẫn muốn thay đổi chứ?',
                                confirmLabel: 'Thay đổi',
                                confirmColor: accent,
                                icon: Icons.warning_amber_rounded,
                                onConfirm: () {
                                  setState(() {
                                    _selectedIcon = icon.codePoint;
                                    _selectedImagePath = null;
                                  });
                                  Navigator.pop(ctx);
                                },
                              ),
                            );
                          } else {
                            setState(() {
                              _selectedIcon = icon.codePoint;
                              _selectedImagePath = null;
                            });
                            Navigator.pop(ctx);
                          }
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
                          alignment: Alignment.center,
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
          );
        },
      ),
    );
  }

  Widget _buildVisualActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final accent = color ?? _effectiveSelectedColor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SheepRadius.lg),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(SheepRadius.lg),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: SheepSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SheepTextStyles.itemMeta(context).copyWith(
                  color: AppColors.getTextPrimary(theme.brightness),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategoryImage() async {
    String? newImageRef;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      if (!mounted) return;
      final themeColor = _effectiveSelectedColor(context);
      final cropped = await cropper.ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const cropper.CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: cropper.ImageCompressFormat.jpg,
        compressQuality: 80,
        uiSettings: [
          cropper.AndroidUiSettings(
            toolbarTitle: L10n.of(context).get('upload_image'),
            toolbarColor: themeColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: themeColor,
            initAspectRatio: cropper.CropAspectRatioPreset.square,
            aspectRatioPresets: const [cropper.CropAspectRatioPreset.square],
            lockAspectRatio: true,
          ),
          cropper.IOSUiSettings(
            title: L10n.of(context).get('upload_image'),
            doneButtonTitle: L10n.of(context).save,
            cancelButtonTitle: L10n.of(context).cancel,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: const [cropper.CropAspectRatioPreset.square],
          ),
        ],
      );
      if (cropped == null) return;

      newImageRef = await CategoryImageStore.saveFromSourcePath(cropped.path);
      if (!mounted) {
        await CategoryImageStore.deleteStoredRef(newImageRef);
        return;
      }

      final previousImageRef = _selectedImagePath;
      setState(() {
        _selectedImagePath = newImageRef;
        _createdImageRefs.add(newImageRef!);
      });

      if (previousImageRef != null &&
          _createdImageRefs.remove(previousImageRef)) {
        await CategoryImageStore.deleteStoredRef(previousImageRef);
      }
    } catch (_) {
      await CategoryImageStore.deleteStoredRef(newImageRef);
      if (!mounted) return;
      SheepNotifications.showError(
        context,
        L10n.of(context).get('error_prefix'),
      );
    }
  }

  Future<void> _clearSelectedImage() async {
    final selectedImageRef = _selectedImagePath;
    setState(() => _selectedImagePath = null);
    if (selectedImageRef != null && _createdImageRefs.remove(selectedImageRef)) {
      await CategoryImageStore.deleteStoredRef(selectedImageRef);
    }
  }

  Future<void> _deleteUnusedCreatedImages() async {
    final refsToDelete = _createdImageRefs
        .where((imageRef) => imageRef != _selectedImagePath)
        .toList();
    for (final imageRef in refsToDelete) {
      await CategoryImageStore.deleteStoredRef(imageRef);
      _createdImageRefs.remove(imageRef);
    }
    if (_selectedImagePath != null) {
      _createdImageRefs.remove(_selectedImagePath);
    }
  }

  Color _effectiveSelectedColor(BuildContext context) {
    return AppColors.getInteractiveAccent(
      Theme.of(context).brightness,
      _selectedColor,
    );
  }

  Future<void> _handleImageTap() async {
    if (_selectedImagePath == null) {
      await _showVisualPicker();
    } else {
      await _showCategoryImageActions();
    }
  }

  Future<void> _showCategoryImageActions() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final imageFile = CategoryImageStore.resolve(_selectedImagePath);
    final hasImage = imageFile != null && imageFile.existsSync();
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7DDE1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                _CategoryImageActionTile(
                  icon: Icons.image_outlined,
                  label: l10n.viewCategoryImage,
                  enabled: hasImage,
                  color: theme.primaryColor,
                  onTap: () => Navigator.pop(sheetContext, 'preview'),
                ),
                _CategoryImageActionTile(
                  icon: Icons.photo_library_rounded,
                  label: l10n.changeImage,
                  color: theme.primaryColor,
                  onTap: () => Navigator.pop(sheetContext, 'change'),
                ),
                _CategoryImageActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: l10n.deleteImage,
                  enabled: hasImage,
                  color: AppColors.expense,
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'preview':
        _previewCategoryImage();
        break;
      case 'change':
        await _showVisualPicker();
        break;
      case 'delete':
        _confirmDeleteCategoryImage();
        break;
    }
  }

  void _previewCategoryImage() {
    final imageFile = CategoryImageStore.resolve(_selectedImagePath);
    if (imageFile == null || !imageFile.existsSync()) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteCategoryImage() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => SheepConfirmDialog(
        title: 'Xoá ảnh danh mục?',
        content: 'Ảnh danh mục hiện tại sẽ bị xoá khỏi biểu mẫu.',
        confirmLabel: 'Xoá ảnh',
        confirmColor: AppColors.expense,
        icon: Icons.delete_outline_rounded,
        onConfirm: () => _clearSelectedImage(),
      ),
    );
  }
}

class _CategoryImageActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _CategoryImageActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? color : const Color(0xFFB8AEB3);
    return ListTile(
      enabled: enabled,
      minVerticalPadding: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: foreground, size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: enabled ? const Color(0xFF4D4449) : const Color(0xFFB8AEB3),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
