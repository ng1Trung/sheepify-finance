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
import '../widgets/category/transaction_history_sheet.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  bool _isExpenseMode = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. MODE TOGGLE ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SheepTypeToggle(
            isExpense: _isExpenseMode,
            leftLabel: "Chi phí",
            rightLabel: "Thu nhập",
            onChanged: (val) => setState(() => _isExpenseMode = val),
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

              // Calculate spent per category
              Map<String, double> categorySpent = {};
              List<Transaction> monthTxs = txBox.values
                  .where(
                    (tx) => tx.date.month == now.month && tx.date.year == now.year,
                  )
                  .toList();

              for (var tx in monthTxs) {
                categorySpent[tx.categoryId] =
                    (categorySpent[tx.categoryId] ?? 0) + tx.amount;
              }

              final categories = box.values
                  .where((c) => c.isExpense == _isExpenseMode)
                  .toList();

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
                    onDismissed: (_) => cat.delete(),
                    child: SheepCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => _showTransactionHistory(context, cat, monthTxs),
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
            'Chưa có danh mục ${_isExpenseMode ? "chi phí" : "thu nhập"}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(CategoryModel cat) {
    final color = cat.colorValue != null ? Color(cat.colorValue!) : (_isExpenseMode ? AppColors.expense : AppColors.income);
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
    final remaining = (cat.budget ?? 0) - spent;
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
              if (_isExpenseMode && cat.budget != null && remaining < 0)
                Text(
                  CurrencyUtil.formatMoney(remaining),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense,
                  ),
                ),
            ],
          ),
          if (_isExpenseMode && cat.budget != null) ...[
            const SizedBox(height: 10),
            _buildProgressBar(cat, spent),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  remaining < 0 ? 'Vượt quá' : '',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
                Text(
                  'Ngân sách: ${CurrencyUtil.formatMoney(cat.budget!)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(CategoryModel cat, double spent) {
    double progress = spent / (cat.budget ?? 1.0);
    if (progress > 1.0) progress = 1.0;
    if (progress < 0) progress = 0;

    final baseColor = cat.colorValue != null ? Color(cat.colorValue!) : AppColors.primary;
    final barColor = (spent > (cat.budget ?? 0)) ? AppColors.expense : baseColor;

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
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá danh mục?'),
        content: Text('Bạn có chắc chắn muốn xoá danh mục "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
