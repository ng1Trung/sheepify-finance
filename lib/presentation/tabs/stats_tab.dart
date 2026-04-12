import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';

class StatsTab extends StatelessWidget {
  final DateTime currentMonth;
  const StatsTab({super.key, required this.currentMonth});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Transaction>(kMoneyBox).listenable(),
      builder: (context, box, _) {
        final catBox = Hive.box<CategoryModel>(kCatBox);

        final transactions = box.values.cast<Transaction>().where((tx) {
          return tx.date.month == currentMonth.month &&
              tx.date.year == currentMonth.year;
        }).toList();

        final allParents = catBox.values
            .where((c) => c.parentId == null)
            .toList();
        Map<String, double> parentStats = {for (var p in allParents) p.id: 0.0};
        Map<String, double> childStats = {};
        double totalIncome = 0;
        double totalExpense = 0;

        for (var tx in transactions) {
          final childCat = catBox.values.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => CategoryModel(
              id: '',
              name: '?',
              iconCode: 0,
              isExpense: true,
              parentId: null,
            ),
          );
          if (childCat.id == '') continue;

          if (tx.isExpense)
            totalExpense += tx.amount;
          else
            totalIncome += tx.amount;

          childStats[childCat.name] =
              (childStats[childCat.name] ?? 0) + tx.amount;

          if (childCat.parentId != null &&
              parentStats.containsKey(childCat.parentId)) {
            parentStats[childCat.parentId!] =
                (parentStats[childCat.parentId!] ?? 0) + tx.amount;
          }
        }

        var sortedChildEntries = childStats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        allParents.sort(
          (a, b) => (parentStats[b.id] ?? 0).compareTo(parentStats[a.id] ?? 0),
        );

        bool hasData = totalIncome > 0 || totalExpense > 0;

        // --- EMPTY STATE ---
        if (!hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/empty.json',
                  width: MediaQuery.of(context).size.width * 0.8,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  'Tháng ${DateFormat('MM/yyyy').format(currentMonth)} chưa có dữ liệu!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        double balance = totalIncome - totalExpense;
        Color cardColor = balance > 0
            ? Colors.green
            : (balance < 0 ? Colors.red : Colors.grey);
        const textColor = Colors.white;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 300,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: sortedChildEntries.map((e) {
                    final color = Colors
                        .primaries[e.key.hashCode % Colors.primaries.length];
                    final percent =
                        (e.value / (totalIncome + totalExpense) * 100).toInt();
                    return PieChartSectionData(
                      color: color,
                      value: e.value,
                      title: percent > 5 ? '$percent%' : '',
                      radius: 80,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      badgeWidget: _Badge(e.key),
                      badgePositionPercentageOffset: 1.2,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...allParents.map((parent) {
              final total = parentStats[parent.id] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                      color: parent.isExpense
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      IconData(parent.iconCode, fontFamily: 'MaterialIcons'),
                      color: parent.isExpense ? Colors.red : Colors.green,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    parent.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    CurrencyUtil.formatMoney(total),
                    style: TextStyle(
                      color: total == 0
                          ? Colors.grey
                          : (parent.isExpense ? Colors.red : Colors.green),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SỐ DƯ THỰC TẾ:',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      CurrencyUtil.formatMoney(balance),
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 2),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
