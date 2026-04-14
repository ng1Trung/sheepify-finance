import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction.dart';
import '../widgets/category_form.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';

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
        // --- 1. MODE TOGGLE (PILL STYLE) ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleItem(
                    "Chi",
                    _isExpenseMode,
                    AppColors.expense,
                  ),
                ),
                Expanded(
                  child: _buildToggleItem(
                    "Thu",
                    !_isExpenseMode,
                    AppColors.income,
                  ),
                ),
              ],
            ),
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
                    (tx) =>
                        tx.date.month == now.month && tx.date.year == now.year,
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LineIcons.tags, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text(
                        'Chưa có danh mục ${_isExpenseMode ? "chi" : "thu"} nào',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
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
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (_isExpenseMode
                                          ? AppColors.expense
                                          : AppColors.income)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  cat.iconData,
                                  color: _isExpenseMode
                                      ? AppColors.expense
                                      : AppColors.income,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_isExpenseMode && cat.budget != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Còn: ${CurrencyUtil.formatMoney(cat.budget! - spent)} / ${CurrencyUtil.formatMoney(cat.budget!)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: (cat.budget! - spent) < 0
                                              ? AppColors.expense
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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

  Widget _buildToggleItem(String title, bool isActive, Color color) {
    return GestureDetector(
      onTap: () => setState(() => _isExpenseMode = (title == "Chi")),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          boxShadow: isActive ? AppColors.softShadow : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? color : AppColors.textSecondary,
          ),
        ),
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

  void _showTransactionHistory(
    BuildContext context,
    CategoryModel category,
    List<Transaction> allMonthTxs,
  ) {
    final catTxs = allMonthTxs.where((tx) => tx.categoryId == category.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(category.iconData, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (catTxs.isNotEmpty)
                    Text(
                      'Tháng này: ${CurrencyUtil.formatMoney(catTxs.fold(0.0, (sum, tx) => sum + tx.amount))}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: category.isExpense ? AppColors.expense : AppColors.income,
                      ),
                    ),
                ],
              ),
              const Divider(height: 30),
              Expanded(
                child: catTxs.isEmpty
                    ? Center(
                        child: Text(
                          'Không có giao dịch nào trong tháng',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: catTxs.length,
                        itemBuilder: (_, i) => SheepListTile(
                          onTap: () {},
                          leading: const Icon(LineIcons.receipt, color: Colors.grey, size: 20),
                          title: catTxs[i].note.isNotEmpty ? catTxs[i].note : 'Giao dịch',
                          subtitle: DateFormat('dd/MM/yyyy - HH:mm').format(catTxs[i].date),
                          trailing: Text(
                            CurrencyUtil.formatMoney(catTxs[i].amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryForm(BuildContext context, CategoryModel? category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => CategoryForm(category: category),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, CategoryModel item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh mục?'),
        content: Text('Bạn muốn xóa danh mục "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }
}
