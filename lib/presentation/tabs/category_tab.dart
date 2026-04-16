import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction.dart';
import '../widgets/category_form.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_toggles.dart';
import '../widgets/common/sheep_dialogs.dart';
import '../widgets/common/sheep_notifications.dart';
import '../widgets/category/transaction_history_sheet.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  int _selectedTypeIndex = 0; // 0: expense, 1: income, 2: savings

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. MODE TOGGLE ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SheepTripleToggle(
            selectedIndex: _selectedTypeIndex,
            onChanged: (val) => setState(() => _selectedTypeIndex = val),
          ),
        ),

        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              Hive.box<CategoryModel>(kCatBox).listenable(),
              Hive.box<Transaction>(kMoneyBox).listenable(),
            ]),
            builder: (context, _) {
              final box = Hive.box<CategoryModel>(kCatBox);
              final txBox = Hive.box<Transaction>(kMoneyBox);
              final now = DateTime.now();

              List<Transaction> allTransactions = txBox.values.toList();
              
              // Map to store relevant spent amount based on category's goal type
              Map<String, double> categorySpent = {};

              final categories = box.values
                  .where((c) => c.effectiveTypeIndex == _selectedTypeIndex)
                  .toList();

              for (var cat in categories) {
                double spent = 0;
                final goalType = cat.effectiveGoalTypeIndex;
                if (goalType == 1) {
                  // Monthly goal: only current month
                  spent = allTransactions
                      .where((tx) => tx.categoryId == cat.id && tx.date.month == now.month && tx.date.year == now.year)
                      .fold(0.0, (sum, tx) => sum + tx.amount);
                } else if (goalType == 2) {
                  // Long-term goal: all history
                  spent = allTransactions
                      .where((tx) => tx.categoryId == cat.id)
                      .fold(0.0, (sum, tx) => sum + tx.amount);
                } else {
                  // Standard Income/Expense: usually current month
                  spent = allTransactions
                      .where((tx) => tx.categoryId == cat.id && tx.date.month == now.month && tx.date.year == now.year)
                      .fold(0.0, (sum, tx) => sum + tx.amount);
                }
                categorySpent[cat.id] = spent;
              }

              if (categories.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final spent = categorySpent[cat.id] ?? 0;

                  return Dismissible(
                    key: ValueKey(cat.id),
                    direction: DismissDirection.endToStart,
                    background: _buildDeleteBackground(),
                    confirmDismiss: (_) => _confirmDelete(context, cat),
                    onDismissed: (_) {
                      final name = cat.name;
                      cat.delete();
                      SheepNotifications.showSuccess(
                        context,
                        'Đã xoá danh mục "$name"',
                      );
                    },
                    child: SheepCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => _showTransactionHistory(context, cat, allTransactions),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _buildIcon(cat),
                              const SizedBox(width: 15),
                              _buildInfo(cat, spent),
                              IconButton(
                                icon: const Icon(LineIcons.edit, color: Colors.grey),
                                onPressed: () => _showCategoryForm(context, cat),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LineIcons.tags, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            _selectedTypeIndex == 0 
                ? 'Chưa có danh mục chi phí' 
                : (_selectedTypeIndex == 1 ? 'Chưa có danh mục thu nhập' : 'Chưa có mục tiêu tích luỹ nào'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(CategoryModel cat) {
    Color color;
    if (_selectedTypeIndex == 0) color = AppColors.expense;
    else if (_selectedTypeIndex == 1) color = AppColors.income;
    else color = AppColors.savings;
    
    if (cat.colorValue != null) color = Color(cat.colorValue!);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        cat.iconData,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildInfo(CategoryModel cat, double spent) {
    bool isSavings = _selectedTypeIndex == 2;
    double? target = isSavings ? cat.targetAmount : cat.budget;
    final remaining = (target ?? 0) - spent;
    
    String goalSubtitle = '';
    if (isSavings) {
      final goalType = cat.effectiveGoalTypeIndex;
      if (goalType == 1) {
        goalSubtitle = 'Mục tiêu tháng: ${CurrencyUtil.formatMoney(cat.targetAmount!)}';
      } else if (goalType == 2) {
        goalSubtitle = 'Hạn T${cat.targetMonth}/${cat.targetYear}: ${CurrencyUtil.formatMoney(cat.targetAmount!)}';
      } else {
        goalSubtitle = 'Mục tiêu ${cat.targetYear}: ${CurrencyUtil.formatMoney(cat.targetAmount!)}';
      }
    } else {
      goalSubtitle = 'Ngân sách: ${CurrencyUtil.formatMoney(cat.budget ?? 0)}';
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cat.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_selectedTypeIndex == 0 && cat.budget != null && remaining < 0)
                Text(
                  CurrencyUtil.formatMoney(remaining),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense,
                  ),
                ),
              if (isSavings && cat.targetAmount != null && remaining <= 0)
                const Icon(Icons.check_circle, color: AppColors.savings, size: 20),
            ],
          ),
          if (target != null && target > 0) ...[
            const SizedBox(height: 10),
            _buildProgressBar(cat, spent),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isSavings 
                        ? (remaining <= 0 ? 'Đã đạt mục tiêu!' : (cat.effectiveGoalTypeIndex == 1 ? 'Tiến độ tháng' : 'Hành trình'))
                        : (remaining < 0 ? 'Vượt quá' : ''),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    goalSubtitle,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(CategoryModel cat, double spent) {
    double? target = _selectedTypeIndex == 2 ? cat.targetAmount : cat.budget;
    double progress = (target != null && target > 0)
        ? (spent / target)
        : 0.0;
    if (progress > 1.0) progress = 1.0;
    if (progress < 0) progress = 0;

    final baseColor = cat.colorValue != null ? Color(cat.colorValue!) : (_selectedTypeIndex == 2 ? AppColors.savings : AppColors.primary);
    final barColor = (_selectedTypeIndex == 0 && spent > (cat.budget ?? 0)) ? AppColors.expense : baseColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: barColor.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }


  Widget _buildDeleteBackground() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.expense.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(LineIcons.trash, color: AppColors.expense),
    );
  }

  void _showTransactionHistory(BuildContext context, CategoryModel cat, List<Transaction> txs) {
    final catTxs = txs.where((tx) => tx.categoryId == cat.id).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionHistorySheet(category: cat, transactions: catTxs),
    );
  }

  void _showCategoryForm(BuildContext context, CategoryModel? category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => CategoryForm(category: category),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, CategoryModel item) {
    final txBox = Hive.box<Transaction>(kMoneyBox);
    final relatedTxsCount =
        txBox.values.where((tx) => tx.categoryId == item.id).length;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => SheepConfirmDialog(
        title: relatedTxsCount > 0 ? 'Xoá danh mục & dữ liệu?' : 'Xoá danh mục?',
        richContent: Text.rich(
          TextSpan(
            text: relatedTxsCount > 0
                ? 'Danh mục '
                : 'Bạn có chắc chắn muốn xoá danh mục ',
            children: [
              TextSpan(
                text: '"${item.name}"',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (relatedTxsCount > 0) ...[
                const TextSpan(text: ' hiện đang chứa '),
                TextSpan(
                  text: '$relatedTxsCount giao dịch',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(
                  text:
                      '. Nếu xoá danh mục này, toàn bộ dữ liệu giao dịch liên quan sẽ bị mất vĩnh viễn. Bạn có chắc muốn tiếp tục?',
                ),
              ] else
                const TextSpan(text: '?'),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        confirmLabel: relatedTxsCount > 0 ? 'Xoá tất cả' : 'Xoá',
        onConfirm: () {},
      ),
    );
  }
}
