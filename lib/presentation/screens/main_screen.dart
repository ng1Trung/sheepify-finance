import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction.dart';
import '../widgets/transaction_form.dart';
import '../tabs/diary_tab.dart';
import '../tabs/category_tab.dart';
import '../tabs/stats_tab.dart';
import '../tabs/settings_tab.dart';
import '../widgets/category_form.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../core/utils/l10n.dart';

import '../widgets/common/sheep_widgets.dart';

enum _DrawerInsightType { budget, cycle, savings, today }

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
  late final ValueListenable<Box<Transaction>> _moneyListenable;
  final _insightRandom = Random();
  bool _isDrawerOpen = false;
  DateTime? _drawerLastClosedAt;
  _DrawerInsightType? _activeInsightType;

  static const Duration _insightRepickDelay = Duration(seconds: 180);

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
    _moneyListenable = Hive.box<Transaction>(kMoneyBox).listenable();
    _moneyListenable.addListener(_handleTransactionEvents);
    _seedParentCategories();
    _activeInsightType = _pickRandomInsightType();
  }

  @override
  void dispose() {
    _moneyListenable.removeListener(_handleTransactionEvents);
    super.dispose();
  }

  void _handleTransactionEvents() {
    if (!_isDrawerOpen || !mounted) return;
    setState(() {
      _activeInsightType =
          _validInsightType(_activeInsightType) ?? _pickRandomInsightType();
    });
  }

  void _handleDrawerChanged(bool isOpened) {
    final now = DateTime.now();
    if (!isOpened) {
      setState(() {
        _isDrawerOpen = false;
        _drawerLastClosedAt = now;
      });
      return;
    }

    final shouldPickInsight =
        _activeInsightType == null ||
        _drawerLastClosedAt == null ||
        now.difference(_drawerLastClosedAt!) >= _insightRepickDelay;

    setState(() {
      _isDrawerOpen = true;
      _activeInsightType = shouldPickInsight
          ? _pickRandomInsightType(excluding: _activeInsightType)
          : (_validInsightType(_activeInsightType) ?? _pickRandomInsightType());
    });
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
      drawerScrimColor: const Color(0x6B000000),
      onDrawerChanged: _handleDrawerChanged,
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
          if (_usesDateRange)
            const SizedBox(width: kToolbarHeight)
          else if (_currentIndex == 1 || _currentIndex == 3)
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
      floatingActionButton: _currentIndex == 0 || _currentIndex == 2
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
    const username = 'Jason';
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final headerBase = AppColors.getPalette(settings.themePresetName).primary;
    final headerShade = Color.lerp(
      headerBase,
      Colors.black,
      theme.brightness == Brightness.dark ? 0.48 : 0.22,
    )!;
    final drawerWidth = MediaQuery.sizeOf(context).width * 0.82;
    final safePadding = MediaQuery.paddingOf(context);
    final streakCount = _calculateTransactionStreak();
    final overview = _buildFinancialOverview(settings);

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 232,
              padding: EdgeInsets.fromLTRB(10, safePadding.top + 20, 10, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [headerBase, headerShade],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(l10n),
                              style: const TextStyle(
                                color: Color(0xDBFFFFFF),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 22 / 16,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                height: 36 / 30,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 48,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DrawerAvatar(
                              username: username,
                              streakCount: streakCount,
                            ),
                            const SizedBox(height: 2),
                            ValueListenableBuilder(
                              valueListenable: Hive.box<AppSettings>(
                                kSettingsBox,
                              ).listenable(),
                              builder: (context, settingsBox, _) {
                                final currentSettings =
                                    settingsBox.get('current') ?? AppSettings();
                                return _DrawerPrivacyButton(
                                  isHidden: currentSettings.hideAmounts,
                                  onPressed: () {
                                    currentSettings.hideAmounts =
                                        !currentSettings.hideAmounts;
                                    currentSettings.save();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _DrawerOverviewCard(status: overview),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: constraints.maxHeight < 430
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            10,
                            14,
                            10,
                            safePadding.bottom + 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDrawerItem(
                                context,
                                index: 0,
                                icon: Icons.receipt_long_rounded,
                                label: l10n.diary,
                              ),
                              _buildDrawerItem(
                                context,
                                index: 1,
                                icon: Icons.savings_rounded,
                                label: l10n.savings,
                              ),
                              _buildDrawerItem(
                                context,
                                index: 2,
                                icon: Icons.pie_chart_rounded,
                                label: l10n.stats,
                              ),
                              _buildDrawerItem(
                                context,
                                index: 3,
                                icon: Icons.sell_rounded,
                                label: l10n.categories,
                              ),
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                color: const Color(0xFFF0E8EB),
                              ),
                              _buildDrawerItem(
                                context,
                                index: 4,
                                icon: Icons.settings_rounded,
                                label: l10n.settings,
                              ),
                              const Spacer(),
                              const Padding(
                                padding: EdgeInsets.only(left: 12, top: 14),
                                child: Text(
                                  'Sheepify v1.0.0',
                                  style: TextStyle(
                                    color: Color(0xFFB8AEB3),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Future<void> _showAddTransactionForm() async {
    final sourceIndex = _currentIndex;
    final resultDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => TransactionForm(
        initialDate: _usesDateRange ? _diaryRange.start : _selectedDate,
      ),
    );

    if (resultDate != null) {
      setState(() {
        _selectedDate = resultDate;
        _diaryRange = _dayRange(resultDate);
        _currentIndex = sourceIndex == 2 ? 2 : 0;
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
    final isSelected = _currentIndex == index;
    final foreground = isSelected
        ? const Color(0xFFFF7FA2)
        : const Color(0xFF5F555A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected ? const Color(0x1FFF7FA2) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          overlayColor: WidgetStateProperty.all(const Color(0x14FF7FA2)),
          onTap: () {
            _selectTab(index);
            Navigator.of(context).pop();
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: foreground),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 18,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _calculateTransactionStreak() {
    final transactionDays = Hive.box<Transaction>(kMoneyBox).values.map((tx) {
      return DateTime(tx.date.year, tx.date.month, tx.date.day);
    }).toSet();
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    var streak = 0;

    while (transactionDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  _DrawerOverviewStatus _buildFinancialOverview(AppSettings settings) {
    final type = _activeInsightType ?? _validInsightType(null);
    if (type == null) return _buildTodayOverview(settings);
    return _overviewForType(type, settings) ?? _buildTodayOverview(settings);
  }

  _DrawerInsightType _pickRandomInsightType({_DrawerInsightType? excluding}) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    var availableTypes = _availableInsightTypes(settings);
    if (availableTypes.isEmpty) return _DrawerInsightType.today;

    if (excluding != null && availableTypes.length > 1) {
      availableTypes = availableTypes
          .where((type) => type != excluding)
          .toList();
    }

    return availableTypes[_insightRandom.nextInt(availableTypes.length)];
  }

  _DrawerInsightType? _validInsightType(_DrawerInsightType? preferredType) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    if (preferredType != null &&
        _overviewForType(preferredType, settings) != null) {
      return preferredType;
    }

    final availableTypes = _availableInsightTypes(settings);
    return availableTypes.isEmpty ? null : _pickRandomInsightType();
  }

  List<_DrawerInsightType> _availableInsightTypes(AppSettings settings) {
    return _DrawerInsightType.values
        .where((type) => _overviewForType(type, settings) != null)
        .toList();
  }

  _DrawerOverviewStatus? _overviewForType(
    _DrawerInsightType type,
    AppSettings settings,
  ) {
    return switch (type) {
      _DrawerInsightType.budget => _buildBudgetOverview(),
      _DrawerInsightType.cycle => _buildCycleOverview(),
      _DrawerInsightType.savings => _buildSavingsOverview(settings),
      _DrawerInsightType.today => _buildTodayOverview(settings),
    };
  }

  _DrawerOverviewStatus? _buildBudgetOverview() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final transactions = Hive.box<Transaction>(kMoneyBox).values.toList();
    _DrawerOverviewStatus? bestUnderBudget;
    double bestProgress = -1;
    _DrawerOverviewStatus? bestOverBudget;
    double bestOverage = -1;

    for (final category in Hive.box<CategoryModel>(kCatBox).values) {
      final budget = category.budget;
      if (category.effectiveTypeIndex != 0 || budget == null || budget <= 0) {
        continue;
      }

      final spent = transactions
          .where(
            (tx) =>
                tx.categoryId == category.id &&
                !tx.date.isBefore(start) &&
                tx.date.isBefore(end),
          )
          .fold(0.0, (sum, tx) => sum + tx.amount);
      if (spent <= 0) continue;

      final progressPercent = (spent / budget * 100).round();
      if (spent > budget) {
        final overPercent = ((spent - budget) / budget * 100).round();
        if (overPercent > bestOverage) {
          bestOverage = overPercent.toDouble();
          bestOverBudget = _DrawerOverviewStatus(
            icon: category.iconData,
            title: category.name,
            message: 'vượt ngân sách $overPercent%',
            color: const Color(0xFFFF5F75),
            backgroundColor: const Color(0xFFFFEEF2),
          );
        }
      } else if (progressPercent > bestProgress) {
        bestProgress = progressPercent.toDouble();
        bestUnderBudget = _DrawerOverviewStatus(
          icon: category.iconData,
          title: category.name,
          message: 'đã tiêu $progressPercent% ngân sách',
        );
      }
    }

    return bestOverBudget ?? bestUnderBudget;
  }

  _DrawerOverviewStatus? _buildCycleOverview() {
    final now = DateTime.now();
    final currentStart = DateTime(now.year, now.month);
    final currentEnd = DateTime(now.year, now.month + 1);
    final previousStart = DateTime(now.year, now.month - 1);
    final previousEnd = currentStart;
    final transactions = Hive.box<Transaction>(kMoneyBox).values.toList();
    final categoriesById = {
      for (final cat in Hive.box<CategoryModel>(kCatBox).values) cat.id: cat,
    };

    double sumForRange(DateTime start, DateTime end, int typeIndex) {
      return transactions
          .where((tx) {
            final category = categoriesById[tx.categoryId];
            final effectiveTypeIndex =
                category?.effectiveTypeIndex ?? (tx.isExpense ? 0 : 1);
            return effectiveTypeIndex == typeIndex &&
                !tx.date.isBefore(start) &&
                tx.date.isBefore(end);
          })
          .fold(0.0, (sum, tx) => sum + tx.amount);
    }

    final currentExpense = sumForRange(currentStart, currentEnd, 0);
    final previousExpense = sumForRange(previousStart, previousEnd, 0);
    if (previousExpense > 0 && currentExpense != previousExpense) {
      final percent =
          ((currentExpense - previousExpense).abs() / previousExpense * 100)
              .round();
      final isLower = currentExpense < previousExpense;
      return _DrawerOverviewStatus(
        icon: Icons.pie_chart_rounded,
        title: 'Chi tiêu',
        message: '${isLower ? 'ít' : 'nhiều'} hơn $percent% so với kỳ trước',
        color: isLower ? const Color(0xFF37D58A) : const Color(0xFFFF5F75),
        backgroundColor: isLower
            ? const Color(0xFFE9FFF3)
            : const Color(0xFFFFEEF2),
      );
    }

    final currentIncome = sumForRange(currentStart, currentEnd, 1);
    final previousIncome = sumForRange(previousStart, previousEnd, 1);
    if (previousIncome > 0 && currentIncome > previousIncome) {
      final percent = ((currentIncome - previousIncome) / previousIncome * 100)
          .round();
      return _DrawerOverviewStatus(
        icon: Icons.pie_chart_rounded,
        title: 'Thu nhập',
        message: 'tăng $percent% so với kỳ trước',
        color: const Color(0xFF37D58A),
        backgroundColor: const Color(0xFFE9FFF3),
      );
    }

    return null;
  }

  _DrawerOverviewStatus? _buildSavingsOverview(AppSettings settings) {
    final transactions = Hive.box<Transaction>(kMoneyBox).values.toList();
    _DrawerOverviewStatus? bestStatus;
    double bestProgress = -1;

    for (final category in Hive.box<CategoryModel>(kCatBox).values) {
      final target = category.targetAmount;
      if (category.effectiveTypeIndex != 2 || target == null || target <= 0) {
        continue;
      }

      final saved = transactions
          .where((tx) => tx.categoryId == category.id)
          .fold(0.0, (sum, tx) => sum + tx.amount);
      final progress = saved / target;
      if (progress <= bestProgress) continue;

      bestProgress = progress;
      if (saved >= target) {
        bestStatus = _DrawerOverviewStatus(
          icon: category.iconData,
          title: 'Mục tiêu ${category.name}',
          message: 'đã hoàn thành 🎉',
          color: const Color(0xFF37D58A),
          backgroundColor: const Color(0xFFE9FFF3),
        );
      } else if (progress >= 0.5) {
        bestStatus = _DrawerOverviewStatus(
          icon: category.iconData,
          title: 'Mục tiêu ${category.name}',
          message: 'đã đạt ${(progress * 100).round()}%',
        );
      } else {
        final remaining = _formatCompactAmount(target - saved, settings);
        bestStatus = _DrawerOverviewStatus(
          icon: category.iconData,
          title: 'Mục tiêu ${category.name}',
          message: 'còn $remaining nữa là hoàn thành',
        );
      }
    }

    return bestStatus;
  }

  _DrawerOverviewStatus _buildTodayOverview(AppSettings settings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayTransactions = Hive.box<Transaction>(kMoneyBox).values.where(
      (tx) => !tx.date.isBefore(today) && tx.date.isBefore(tomorrow),
    );
    final todayExpense = todayTransactions
        .where((tx) => tx.isExpense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final count = todayTransactions.length;

    if (count == 0) {
      return const _DrawerOverviewStatus(
        icon: Icons.receipt_long_rounded,
        title: 'Hôm nay',
        message: 'chưa có giao dịch nào',
        color: Color(0xFF37D58A),
        backgroundColor: Color(0xFFE9FFF3),
      );
    }

    return _DrawerOverviewStatus(
      icon: Icons.receipt_long_rounded,
      title: 'Hôm nay',
      message:
          'đã chi ${_formatCompactAmount(todayExpense, settings)} với $count giao dịch',
    );
  }

  String _formatCompactAmount(double amount, AppSettings settings) {
    if (settings.hideAmounts) return '****';
    return '${CurrencyUtil.formatCompact(amount)}${CurrencyUtil.getCurrencySymbol(settings.currencyCode)}';
  }

  String _getGreeting(L10n l10n) {
    final hour = DateTime.now().hour;
    final isVietnamese = l10n.locale.languageCode == 'vi';

    if (hour < 12) {
      return isVietnamese ? 'Chào buổi sáng 👋' : 'Good morning 👋';
    }
    if (hour < 18) {
      return isVietnamese ? 'Chào buổi chiều 👋' : 'Good afternoon 👋';
    }
    return isVietnamese ? 'Chào buổi tối 👋' : 'Good evening 👋';
  }
}

class _DrawerOverviewStatus {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color backgroundColor;

  const _DrawerOverviewStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.color = const Color(0xFF1F7AE0),
    this.backgroundColor = const Color(0xDDE8F2FF),
  });
}

class _DrawerOverviewCard extends StatelessWidget {
  final _DrawerOverviewStatus status;

  const _DrawerOverviewCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(status.icon, size: 14, color: status.color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  color: status.color,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w600,
                  height: 1.22,
                  letterSpacing: 0,
                ),
                children: [
                  TextSpan(
                    text: status.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' ${status.message}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerAvatar extends StatelessWidget {
  final String username;
  final int streakCount;

  const _DrawerAvatar({required this.username, required this.streakCount});

  @override
  Widget build(BuildContext context) {
    final initial = username.trim().isEmpty
        ? 'S'
        : username.trim().characters.first.toUpperCase();
    final hasStreak = streakCount >= 1;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasStreak
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF7A1A), Color(0xFFFFD44D)],
                  )
                : null,
            border: null,
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x38FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        if (hasStreak)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              height: 18,
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF7A1A), Color(0xFFFFD44D)],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                '$streakCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DrawerPrivacyButton extends StatelessWidget {
  final bool isHidden;
  final VoidCallback onPressed;

  const _DrawerPrivacyButton({required this.isHidden, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      onPressed: onPressed,
      icon: Icon(
        isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
