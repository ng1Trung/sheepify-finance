import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/transaction_form.dart';

class DiaryTab extends StatefulWidget {
  final DateTime selectedDate;
  final bool isMonthly;
  const DiaryTab({
    super.key,
    required this.selectedDate,
    required this.isMonthly,
  });

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, settingsBox, _) {
        final settings = settingsBox.get('current') ?? AppSettings();
        
        return ValueListenableBuilder(
          valueListenable: Hive.box<Transaction>(kMoneyBox).listenable(),
          builder: (context, box, _) {
            final catBox = Hive.box<CategoryModel>(kCatBox);

            // 1. Lấy và lọc giao dịch để tính số dư
            var calcTxs = box.values.cast<Transaction>().toList();
            
            // Nếu KHÔNG cộng dồn -> Chỉ tính từ đầu tháng này
            if (!settings.accumulateBalance) {
              calcTxs = calcTxs.where((tx) => 
                tx.date.year == widget.selectedDate.year && 
                tx.date.month == widget.selectedDate.month
              ).toList();
            }

            calcTxs.sort((a, b) {
              int cmp = a.date.compareTo(b.date);
              if (cmp == 0) return a.key.toString().compareTo(b.key.toString());
              return cmp;
            });

            Map<dynamic, double> runningBalances = {};
            double currentTotal = 0;
            for (var tx in calcTxs) {
              if (tx.isExpense) {
                currentTotal -= tx.amount;
              } else {
                currentTotal += tx.amount;
              }
              runningBalances[tx.key] = currentTotal;
            }

            // 2. Lọc giao dịch hiển thị (lọc theo Ngày/Tháng đang chọn trên UI)
            final displayTxs = box.values.cast<Transaction>().where((tx) {
              if (widget.isMonthly) {
                return tx.date.month == widget.selectedDate.month &&
                       tx.date.year == widget.selectedDate.year;
              } else {
                return tx.date.day == widget.selectedDate.day &&
                       tx.date.month == widget.selectedDate.month &&
                       tx.date.year == widget.selectedDate.year;
              }
            }).toList();

            // 3. Tính toán Thống kê Summary cho vùng hiển thị
            double totalIncome = 0;
            double totalExpense = 0;
            for (var tx in displayTxs) {
              if (tx.isExpense) totalExpense += tx.amount;
              else totalIncome += tx.amount;
            }

            // 4. Gom nhóm theo ngày
            Map<String, List<Transaction>> grouped = {};
            for (var tx in displayTxs) {
              final dayKey = DateFormat('yyyy-MM-dd').format(tx.date);
              if (grouped[dayKey] == null) grouped[dayKey] = [];
              grouped[dayKey]!.add(tx);
            }

            final sortedDayKeys = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return Column(
              children: [
                // summary header
                Container(
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Thu nhập', totalIncome, Colors.green),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildStatItem('Chi tiêu', totalExpense, Colors.red),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildStatItem('Tổng', totalIncome - totalExpense, Colors.blue),
                    ],
                  ),
                ),

                Expanded(
                  child: displayTxs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Lottie.asset('assets/empty.json', width: 250),
                              const SizedBox(height: 10),
                              Text(
                                widget.isMonthly
                                    ? 'Tháng này chưa có giao dịch'
                                    : 'Hôm nay chưa có giao dịch',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: sortedDayKeys.length,
                          itemBuilder: (context, dayIdx) {
                            final dKey = sortedDayKeys[dayIdx];
                            final dayTxs = grouped[dKey]!;
                            // sort txs within day newest to oldest
                            dayTxs.sort((a,b) {
                              int c = b.date.compareTo(a.date);
                              if (c == 0) return b.key.toString().compareTo(a.key.toString());
                              return c;
                            });

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.isMonthly) 
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            DateFormat('dd/MM (EEEE)').format(DateTime.parse(dKey)),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                                          ),
                                        ),
                                        const Expanded(child: Divider(indent: 10)),
                                      ],
                                    ),
                                  ),
                                ...dayTxs.map((tx) {
                                  final cat = catBox.values.firstWhere(
                                    (c) => c.id == tx.categoryId,
                                    orElse: () => CategoryModel(id: '', name: '?', iconCode: Icons.help.codePoint, isExpense: true),
                                  );
                                  return Dismissible(
                                    key: ValueKey(tx.key),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: Colors.red[100],
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(Icons.delete, color: Colors.red),
                                    ),
                                    onDismissed: (_) => tx.delete(),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                                      ),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: tx.isExpense ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(IconData(cat.iconCode, fontFamily: 'MaterialIcons'), color: tx.isExpense ? Colors.red : Colors.green, size: 20),
                                              if (tx.imagePath != null) ...[
                                                const SizedBox(width: 8),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.file(File(tx.imagePath!), width: 25, height: 25, fit: BoxFit.cover),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        subtitle: tx.note.isNotEmpty ? Text(tx.note, style: const TextStyle(fontSize: 12)) : null,
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(CurrencyUtil.formatMoney(tx.amount), style: TextStyle(color: tx.isExpense ? Colors.red : Colors.teal, fontWeight: FontWeight.bold, fontSize: 14)),
                                            Text('Số dư: ${CurrencyUtil.formatMoney(runningBalances[tx.key] ?? 0)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                        onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => TransactionForm(transaction: tx)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(CurrencyUtil.formatMoney(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
