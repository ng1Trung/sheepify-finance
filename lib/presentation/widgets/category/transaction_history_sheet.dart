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

    final double monthlyTotal = transactions.fold(0.0, (sum, tx) => sum + tx.amount);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildDragHandle(),
            const SizedBox(height: 25),
            
            _buildHeader(catColor, monthlyTotal),
            
            const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: catColor.withOpacity(0.2)),
            ),
            child: Icon(category.iconData, color: catColor, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${transactions.length} transactions this month',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textSecondary),
              ),
              Text(
                CurrencyUtil.formatMoney(total),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: category.isExpense ? AppColors.expense : AppColors.income,
                ),
              ),
            ],
          ),
        ],
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
              'No transactions found',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
          title: tx.note.isNotEmpty ? tx.note : 'Untitled Transaction',
          subtitle: DateFormat('MMMM dd, yyyy').format(tx.date),
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
}
