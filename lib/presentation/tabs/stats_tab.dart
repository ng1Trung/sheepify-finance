import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';
import 'package:lottie/lottie.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';

class StatsTab extends StatefulWidget {
  final DateTime currentMonth;
  const StatsTab({super.key, required this.currentMonth});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatEntry {
  final CategoryModel category;
  double amount;
  _StatEntry(this.category, this.amount);
}

class _StatsTabState extends State<StatsTab> {
  bool _isExpenseMode = true;
  int _touchedIndex = -1;

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
            final allTransactions = box.values.cast<Transaction>().toList();

            // 1. Phân loại giao dịch: Tháng này vs Các tháng trước
            final monthStart = DateTime(
              widget.currentMonth.year,
              widget.currentMonth.month,
              1,
            );
            final nextMonthStart = DateTime(
              widget.currentMonth.year,
              widget.currentMonth.month + 1,
              1,
            );

            final monthTransactions = allTransactions
                .where(
                  (tx) =>
                      tx.date.isAfter(
                        monthStart.subtract(const Duration(seconds: 1)),
                      ) &&
                      tx.date.isBefore(nextMonthStart),
                )
                .toList();

            final previousTransactions = allTransactions
                .where((tx) => tx.date.isBefore(monthStart))
                .toList();

            // 2. Tính toán số dư tồn dư từ quá khứ
            double prevIncome = 0;
            double prevExpense = 0;
            for (var tx in previousTransactions) {
              if (tx.isExpense)
                prevExpense += tx.amount;
              else
                prevIncome += tx.amount;
            }
            double carriedOverBalance = prevIncome - prevExpense;

            // 3. Phân tích dữ liệu theo Danh mục trong tháng
            Map<String, _StatEntry> statsMap = {};
            double monthIncome = 0;
            double monthExpense = 0;

            for (var tx in monthTransactions) {
              if (tx.isExpense)
                monthExpense += tx.amount;
              else
                monthIncome += tx.amount;

              if (tx.isExpense == _isExpenseMode) {
                final cat = catBox.values.firstWhere(
                  (c) => c.id == tx.categoryId,
                  orElse: () => CategoryModel(
                    id: 'unknown',
                    name: 'Khác',
                    iconCode: 58263,
                    isExpense: tx.isExpense,
                  ),
                );

                if (statsMap.containsKey(cat.id)) {
                  statsMap[cat.id]!.amount += tx.amount;
                } else {
                  statsMap[cat.id] = _StatEntry(cat, tx.amount);
                }
              }
            }

            // 4. Xử lý "Số dư khả dụng" và "Danh mục ảo Tháng trước"
            double availableBalance;
            if (settings.accumulateBalance) {
              availableBalance =
                  carriedOverBalance + monthIncome - monthExpense;

              // Thêm mục "Tháng trước" vào Tab THU NHẬP nếu có dư
              if (!_isExpenseMode && carriedOverBalance > 0) {
                final prevMonthCat = CategoryModel(
                  id: 'virtual_prev_month',
                  name: 'Tháng trước',
                  iconCode: LineIcons.history.codePoint,
                  isExpense: false,
                );
                statsMap[prevMonthCat.id] = _StatEntry(
                  prevMonthCat,
                  carriedOverBalance,
                );
              }
            } else {
              availableBalance = monthIncome - monthExpense;
            }

            double currentModeDisplayTotal = statsMap.values.fold(
              0,
              (sum, item) => sum + item.amount,
            );

            // Sắp xếp danh mục
            var sortedStats = statsMap.values.toList()
              ..sort((a, b) => b.amount.compareTo(a.amount));

            // --- EMPTY STATE ---
            if (currentModeDisplayTotal == 0) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildBalanceCard(availableBalance),
                    const SizedBox(height: 15),
                    _buildToggleButton(),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/empty.json',
                              width: MediaQuery.of(context).size.width * 0.6,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Tháng ${DateFormat('MM/yyyy').format(widget.currentMonth)} chưa có dữ liệu ${_isExpenseMode ? "chi tiêu" : "thu nhập"}!',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBalanceCard(availableBalance),
                const SizedBox(height: 15),
                _buildToggleButton(),
                const SizedBox(height: 20),

                // --- BIỂU ĐỒ TRÒN ---
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection ==
                                            null) {
                                      _touchedIndex = -1;
                                      return;
                                    }
                                    _touchedIndex = pieTouchResponse
                                        .touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 4,
                          centerSpaceRadius: 65,
                          sections: List.generate(sortedStats.length, (i) {
                            final isTouched = i == _touchedIndex;
                            final radius = isTouched ? 75.0 : 65.0;
                            final stat = sortedStats[i];
                            final color =
                                Colors.primaries[stat.category.id.hashCode %
                                    Colors.primaries.length];
                            final double percentage =
                                (stat.amount / currentModeDisplayTotal) * 100;

                            return PieChartSectionData(
                              color: color,
                              value: stat.amount,
                              title: '${percentage.toStringAsFixed(1)}%',
                              radius: radius,
                              titleStyle: TextStyle(
                                fontSize: isTouched ? 14 : 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
                      ),
                      _buildCenterInfo(sortedStats, currentModeDisplayTotal),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                ...sortedStats.map((stat) {
                  final parent = stat.category.parentId != null
                      ? catBox.values.firstWhere(
                          (c) => c.id == stat.category.parentId,
                          orElse: () => stat.category,
                        )
                      : null;

                  bool isVirtual = stat.category.id == 'virtual_prev_month';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isExpenseMode
                              ? Colors.red.withOpacity(0.08)
                              : Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isVirtual
                              ? LineIcons.history
                              : IconData(
                                  stat.category.iconCode,
                                  fontFamily: 'MaterialIcons',
                                ),
                          color: _isExpenseMode ? Colors.red : Colors.green,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        stat.category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: isVirtual
                          ? const Text(
                              'Số dư cộng dồn từ trước',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                              ),
                            )
                          : (parent != null
                                ? Text(
                                    parent.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  )
                                : null),
                      trailing: Text(
                        CurrencyUtil.formatMoney(stat.amount),
                        style: TextStyle(
                          color: _isExpenseMode ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 50),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildToggleButton() {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleItem("Chi tiêu", _isExpenseMode, Colors.red),
          ),
          Expanded(
            child: _buildToggleItem("Thu nhập", !_isExpenseMode, Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool isActive, Color color) {
    return GestureDetector(
      onTap: () => setState(() {
        _isExpenseMode = (title == "Chi tiêu");
        _touchedIndex = -1;
      }),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? color : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterInfo(List<_StatEntry> sortedStats, double total) {
    String label = "TỔNG";
    String amount = CurrencyUtil.formatMoney(total);
    Color color = _isExpenseMode ? Colors.red : Colors.green;

    if (_touchedIndex != -1 && _touchedIndex < sortedStats.length) {
      label = sortedStats[_touchedIndex].category.name;
      amount = CurrencyUtil.formatMoney(sortedStats[_touchedIndex].amount);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(double balance) {
    Color color = balance >= 0 ? Colors.teal : Colors.red;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SỐ DƯ KHẢ DỤNG:',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              CurrencyUtil.formatMoney(balance),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
