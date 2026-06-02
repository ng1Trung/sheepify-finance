import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/transaction_form.dart';
import '../tabs/diary_tab.dart';
import '../tabs/category_tab.dart';
import '../tabs/stats_tab.dart';
import '../tabs/settings_tab.dart';
import '../widgets/category_form.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n.dart';

import '../widgets/common/sheep_widgets.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // Bắt đầu từ Nhật ký

  // TIME AND VIEW MODE MANAGEMENT
  DateTime _selectedDate = DateTime.now();
  late DateTimeRange _diaryRange = _dayRange(DateTime.now());

  static DateTimeRange _dayRange(DateTime date) {
    return DateTimeRange(
      start: DateTime(date.year, date.month, date.day),
      end: DateTime(date.year, date.month, date.day, 23, 59, 59),
    );
  }

  final _catBox = Hive.box<CategoryModel>(kCatBox);

  @override
  void initState() {
    super.initState();
    _seedParentCategories();
  }

  void _seedParentCategories() {
    final defaultCategories = [
      CategoryModel(
        id: 'cat_bill',
        name: 'Hoá đơn',
        iconCode: Icons.receipt.codePoint,
        isExpense: true,
        typeIndex: 0,
        colorValue: AppColors.expense.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_eat',
        name: 'Ăn uống',
        iconCode: Icons.restaurant.codePoint,
        isExpense: true,
        typeIndex: 0,
        colorValue: AppColors.expense.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_shop',
        name: 'Mua sắm',
        iconCode: Icons.shopping_cart.codePoint,
        isExpense: true,
        typeIndex: 0,
        colorValue: AppColors.expense.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_salary',
        name: 'Lương',
        iconCode: Icons.attach_money.codePoint,
        isExpense: false,
        typeIndex: 1,
        colorValue: AppColors.income.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_bonus',
        name: 'Thưởng',
        iconCode: Icons.card_giftcard.codePoint,
        isExpense: false,
        typeIndex: 1,
        colorValue: AppColors.income.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_savings',
        name: 'Tiết kiệm',
        iconCode: Icons.savings.codePoint,
        isExpense: false,
        typeIndex: 2,
        colorValue: AppColors.savings.toARGB32(),
      ),
    ];

    if (_catBox.isEmpty) {
      _catBox.addAll(defaultCategories);
      return;
    }

    final defaultsById = {for (final cat in defaultCategories) cat.id: cat};
    final existingDefaults = _catBox.values
        .where((cat) => defaultsById.containsKey(cat.id))
        .toList();
    final needsLegacyMigration = existingDefaults.any((cat) {
      final defaultCategory = defaultsById[cat.id]!;
      return cat.id != 'cat_savings' &&
          (cat.isExpense != defaultCategory.isExpense ||
              cat.typeIndex != defaultCategory.typeIndex ||
              cat.colorValue == null);
    });

    for (final cat in existingDefaults) {
      final defaultCategory = defaultsById[cat.id]!;
      cat.isExpense = defaultCategory.isExpense;
      cat.typeIndex = defaultCategory.typeIndex;
      cat.colorValue ??= defaultCategory.colorValue;
      cat.save();
    }

    final hasSavingsDefault = existingDefaults.any(
      (cat) => cat.id == 'cat_savings',
    );
    if (needsLegacyMigration && !hasSavingsDefault) {
      _catBox.add(defaultsById['cat_savings']!);
    }
  }

  void _changeTime(int offset) {
    setState(() {
      if (_usesDateRange) {
        final start = _diaryRange.start.add(Duration(days: offset));
        final end = _diaryRange.end.add(Duration(days: offset));
        _diaryRange = DateTimeRange(start: start, end: end);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: offset));
      }
    });
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _selectedDate = DateTime.now();
      if (index == 0) {
        _diaryRange = _dayRange(DateTime.now());
      }
    });
  }

  Future<void> _pickTime() async {
    if (_usesDateRange) {
      final picked = await SheepDateRangePicker.show(
        context: context,
        initialRange: _diaryRange,
      );
      if (picked != null) {
        setState(() => _diaryRange = picked);
      }
      return;
    }

    final picked = await SheepDatePicker.show(
      context: context,
      initialDate: _selectedDate,
      mode: SheepDateMode.day,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  bool get _usesDateRange => _currentIndex == 0 || _currentIndex == 2;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final headerBase = AppColors.getPalette(settings.themePresetName).primary;
    final headerShade = Color.lerp(
      headerBase,
      theme.brightness == Brightness.dark ? Colors.black : Colors.white,
      theme.brightness == Brightness.dark ? 0.36 : 0.32,
    );
    final headerForeground = headerBase.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;

    // PREMIUM APPBAR NAVIGATOR
    Widget buildAppBarTitle() {
      if (_currentIndex == 1) {
        return Text(
          l10n.savings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerForeground,
          ),
        );
      }
      if (_currentIndex == 3) {
        return Text(
          l10n.categories,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerForeground,
          ),
        );
      }
      if (_currentIndex == 4) {
        return Text(
          l10n.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerForeground,
          ),
        );
      }

      if (!_usesDateRange) {
        return const SizedBox.shrink();
      }

      String dateText;
      final locale = Localizations.localeOf(context).toString();
      final isSingleDiaryDay =
          (_diaryRange.start.year == _diaryRange.end.year &&
          _diaryRange.start.month == _diaryRange.end.month &&
          _diaryRange.start.day == _diaryRange.end.day);
      final start = DateFormat('dd/MM/yyyy', locale).format(_diaryRange.start);
      final end = DateFormat('dd/MM/yyyy', locale).format(_diaryRange.end);
      dateText = start == end ? start : '$start - $end';

      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSingleDiaryDay) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: AppColors.getInteractiveAccent(
                    theme.brightness,
                    headerForeground,
                  ),
                ),
                onPressed: () => _changeTime(-1),
              ),
              const SizedBox(width: 4),
            ],
            SheepDatePill(label: dateText, onTap: _pickTime),
            if (isSingleDiaryDay) ...[
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.getInteractiveAccent(
                    theme.brightness,
                    headerForeground,
                  ),
                ),
                onPressed: () => _changeTime(1),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildBody() {
      switch (_currentIndex) {
        case 0:
          return DiaryTab(selectedRange: _diaryRange);
        case 1:
          return const CategoryTab(
            key: ValueKey('savings-tab'),
            initialTypeIndex: 2,
            showTypeToggle: false,
          );
        case 2:
          return StatsTab(selectedRange: _diaryRange);
        case 3:
          return const CategoryTab(key: ValueKey('categories-tab'));
        case 4:
          return const SettingsTab();
        default:
          return const SizedBox();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(theme.brightness),
      drawer: _buildSideMenu(context),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: headerBase,
        foregroundColor: headerForeground,
        iconTheme: IconThemeData(
          color: AppColors.getInteractiveAccent(
            theme.brightness,
            headerForeground,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [headerBase, headerShade!],
            ),
          ),
        ),
        toolbarHeight: _usesDateRange ? 68 : 60,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            icon: Icon(
              Icons.menu_rounded,
              color: AppColors.getInteractiveAccent(
                theme.brightness,
                headerForeground,
              ),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: buildAppBarTitle(),
        actions: [
          if (_currentIndex == 0 || _currentIndex == 2)
            ValueListenableBuilder(
              valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
              builder: (context, settingsBox, _) {
                final settings = settingsBox.get('current') ?? AppSettings();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                      settings.hideAmounts
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.getInteractiveAccent(
                        theme.brightness,
                        headerForeground,
                      ),
                    ),
                    onPressed: () {
                      settings.hideAmounts = !settings.hideAmounts;
                      settings.save();
                    },
                  ),
                );
              },
            ),
          if (_currentIndex == 1 || _currentIndex == 3)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.getInteractiveAccent(
                    theme.brightness,
                    headerForeground,
                  ),
                  size: 28,
                ),
                onPressed: _showAddCategoryForm,
              ),
            ),
        ],
      ),
      body: buildBody(),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddTransactionForm,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSideMenu(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final headerBase = AppColors.getPalette(settings.themePresetName).primary;
    final headerShade = Color.lerp(
      headerBase,
      Colors.black,
      theme.brightness == Brightness.dark ? 0.52 : 0.28,
    )!;
    final headerForeground = headerBase.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;

    return Drawer(
      backgroundColor: AppColors.getSurface(theme.brightness),
      shape: const RoundedRectangleBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [headerBase, headerShade],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.get('app_title'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: headerForeground,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          icon: const Icon(Icons.close_rounded),
                          color: headerForeground,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _getGreeting(l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: headerForeground.withOpacity(0.78),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jason',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: headerForeground,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildDrawerItem(
            context,
            index: 0,
            icon: Icons.receipt_long_rounded,
            label: l10n.diary,
          ),
          _buildDrawerItem(
            context,
            index: 1,
            icon: Icons.savings_outlined,
            label: l10n.savings,
          ),
          _buildDrawerItem(
            context,
            index: 2,
            icon: Icons.donut_large_rounded,
            label: l10n.stats,
          ),
          _buildDrawerItem(
            context,
            index: 3,
            icon: Icons.style_rounded,
            label: l10n.categories,
          ),
          _buildDrawerItem(
            context,
            index: 4,
            icon: Icons.settings_rounded,
            label: l10n.settings,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTransactionForm() async {
    final resultDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => TransactionForm(
        initialDate: _currentIndex == 0 ? _diaryRange.start : _selectedDate,
      ),
    );

    if (resultDate != null) {
      setState(() {
        _selectedDate = resultDate;
        _diaryRange = _dayRange(resultDate);
        _currentIndex = 0;
      });
    }
  }

  Future<void> _showAddCategoryForm() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CategoryForm(
        category: null,
        fixedTypeIndex: _currentIndex == 1 ? 2 : null,
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;
    final accent = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        selected: isSelected,
        selectedColor: accent,
        selectedTileColor: AppColors.getAccentSurface(theme.brightness, accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SheepRadius.md),
        ),
        onTap: () {
          Navigator.of(context).pop();
          _selectTab(index);
        },
      ),
    );
  }

  String _getGreeting(L10n l10n) {
    final hour = DateTime.now().hour;
    final isVietnamese = l10n.locale.languageCode == 'vi';

    if (hour < 12) {
      return isVietnamese ? 'Chào buổi sáng,' : 'Good morning,';
    }
    if (hour < 18) {
      return isVietnamese ? 'Chào buổi chiều,' : 'Good afternoon,';
    }
    return isVietnamese ? 'Chào buổi tối,' : 'Good evening,';
  }
}
