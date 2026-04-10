import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../models/transaction.dart';
import '../models/category_model.dart';
import '../constants.dart';
import '../widgets/transaction_form.dart';

class DiaryTab extends StatefulWidget {
  final DateTime currentDay;
  const DiaryTab({super.key, required this.currentDay});

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  String formatMoney(double amount) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);

  void _confirmDelete(BuildContext context, Transaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              tx.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa giao dịch thành công'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Xóa Vĩnh Viễn',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Transaction>(kMoneyBox).listenable(),
      builder: (context, box, _) {
        final catBox = Hive.box<CategoryModel>(kCatBox);

        final transactions = box.values.cast<Transaction>().where((tx) {
          return tx.date.day == widget.currentDay.day &&
              tx.date.month == widget.currentDay.month &&
              tx.date.year == widget.currentDay.year;
        }).toList();

        transactions.sort((a, b) => b.date.compareTo(a.date));

        double dailyIncome = 0;
        double dailyExpense = 0;
        for (var tx in transactions) {
          if (tx.isExpense)
            dailyExpense += tx.amount;
          else
            dailyIncome += tx.amount;
        }

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Thu Nhập',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        formatMoney(dailyIncome),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Column(
                    children: [
                      const Text(
                        'Chi Tiêu',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        formatMoney(dailyExpense),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Column(
                    children: [
                      const Text('Tổng', style: TextStyle(color: Colors.grey)),
                      Text(
                        formatMoney(dailyIncome - dailyExpense),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: transactions.isEmpty
                  // --- CẬP NHẬT EMPTY STATE TO RÕ ---
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/empty.json',
                            width:
                                MediaQuery.of(context).size.width *
                                0.8, // 80% màn hình
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Ngày ${DateFormat('dd/MM').format(widget.currentDay)} không có giao dịch',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final childCat = catBox.values.firstWhere(
                          (c) => c.id == tx.categoryId,
                          orElse: () => CategoryModel(
                            id: '',
                            name: '?',
                            iconCode: Icons.help.codePoint,
                            isExpense: true,
                            parentId: null,
                          ),
                        );
                        String parentName = '';
                        if (childCat.parentId != null) {
                          try {
                            parentName = catBox.values
                                .firstWhere((c) => c.id == childCat.parentId)
                                .name;
                          } catch (_) {}
                        }
                        final titleText = parentName.isNotEmpty
                            ? '$parentName - ${childCat.name}'
                            : childCat.name;

                        return Dismissible(
                          key: ValueKey(tx.key),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 30,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Xác nhận xóa'),
                                content: const Text(
                                  'Bạn có chắc muốn xóa giao dịch này không?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            tx.delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã xóa giao dịch thành công'),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tx.isExpense
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      IconData(
                                        childCat.iconCode,
                                        fontFamily: 'MaterialIcons',
                                      ),
                                      color: tx.isExpense
                                          ? Colors.red
                                          : Colors.green,
                                      size: 22,
                                    ),
                                    if (tx.imagePath != null) ...[
                                      const SizedBox(width: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.file(
                                          File(tx.imagePath!),
                                          width: 30,
                                          height: 30,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              title: Text(
                                titleText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: tx.note.isNotEmpty
                                  ? Text(tx.note)
                                  : null,
                              trailing: Text(
                                formatMoney(tx.amount),
                                style: TextStyle(
                                  color: tx.isExpense
                                      ? Colors.red
                                      : Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                final result = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) =>
                                      TransactionForm(transaction: tx),
                                );
                                if (result != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Cập nhật thành công!'),
                                      backgroundColor: Colors.teal,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              onLongPress: () => _confirmDelete(context, tx),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
