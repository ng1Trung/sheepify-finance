import 'package:flutter/material.dart';

class L10n {
  final Locale locale;
  L10n(this.locale);

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const _localizedValues = {
    'vi': {
      'app_title': 'Sheepify',
      'settings': 'Cài đặt',
      'home': 'Trang chủ',
      'categories': 'Danh mục',
      'stats': 'Thống kê',
      'diary': 'Nhật ký',
      'balance': 'Số dư',
      'total_balance': 'Tổng số dư',
      'income': 'Thu nhập',
      'expense': 'Chi tiêu',
      'accumulate_balance': 'Cộng dồn số dư từ tháng trước',
      'accumulate_subtitle':
          'Số dư tháng này sẽ bao gồm cả số dư khả dụng từ các tháng trước đó.',
      'system_settings': 'CÀI ĐẶT HỆ THỐNG',
      'theme': 'Giao diện & Màu sắc',
      'language': 'Ngôn ngữ',
      'currency': 'Tiền tệ',
      'font': 'Phông chữ',
      'version': 'Phiên bản',
      'user_greeting': 'Người dùng Sheepify',
      'user_sub': 'Quản lý tài chính đơn giản',
      'confirm': 'Xác nhận',
      'cancel': 'Hủy',
      'day': 'Ngày',
      'month': 'Tháng',
      'monthly_balance': 'SỐ DƯ THÁNG',
      'daily_balance': 'SỐ DƯ NGÀY',
      'no_tx_month': 'Tháng này chưa có giao dịch',
      'no_tx_today': 'Hôm nay chưa có giao dịch',
      'delete_confirm_title': 'Xoá giao dịch?',
      'delete_confirm_msg':
          'Bạn có chắc chắn muốn xoá giao dịch này không? Hành động này không thể hoàn tác.',
      'delete': 'Xoá',
      'delete_success': 'Đã xoá giao dịch',
      'wallet_balance': 'SỐ DƯ VÍ',
      'total_expense': 'TỔNG CHI PHÍ',
      'total_income': 'TỔNG THU NHẬP',
      'total_savings': 'TỔNG TÍCH LUỸ',
      'prev_balance': 'Số dư trước',
      'accumulated_from_prev': 'Số dư tích lũy từ các tháng trước',
      'other': 'Khác',
      'no_data_expense': 'Chưa có dữ liệu chi phí!',
      'no_data_income': 'Chưa có dữ liệu thu nhập!',
      'no_data_savings': 'Chưa có dữ liệu tích luỹ!',
      'save': 'LƯU',
      'update': 'CẬP NHẬT',
      'upload_image': 'TẢI ẢNH LÊN',
      'take_photo': 'Chụp ảnh',
      'choose_gallery': 'Chọn từ thư viện',
      'error_input': 'Vui lòng nhập số tiền và chọn danh mục!',
      'tx_updated': 'Đã cập nhật giao dịch',
      'tx_added': 'Đã thêm giao dịch thành công',
      'budget_warning': 'Cảnh báo ngân sách!',
      'budget_msg':
          'Bạn đã tiêu quá hạn mức của danh mục "{name}". Hãy cân nhắc chi tiêu nhé!',
      'goal_congrats': 'Chúc mừng!',
      'goal_msg':
          'Tuyệt vời! Bạn đã đạt mục tiêu tích luỹ. Tiếp tục phát huy nhé!',
      'understood': 'Đã hiểu',
      'awesome': 'Tuyệt vời!',
      'savings': 'Tích luỹ',
      'total_target': 'TỔNG TÍCH LUỸ',
      'total_spent_cat': 'TỔNG CHI TIÊU',
      'num_transactions': '{count} giao dịch',
      'no_transactions': 'Chưa có giao dịch nào',
      'unnamed_transaction': 'Giao dịch chưa đặt tên',
      'monthly_goal_label': 'Mục tiêu tháng',
      'short_term_goal': 'Kế hoạch ngắn hạn',
      'long_term_goal': 'Hành trình dài hạn',
      'target_amount': 'Số tiền mục tiêu',
      'target_date': 'Hạn hoàn thành',
      'days_left': 'còn {count} ngày',
      'months_left': 'còn {count} tháng',
      'need_more': 'Cần nạp thêm {amount} / ngày',
      'done_this_month': 'Bạn đã hoàn thành chỉ tiêu tháng này.',
      'overdue': 'Hạn đã qua',
      'basic_info': 'THÔNG TIN CƠ BẢN',
      'category_name': 'Tên danh mục',
      'budget_monthly': 'Ngân sách hàng tháng (Tùy chọn)',
      'goal_amount_monthly': 'Số tiền nạp mỗi tháng',
      'goal_type': 'HÌNH THỨC',
      'recurring_monthly': 'Định kỳ',
      'goal': 'Mục tiêu',
      'reminder_day': 'Ngày nạp tiền hàng tháng',
      'target_month': 'Tháng hoàn thành',
      'target_year': 'Năm hoàn thành',
      'colors': 'MÀU SẮC',
      'icons': 'BIỂU TƯỢNG',
      'create_category': 'TẠO DANH MỤC',
      'save_changes': 'LƯU THAY ĐỔI',
      'delete_cat_confirm': 'Xoá danh mục & dữ liệu?',
      'delete_cat_confirm_msg':
          'Danh mục "{name}" hiện đang chứa {count} giao dịch. Nếu xoá, toàn bộ dữ liệu sẽ bị mất vĩnh viễn.',
      'delete_cat_simple': 'Xoá danh mục?',
      'delete_cat_simple_msg': 'Bạn có chắc chắn muốn xoá danh mục {name}?',
      'no_cat_expense': 'Chưa có danh mục chi phí',
      'no_cat_income': 'Chưa có danh mục thu nhập',
      'no_cat_savings': 'Chưa có mục tiêu tích luỹ nào',
      'over_budget': 'Vượt quá',
      'target_achieved': 'Đã đạt mục tiêu!',
      'monthly_progress': 'Tiến độ tháng',
      'journey': 'Hành trình',
      'delete_cat_success': 'Đã xoá danh mục "{name}"',
      'accumulate_periodic': 'Tích luỹ định kỳ',
      'accumulate_goal': 'Tích luỹ mục tiêu',
      'total_savings_label': 'Tổng tích luỹ',
      'enter_cat_name': 'Vui lòng nhập tên danh mục!',
    },
    'en': {
      'app_title': 'Sheepify',
      'settings': 'Settings',
      'home': 'Home',
      'categories': 'Categories',
      'stats': 'Statistics',
      'diary': 'Diary',
      'balance': 'Balance',
      'total_balance': 'Total Balance',
      'income': 'Income',
      'expense': 'Expense',
      'accumulate_balance': 'Roll over balance from last month',
      'accumulate_subtitle':
          'Balance for this month will include available balance from previous months.',
      'system_settings': 'SYSTEM SETTINGS',
      'theme': 'Theme & Colors',
      'language': 'Language',
      'currency': 'Currency',
      'font': 'Font Family',
      'version': 'Version',
      'user_greeting': 'Sheepify User',
      'user_sub': 'Simple Finance Management',
      'confirm': 'Confirm',
      'cancel': 'Cancel',
      'day': 'Day',
      'month': 'Month',
      'monthly_balance': 'MONTHLY BALANCE',
      'daily_balance': 'DAILY BALANCE',
      'no_tx_month': 'No transactions this month',
      'no_tx_today': 'No transactions today',
      'delete_confirm_title': 'Delete transaction?',
      'delete_confirm_msg':
          'Are you sure you want to delete this transaction? This action cannot be undone.',
      'delete': 'Delete',
      'delete_success': 'Transaction deleted',
      'wallet_balance': 'WALLET BALANCE',
      'total_expense': 'TOTAL EXPENSE',
      'total_income': 'TOTAL INCOME',
      'total_savings': 'TOTAL SAVINGS',
      'prev_balance': 'Previous Balance',
      'accumulated_from_prev': 'Accumulated balance from previous months',
      'other': 'Other',
      'no_data_expense': 'No expense data found!',
      'no_data_income': 'No income data found!',
      'no_data_savings': 'No savings data found!',
      'save': 'SAVE',
      'update': 'UPDATE',
      'upload_image': 'UPLOAD IMAGE',
      'take_photo': 'Take Photo',
      'choose_gallery': 'Pick from Gallery',
      'error_input': 'Please enter amount and choose category!',
      'tx_updated': 'Transaction updated',
      'tx_added': 'Transaction added successfully',
      'budget_warning': 'Budget Warning!',
      'budget_msg':
          'You have exceeded the budget for "{name}". Please consider your spending!',
      'goal_congrats': 'Congratulations!',
      'goal_msg': 'Awesome! You have reached your savings goal. Keep it up!',
      'understood': 'Understood',
      'awesome': 'Awesome!',
      'savings': 'Savings',
      'total_target': 'TOTAL ACCUMULATED',
      'total_spent_cat': 'TOTAL SPENT',
      'num_transactions': '{count} transactions',
      'no_transactions': 'No transactions found',
      'unnamed_transaction': 'Unnamed transaction',
      'monthly_goal_label': 'Monthly Goal',
      'short_term_goal': 'Short-term plan',
      'long_term_goal': 'Long-term journey',
      'target_amount': 'Target amount',
      'target_date': 'Target date',
      'days_left': '{count} days left',
      'months_left': '{count} months left',
      'need_more': 'Needs {amount} / day more',
      'done_this_month': 'You have reached your goal for this month.',
      'overdue': 'Overdue',
      'basic_info': 'BASIC INFO',
      'category_name': 'Category Name',
      'budget_monthly': 'Monthly Budget (Optional)',
      'goal_amount_monthly': 'Monthly savings goal',
      'goal_type': 'GOAL TYPE',
      'recurring_monthly': 'Periodic',
      'goal': 'Goal',
      'reminder_day': 'Monthly deposit day',
      'target_month': 'Target month',
      'target_year': 'Target year',
      'colors': 'COLORS',
      'icons': 'ICONS',
      'create_category': 'CREATE CATEGORY',
      'save_changes': 'SAVE CHANGES',
      'delete_cat_confirm': 'Delete category & data?',
      'delete_cat_confirm_msg':
          'Category "{name}" contains {count} transactions. If deleted, data will be lost forever.',
      'delete_cat_simple': 'Delete category?',
      'delete_cat_simple_msg':
          'Are you sure you want to delete category {name}?',
      'no_cat_expense': 'No expense categories yet',
      'no_cat_income': 'No income categories yet',
      'no_cat_savings': 'No savings goals yet',
      'over_budget': 'Over budget',
      'target_achieved': 'Goal achieved',
      'monthly_progress': 'Monthly progress',
      'journey': 'Journey',
      'delete_cat_success': 'Category "{name}" deleted',
      'accumulate_periodic': 'Periodic Savings',
      'accumulate_goal': 'Goal Savings',
      'total_savings_label': 'Total savings',
      'enter_cat_name': 'Please enter category name!',
    },
  };

