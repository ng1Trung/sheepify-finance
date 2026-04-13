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
  final Map<String, bool> _expandedMap = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 1. MODE TOGGLE (PILL STYLE - SAME AS STATS) ---
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

              return _buildCategoryList(
                context,
                _isExpenseMode,
                box,
                categorySpent,
                monthTxs,
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

  Widget _buildCategoryList(
    BuildContext context,
    bool isExpense,
    Box<CategoryModel> box,
    Map<String, double> categorySpent,
    List<Transaction> monthTxs,
  ) {
    final parents = box.values
        .where((c) => c.parentId == null && c.isExpense == isExpense)
        .toList();

    if (parents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.tags, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              'Chưa có nhóm ${isExpense ? "chi" : "thu"} nào',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
      itemCount: parents.length,
      itemBuilder: (context, index) {
        final parent = parents[index];
        final children = box.values
            .where((c) => c.parentId == parent.id)
            .toList();
        final isExpanded = _expandedMap[parent.id] ?? true;

        // Total group spent
        double totalGroupSpent = (categorySpent[parent.id] ?? 0);
        for (var child in children) {
          totalGroupSpent += (categorySpent[child.id] ?? 0);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PARENT CARD
              Dismissible(
                key: ValueKey(parent.id),
                direction: DismissDirection.endToStart,
                background: _buildDeleteBackground(),
                confirmDismiss: (_) =>
                    _confirmDeleteParent(context, parent, children.length),
                onDismissed: (_) => parent.delete(),
                child: SheepCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(
                          () => _expandedMap[parent.id] = !isExpanded,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      (isExpense
                                              ? AppColors.expense
                                              : AppColors.income)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  IconData(
                                    parent.iconCode,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  color: isExpense
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
                                      parent.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isExpense && parent.budget != null) ...[
                                      Text(
                                        'Còn: ${CurrencyUtil.formatMoney(parent.budget! - totalGroupSpent)} / ${CurrencyUtil.formatMoney(parent.budget!)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              (parent.budget! -
                                                      totalGroupSpent) <
                                                  0
                                              ? AppColors.expense
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ] else
                                      Text(
                                        '${children.length} danh mục con',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(fontSize: 10),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // ACTIONS
                              IconButton(
                                icon: const Icon(
                                  LineIcons.edit,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    _showCategoryForm(context, parent),
                              ),
                              Icon(
                                isExpanded
                                    ? LineIcons.angleUp
                                    : LineIcons.angleDown,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpense && parent.budget != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (totalGroupSpent / parent.budget!).clamp(
                                0,
                                1,
                              ),
                              minHeight: 3,
                              backgroundColor: Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation(
                                totalGroupSpent > parent.budget!
                                    ? AppColors.expense
                                    : AppColors.income,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // CHILDREN LIST (ANIMATED)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: !isExpanded || children.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Column(
                          children: children
                              .map(
                                (child) => Dismissible(
                                  key: ValueKey(child.id),
                                  direction: DismissDirection.endToStart,
                                  background: _buildDeleteBackground(),
                                  confirmDismiss: (_) =>
                                      _confirmDeleteChild(context, child),
                                  onDismissed: (_) => child.delete(),
                                  child: SheepListTile(
                                    onTap: () => _showTransactionHistory(
                                      context,
                                      child,
                                      monthTxs,
                                    ),
                                    title: child.name,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isExpense)
                                          Text(
                                            '- ${CurrencyUtil.formatMoney(categorySpent[child.id] ?? 0)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        const SizedBox(width: 5),
                                        IconButton(
                                          icon: const Icon(
                                            LineIcons.edit,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () =>
                                              _showCategoryForm(context, child),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
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
    final catTxs = allMonthTxs
        .where((tx) => tx.categoryId == category.id)
        .toList();

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
                  Icon(
                    IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                    color: AppColors.primary,
                  ),
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
                        color:
                            category.isExpense
                                ? AppColors.expense
                                : AppColors.income,
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
                          leading: const Icon(
                            LineIcons.receipt,
                            color: Colors.grey,
                            size: 20,
                          ),
                          title: catTxs[i].note.isNotEmpty
                              ? catTxs[i].note
                              : 'Giao dịch',
                          subtitle: DateFormat(
                            'dd/MM/yyyy - HH:mm',
                          ).format(catTxs[i].date),
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

  Future<bool?> _confirmDeleteChild(BuildContext context, CategoryModel item) {
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

  Future<bool?> _confirmDeleteParent(
    BuildContext context,
    CategoryModel parent,
    int childCount,
  ) async {
    if (childCount > 0) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Không thể xóa!'),
          content: Text(
            'Nhóm "${parent.name}" đang chứa $childCount danh mục con. Vui lòng xóa con trước.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'ĐÃ HIỂU',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      return false;
    }
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhóm?'),
        content: Text('Xóa nhóm rỗng "${parent.name}"?'),
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
