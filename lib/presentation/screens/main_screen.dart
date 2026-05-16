import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/transaction_form.dart';
import '../tabs/diary_tab.dart';
import '../tabs/category_tab.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showAddTransactionForm();
      }
    });
  }

  void _seedParentCategories() {
    if (_catBox.isEmpty) {
      final parents = [
        CategoryModel(
          id: 'cat_bill',
          name: 'Hoá đơn',
          iconCode: Icons.receipt.codePoint,
          isExpense: true,
        ),
        CategoryModel(
          id: 'cat_eat',
          name: 'Ăn uống',
          iconCode: Icons.restaurant.codePoint,
          isExpense: true,
        ),
        CategoryModel(
          id: 'cat_shop',
          name: 'Mua sắm',
          iconCode: Icons.shopping_cart.codePoint,
          isExpense: true,
        ),
        CategoryModel(
          id: 'cat_salary',
          name: 'Lương',
          iconCode: Icons.attach_money.codePoint,
          isExpense: false,
        ),
        CategoryModel(
          id: 'cat_bonus',
          name: 'Thưởng',
          iconCode: Icons.card_giftcard.codePoint,
          isExpense: false,
        ),
      ];
      _catBox.addAll(parents);
    }
  }

  void _changeTime(int offset) {
    setState(() {
      if (_currentIndex == 0) {
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
    if (_currentIndex == 0) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    // PREMIUM APPBAR NAVIGATOR
    Widget buildAppBarTitle() {
      if (_currentIndex == 1) {
        return Text(
          l10n.categories,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        );
      }
      if (_currentIndex == 2) {
        return Text(
          l10n.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        );
      }

      if (_currentIndex == 1 || _currentIndex == 2) {
        return const SizedBox.shrink();
      }

      String dateText;
      final locale = Localizations.localeOf(context).toString();
      final isSingleDiaryDay =
          _currentIndex != 0 ||
          (_diaryRange.start.year == _diaryRange.end.year &&
              _diaryRange.start.month == _diaryRange.end.month &&
              _diaryRange.start.day == _diaryRange.end.day);
      if (_currentIndex == 0) {
        final start = DateFormat(
          'dd/MM/yyyy',
          locale,
        ).format(_diaryRange.start);
        final end = DateFormat('dd/MM/yyyy', locale).format(_diaryRange.end);
        dateText = start == end ? start : '$start - $end';
      } else {
        dateText = DateFormat('dd/MM/yyyy', locale).format(_selectedDate);
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final maxPillWidth =
              constraints.maxWidth - (isSingleDiaryDay ? 104 : 24);

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
                      color: AppColors.getTextPrimary(theme.brightness),
                    ),
                    onPressed: () => _changeTime(-1),
                  ),
                  const SizedBox(width: 4),
                ],
                SheepDatePill(
                  label: dateText,
                  onTap: _pickTime,
                  maxWidth: maxPillWidth,
                ),
                if (isSingleDiaryDay) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.getTextPrimary(theme.brightness),
                    ),
                    onPressed: () => _changeTime(1),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    Widget buildBody() {
      switch (_currentIndex) {
        case 0:
          return DiaryTab(selectedRange: _diaryRange);
        case 1:
          return const CategoryTab();
        case 2:
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
        backgroundColor: Colors.transparent,
        toolbarHeight: (_currentIndex == 1 || _currentIndex == 2) ? 60 : 68,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: buildAppBarTitle(),
        actions: [
          if (_currentIndex == 0)
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
                      color: AppColors.getTextPrimary(theme.brightness),
                    ),
                    onPressed: () {
                      settings.hideAmounts = !settings.hideAmounts;
                      settings.save();
                    },
                  ),
                );
              },
            ),
          if (_currentIndex == 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.getInteractiveAccent(
                    theme.brightness,
                    theme.colorScheme.primary,
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

    return Drawer(
      backgroundColor: AppColors.getSurface(theme.brightness),
      shape: const RoundedRectangleBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.black,
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
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _getGreeting(l10n),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jason',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
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
            icon: Icons.style_rounded,
            label: l10n.categories,
          ),
          _buildDrawerItem(
            context,
            index: 2,
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
      builder: (ctx) => const CategoryForm(category: null),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