  String get(String key, {Map<String, String>? params}) {
    String value = _localizedValues[locale.languageCode]?[key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }

  // Helper getters
  String get appTitle => get('app_title');
  String get settings => get('settings');
  String get home => get('home');
  String get categories => get('categories');
  String get stats => get('stats');
  String get diary => get('diary');
  String get totalBalance => get('total_balance');
  String get income => get('income');
  String get expense => get('expense');
  String get savings => get('savings');
  String get accumulateBalance => get('accumulate_balance');
  String get accumulateSubtitle => get('accumulate_subtitle');
  String get systemSettings => get('system_settings');
  String get theme => get('theme');
  String get language => get('language');
  String get currency => get('currency');
  String get font => get('font');
  String get versionLabel => get('version');
  String get userGreeting => get('user_greeting');
  String get userSub => get('user_sub');
  String get confirm => get('confirm');
  String get cancel => get('cancel');
  String get delete => get('delete');
  String get save => get('save');
  String get updateLabel => get('update');
  String get uploadImage => get('upload_image');
  String get takePhoto => get('take_photo');
  String get chooseGallery => get('choose_gallery');
  String get targetAchieved => get('target_achieved');
  String get travel => get('journey');
  String get monthlyProgress => get('monthly_progress');
  String get unnamedTransaction => get('unnamed_transaction');
  String get overBudget => get('over_budget');
  String get recurringMonthly => get('recurring_monthly');
  String get goal => get('goal');
  String get balance => get('balance');
}

class L10nDelegate extends LocalizationsDelegate<L10n> {
  const L10nDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(L10nDelegate old) => false;
}
