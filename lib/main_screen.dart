import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'widgets/transaction_form.dart';
import 'models/transaction.dart';
import 'models/category_model.dart';
import 'constants.dart';
import 'tabs/stats_tab.dart';
import 'tabs/diary_tab.dart';
import 'tabs/category_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;

  // 1. TÁCH BIẾN THỜI GIAN
  DateTime _selectedMonth = DateTime.now(); // Dùng cho Tab Thống kê
  DateTime _selectedDay = DateTime.now(); // Dùng cho Tab Nhật ký

  final _box = Hive.box<Transaction>(kMoneyBox);
  final _catBox = Hive.box<CategoryModel>(kCatBox);

  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

  // Logic form thêm mới vẫn dùng biến riêng này để chọn ngày nhập liệu
  DateTime _inputDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _seedParentCategories();
  }

  void _seedParentCategories() {
    if (_catBox.isEmpty) {
      final parents = [
        CategoryModel(
          id: 'p_fixed',
          name: 'Hoá đơn',
          iconCode: Icons.receipt.codePoint,
          isExpense: true,
          parentId: null,
        ),
        CategoryModel(
          id: 'p_daily',
          name: 'Chi tiêu',
          iconCode: Icons.shopping_cart.codePoint,
          isExpense: true,
          parentId: null,
        ),
        CategoryModel(
          id: 'p_debt',
          name: 'Trả Nợ',
          iconCode: Icons.credit_card.codePoint,
          isExpense: true,
          parentId: null,
        ),
        CategoryModel(
          id: 'p_income',
          name: 'Thu nhập',
          iconCode: Icons.attach_money.codePoint,
          isExpense: false,
          parentId: null,
        ),
        CategoryModel(
          id: 'p_invest',
          name: 'Tiết kiệm/Đầu tư',
          iconCode: Icons.savings.codePoint,
          isExpense: false,
          parentId: null,
        ),
      ];
      _catBox.addAll(parents);
    }
  }

  // Hàm chuyển Tháng (Cho Tab Thống Kê)
  void _changeMonth(int months) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + months,
        1,
      );
    });
  }

  // Hàm chuyển Ngày (Cho Tab Nhật Ký)
  void _changeDay(int days) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: days));
    });
  }

  // Hàm mở lịch chọn ngày nhanh (Cho Tab Nhật Ký)
  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. LOGIC APPBAR LINH HOẠT
    Widget buildAppBarTitle() {
      // --- TRƯỜNG HỢP 1: TAB THỐNG KÊ (CHỌN THÁNG) ---
      if (_currentIndex == 0) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: Colors.teal,
              ),
              onPressed: () => _changeMonth(-1),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 16,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.teal,
              ),
              onPressed: () => _changeMonth(1),
            ),
          ],
        );
      }

      // --- TRƯỜNG HỢP 2: TAB NHẬT KÝ (CHỌN NGÀY) ---
      if (_currentIndex == 1) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: Colors.teal,
              ),
              onPressed: () => _changeDay(-1), // Trừ 1 ngày
            ),
            GestureDetector(
              onTap: _pickDay, // Bấm vào để chọn lịch
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    // Hiển thị ngày cụ thể (VD: 17/01/2026)
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDay),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.teal,
              ),
              // Nếu là ngày tương lai thì có thể ẩn nút next hoặc vẫn cho bấm tùy bạn
              onPressed: () => _changeDay(1), // Cộng 1 ngày
            ),
          ],
        );
      }

      // --- TRƯỜNG HỢP 3: DANH MỤC ---
      return const Text(
        'Quản Lý Danh Mục',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      );
    }

    Widget buildBody() {
      switch (_currentIndex) {
        case 0:
          return StatsTab(currentMonth: _selectedMonth); // Truyền Tháng
        case 1:
          return DiaryTab(currentDay: _selectedDay); // Truyền Ngày (Mới)
        case 2:
          return const CategoryTab();
        default:
          return const SizedBox();
      }
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: buildAppBarTitle(),
      ),
      body: buildBody(),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                // Khi bấm thêm mới, mặc định lấy ngày đang chọn ở Nhật ký để nhập cho tiện
                _inputDate = _selectedDay;
                _showAddTransactionForm();
              },
              backgroundColor: Colors.teal,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: GNav(
          gap: 8,
          activeColor: Colors.teal,
          iconSize: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          duration: const Duration(milliseconds: 400),
          tabBackgroundColor: Colors.teal.withOpacity(0.1),
          color: Colors.grey[600],
          tabs: const [
            GButton(icon: LineIcons.pieChart, text: 'Thống kê'),
            GButton(icon: LineIcons.book, text: 'Nhật ký'), // Nhật ký
            GButton(icon: LineIcons.tags, text: 'Danh mục'),
          ],
          selectedIndex: _currentIndex,
          onTabChange: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }

  Future<void> _showAddTransactionForm() async {
    // Chờ kết quả trả về từ Form (là ngày user đã chọn)
    final resultDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionForm(initialDate: _selectedDay),
    );

    // Nếu có kết quả trả về (tức là Lưu thành công)
    if (resultDate != null) {
      setState(() {
        // 1. Cập nhật ngày đang chọn thành ngày của giao dịch vừa tạo
        _selectedDay = resultDate;

        // 2. Chuyển ngay sang tab Nhật Ký (index 1) để user thấy kết quả
        _currentIndex = 1;
      });

      // 3. Hiển thị thông báo thành công
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm giao dịch ngày ${DateFormat('dd/MM/yyyy').format(resultDate)}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating, // Nổi lên cho đẹp
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
