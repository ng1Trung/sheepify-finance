import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../widgets/transaction_form.dart';
import '../tabs/home_tab.dart';
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
  int _currentIndex = 0; // Bắt đầu từ Trang chủ

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
      if (_currentIndex == 1) {
        final start = _diaryRange.start.add(Duration(days: offset));
        final end = _diaryRange.end.add(Duration(days: offset));
        _diaryRange = DateTimeRange(start: start, end: end);
      } else if (_currentIndex == 0) {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + offset,
          1,
        );
      } else {
        _selectedDate = _selectedDate.add(Duration(days: offset));
      }
    });
  }

  Future<void> _pickTime() async {
    if (_currentIndex == 1) {
      final picked = await SheepDateRangePicker.show(
        context: context,
        initialRange: _diaryRange,
      );
      if (picked != null) {
        setState(() => _diaryRange = picked);
      }
      return;
    }

    final bool isMonthOnly = _currentIndex == 0;
    final picked = await SheepDatePicker.show(
      context: context,
      initialDate: _selectedDate,
      mode: isMonthOnly ? SheepDateMode.month : SheepDateMode.day,
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
      if (_currentIndex == 0) {
        return const SizedBox.shrink(); // HomeTab handles its own header
      }
      if (_currentIndex == 2) {
        return Text(
          l10n.categories,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        );
      }
      if (_currentIndex == 3) {
        return Text(
          l10n.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        );
      }

      if (_currentIndex == 0 || _currentIndex == 2 || _currentIndex == 3) {
        return const SizedBox.shrink();
      }

      String dateText;
      final locale = Localizations.localeOf(context).toString();
      if (_currentIndex == 1) {
        final start = DateFormat(
          'dd/MM/yyyy',
          locale,
        ).format(_diaryRange.start);
        final end = DateFormat('dd/MM/yyyy', locale).format(_diaryRange.end);
        dateText = start == end ? start : '$start - $end';
      } else {
        dateText = DateFormat('dd/MM/yyyy', locale).format(_selectedDate);
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // NAVIGATOR < DATE/MONTH >
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: AppColors.getTextPrimary(theme.brightness),
                ),
                onPressed: () => _changeTime(-1),
              ),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.light
                        ? Colors.white
                        : AppColors.getSurface(theme.brightness),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.getTextPrimary(theme.brightness),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dateText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(theme.brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
          ),
        ],
      );
    }

    Widget buildBody() {
      switch (_currentIndex) {
        case 0:
          return HomeTab(
            onViewAllSavings: () => setState(() => _currentIndex = 2),
          );
        case 1:
          return DiaryTab(selectedRange: _diaryRange);
        case 2:
          return const CategoryTab();
        case 3:
          return const SettingsTab();
        default:
          return const SizedBox();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(theme.brightness),
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              elevation: 0,
              centerTitle: true,
              backgroundColor: Colors.transparent,
              toolbarHeight: (_currentIndex == 2 || _currentIndex == 3)
                  ? 60
                  : 68,
              title: buildAppBarTitle(),
              actions: [
                if (_currentIndex == 2)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.black,
                        size: 28,
                      ),
                      onPressed: _showAddCategoryForm,
                    ),
                  ),
              ],
            ),
      body: buildBody(),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.getSurface(theme.brightness),
        elevation: 0,
        padding: EdgeInsets.zero,
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.getSurface(theme.brightness),
            border: Border(
              top: BorderSide(color: Colors.black.withOpacity(0.08), width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Căn giữa tuyệt đối theo trục dọc
            children: [
              // --- LEFT: TAB ICONS ---
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIconNavItem(0, Icons.home_rounded),
                    const SizedBox(width: 18),
                    _buildIconNavItem(1, Icons.receipt_long_rounded),
                    const SizedBox(width: 18),
                    _buildIconNavItem(2, Icons.style_rounded),
                    const SizedBox(width: 18),
                    _buildIconNavItem(3, Icons.settings_rounded),
                  ],
                ),
              ),

              // --- RIGHT: ADD BUTTON ---
              _buildRightAddButton(),
            ],
          ),
        ),
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
        initialDate: _currentIndex == 1 ? _diaryRange.start : _selectedDate,
      ),
    );

    if (resultDate != null) {
      setState(() {
        _selectedDate = resultDate;
        _diaryRange = _dayRange(resultDate);
        _currentIndex = 1;
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

  Widget _buildIconNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Colors.black : Colors.grey[400];

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _selectedDate = DateTime.now();
          if (index == 1) {
            _diaryRange = _dayRange(DateTime.now());
          }
        });
      },
      child: Icon(icon, color: color, size: 26),
    );
  }

  Widget _buildRightAddButton() {
    return GestureDetector(
      onTap: _showAddTransactionForm,
      child: Container(
        width: 52, // Tăng từ 48 lên 52
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
