import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../widgets/transaction_form.dart';
import '../tabs/stats_tab.dart';
import '../tabs/diary_tab.dart';
import '../tabs/category_tab.dart';
import '../tabs/settings_tab.dart';
import '../widgets/category_form.dart';

import '../../core/theme/app_colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;

  // QUẢN LÝ THỜI GIAN VÀ CHẾ ĐỘ XEM
  DateTime _selectedDate = DateTime.now();
  bool _isMonthlyView = false; // Mặc định là xem theo Ngày

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
      if (_isMonthlyView || _currentIndex == 0) {
        // Chế độ Tháng hoặc đang ở Tab Thống kê
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + offset,
          1,
        );
      } else {
        // Chế độ Ngày
        _selectedDate = _selectedDate.add(Duration(days: offset));
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildModeToggleItem(String title, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isMonthlyView = (title == 'Tháng')),
      child: Container(
        width: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // APPBAR NAVIGATOR TÍCH HỢP XỊN XÒ
    Widget buildAppBarTitle() {
      if (_currentIndex == 2) {
        return const Text(
          'Danh Mục',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        );
      }
      if (_currentIndex == 3) {
        return const Text(
          'Cá nhân',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        );
      }

      String dateText;
      if (_currentIndex == 0 || _isMonthlyView) {
        dateText = 'Tháng ${DateFormat('MM/yyyy').format(_selectedDate)}';
      } else {
        dateText = DateFormat('dd/MM/yyyy').format(_selectedDate);
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // NÚT CHUYỂN ĐỔI NGÀY/THÁNG (CHỈ HIỆN Ở TAB NHẬT KÝ)
          if (_currentIndex == 1)
            Container(
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeToggleItem('Ngày', !_isMonthlyView),
                  _buildModeToggleItem('Tháng', _isMonthlyView),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // NAVIGATOR < NGÀY/THÁNG >
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: AppColors.primary,
                ),
                onPressed: () => _changeTime(-1),
              ),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_currentIndex == 0 || _isMonthlyView)
                            ? Icons.calendar_month
                            : Icons.calendar_today,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.primary,
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
          return StatsTab(currentMonth: _selectedDate);
        case 1:
          return DiaryTab(
            selectedDate: _selectedDate,
            isMonthly: _isMonthlyView,
          );
        case 2:
          return const CategoryTab();
        case 3:
          return const SettingsTab();
        default:
          return const SizedBox();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        toolbarHeight: (_currentIndex == 2 || _currentIndex == 3) ? 60 : 100,
        title: buildAppBarTitle(),
      ),
      body: buildBody(),
      floatingActionButton: (_currentIndex == 1 || _currentIndex == 2)
          ? Padding(
              padding: const EdgeInsets.only(
                bottom: 0,
              ), // Tighter alignment closer to bottom bar
              child: FloatingActionButton(
                onPressed: _currentIndex == 1
                    ? _showAddTransactionForm
                    : _showAddCategoryForm,
                backgroundColor: AppColors.primary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _currentIndex == 1 ? Icons.add : Icons.create_new_folder,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            )
          : null,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: AppColors.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: GNav(
              gap: 8,
              activeColor: AppColors.primary,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              tabBackgroundColor: AppColors.primary.withOpacity(0.08),
              color: AppColors.textSecondary,
              tabs: const [
                GButton(icon: LineIcons.pieChart, text: 'Thống kê'),
                GButton(icon: LineIcons.book, text: 'Nhật ký'),
                GButton(icon: LineIcons.tags, text: 'Danh mục'),
                GButton(icon: LineIcons.user, text: 'Cá nhân'),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTransactionForm() async {
    final resultDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionForm(
        initialDate: _isMonthlyView ? DateTime.now() : _selectedDate,
      ),
    );

    if (resultDate != null) {
      setState(() {
        _selectedDate = resultDate;
        _isMonthlyView = false; // Khi thêm xong, hiện thị ngày vừa thêm
        _currentIndex = 1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm giao dịch ngày ${DateFormat('dd/MM/yyyy').format(resultDate)}',
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showAddCategoryForm() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const CategoryForm(category: null),
    );
  }
}
