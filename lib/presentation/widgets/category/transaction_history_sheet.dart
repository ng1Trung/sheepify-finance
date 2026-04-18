import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction.dart';
import '../common/sheep_widgets.dart';

class TransactionHistorySheet extends StatelessWidget {
  final CategoryModel category;
  final List<Transaction> transactions;

  const TransactionHistorySheet({
    super.key,
    required this.category,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final Color catColor = category.colorValue != null 
        ? Color(category.colorValue!) 
        : AppColors.primary;

    final double totalAccumulated = transactions.fold(0.0, (sum, tx) => sum + tx.amount);
    final DateTime now = DateTime.now();
    final double totalInMonth = transactions
        .where((tx) => tx.date.month == now.month && tx.date.year == now.year)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final bool isSavings = category.effectiveTypeIndex == 2;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildDragHandle(),
            const SizedBox(height: 15),
            
            _buildHeader(catColor, totalAccumulated),
            
            if (isSavings && category.targetAmount != null) ...[
              const SizedBox(height: 15),
              _buildGoalDashboard(catColor, totalAccumulated),
            ],
            
            const SizedBox(height: 15),
            Expanded(
              child: _buildTransactionList(scrollController, catColor),
            ),
          ],
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

  Widget _buildHeader(Color catColor, double total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(category.iconData, color: catColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                    Text(
                      '${transactions.length} giao dịch',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.7)),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.effectiveTypeIndex == 2 ? 'TỔNG MỤC TIÊU' : 'TỔNG CHI TIÊU',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.textSecondary),
                ),
                Text(
                  CurrencyUtil.formatMoney(total),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: category.effectiveTypeIndex == 2 
                        ? AppColors.savings 
                        : (category.effectiveTypeIndex == 0 ? AppColors.expense : AppColors.income),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(ScrollController controller, Color catColor) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.history, size: 50, color: Colors.grey[200]),
            const SizedBox(height: 10),
            Text(
              'Chưa có giao dịch nào',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      itemCount: transactions.length,
      itemBuilder: (_, i) {
        final tx = transactions[i];
        return SheepListTile(
          onTap: () {},
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(category.iconData, color: catColor, size: 18),
          ),
          title: tx.note.isNotEmpty ? tx.note : 'Giao dịch chưa đặt tên',
          subtitle: Text(
            DateFormat('dd/MM/yyyy').format(tx.date),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: Text(
            '${tx.isExpense ? '-' : '+'}${CurrencyUtil.formatMoney(tx.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: tx.isExpense ? AppColors.expense : AppColors.income,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalDashboard(Color catColor, double totalAllTime) {
    final now = DateTime.now();
    final totalInMonth = transactions
        .where((tx) => tx.date.month == now.month && tx.date.year == now.year)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final goalType = category.effectiveGoalTypeIndex;
    if (goalType == 1) {
      // --- LOẠI: ĐỊNH KỲ HÀNG THÁNG ---
      final target = category.targetAmount ?? 0;
      final remaining = target - totalInMonth;
      final progress = target > 0 ? (totalInMonth / target).clamp(0.0, 1.0) : 0.0;
      
      // Calculate days left until reminder day in this month
      int reminderDay = category.reminderDay ?? 10;
      // Handle end of month
      int lastDay = DateTime(now.year, now.month + 1, 0).day;
      if (reminderDay > lastDay) reminderDay = lastDay;
      
      int daysLeft = reminderDay - now.day;
      String infoText = "";
      String planningText = "";
      
      if (daysLeft > 0 && remaining > 0) {
        final daily = remaining / daysLeft;
        infoText = "Cần nạp thêm ${CurrencyUtil.formatMoney(daily)} / ngày";
        planningText = "Hạn nạp: Ngày $reminderDay tháng này (còn $daysLeft ngày)";
      } else if (remaining <= 0) {
        planningText = "Tuyệt vời! Bạn đã hoàn thành chỉ tiêu tháng này.";
      } else {
        planningText = "Lẽ ra bạn phải hoàn thành vào ngày $reminderDay.";
      }

      return _buildDashboardCard(
        title: "MỤC TIÊU THÁNG ${now.month}",
        subtitle: planningText,
        progress: progress,
        info: infoText,
        footerLeft: "Đã có: ${CurrencyUtil.formatMoney(totalInMonth)}",
        footerRight: "Mục tiêu: ${CurrencyUtil.formatMoney(target)}",
      );
    } else if (goalType == 2 || goalType == 3) {
      // --- LOẠI: MỤC TIÊU DÀI HẠN / NGẮN HẠN ---
      final target = category.targetAmount ?? 0;
      final remaining = target - totalAllTime;
      final progress = target > 0 ? (totalAllTime / target).clamp(0.0, 1.0) : 0.0;
      
      final targetDate = category.targetDate ?? DateTime(category.targetYear ?? now.year, 12, 31);
      final monthsLeft = ((targetDate.year - now.year) * 12) + targetDate.month - now.month;
      
      String infoText = "";
      String planningText = "";
      
      if (monthsLeft > 0 && remaining > 0) {
        final monthly = remaining / monthsLeft;
        infoText = "Mỗi tháng nên cất đi: ${CurrencyUtil.formatMoney(monthly)}";
        planningText = "Hạn hoàn thành: ${DateFormat('MM/yyyy').format(targetDate)} (còn $monthsLeft tháng)";
      } else if (remaining <= 0) {
        planningText = "Chúc mừng! Bạn đã đạt mục tiêu lớn.";
      } else {
        planningText = "Hạn đã qua (${DateFormat('MM/yyyy').format(targetDate)})";
      }

      return _buildDashboardCard(
        title: goalType == 2 ? "KẾ HOẠCH NGẮN HẠN" : "HÀNH TRÌNH DÀI HẠN",
        subtitle: planningText,
        progress: progress,
        info: infoText,
        footerLeft: "Đã có: ${CurrencyUtil.formatMoney(totalAllTime)}",
        footerRight: "Mục tiêu: ${CurrencyUtil.formatMoney(target)}",
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required double progress,
    required String info,
    required String footerLeft,
    required String footerRight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.savings.withOpacity(0.05),
              AppColors.savings.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.savings.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.savings, letterSpacing: 1),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.savings),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.savings.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.savings),
              ),
            ),
            if (info.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LineIcons.calculator, size: 16, color: AppColors.savings),
                  const SizedBox(width: 8),
                  Text(
                    info,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.savings),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(footerLeft, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text(footerRight, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
