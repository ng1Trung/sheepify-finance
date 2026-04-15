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
    return DraggableScrollableSheet(
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
                Icon(category.iconData, color: category.colorValue != null ? Color(category.colorValue!) : AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (transactions.isNotEmpty)
                  Text(
                    'This Month: ${CurrencyUtil.formatMoney(transactions.fold(0.0, (sum, tx) => sum + tx.amount))}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: category.isExpense ? AppColors.expense : AppColors.income,
                    ),
                  ),
              ],
            ),
            const Divider(height: 30),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions this month',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: transactions.length,
                      itemBuilder: (_, i) => SheepListTile(
                        onTap: () {},
                        leading: const Icon(LineIcons.receipt, color: Colors.grey, size: 20),
                        title: transactions[i].note.isNotEmpty ? transactions[i].note : 'Transaction',
                        subtitle: DateFormat('MM/dd/yyyy').format(transactions[i].date),
                        trailing: Text(
                          CurrencyUtil.formatMoney(transactions[i].amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
