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
import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';

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

            // 1. Transaction Filtering
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

            // 2. Balance Calculation
            double prevIncome = 0;
            double prevExpense = 0;
            for (var tx in previousTransactions) {
              if (tx.isExpense) {
                prevExpense += tx.amount;
              } else {
                prevIncome += tx.amount;
              }
            }
            double carriedOverBalance = prevIncome - prevExpense;

            // 3. Category Analysis
            Map<String, _StatEntry> statsMap = {};
            double monthIncome = 0;
            double monthExpense = 0;

            for (var tx in monthTransactions) {
              if (tx.isExpense) {
                monthExpense += tx.amount;
              } else {
                monthIncome += tx.amount;
              }

              if (tx.isExpense == _isExpenseMode) {
                final cat = catBox.values.firstWhere(
                  (c) => c.id == tx.categoryId,
                  orElse: () => CategoryModel(
                    id: 'unknown',
                    name: 'Others',
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

            // 4. Handle "Available Balance"
            double availableBalance;
            if (settings.accumulateBalance) {
              availableBalance =
                  carriedOverBalance + monthIncome - monthExpense;

              if (!_isExpenseMode && carriedOverBalance > 0) {
                final prevMonthCat = CategoryModel(
                  id: 'virtual_prev_month',
                  name: 'Previous Balance',
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
                            Lottie.asset('assets/empty.json', width: 200),
                            const SizedBox(height: 20),
                            Text(
                              'No ${_isExpenseMode ? "expense" : "income"} data for ${DateFormat('MMMM yyyy').format(widget.currentMonth)}!',
                              style: Theme.of(context).textTheme.labelSmall,
                              textAlign: TextAlign.center,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildBalanceCard(availableBalance),
                const SizedBox(height: 15),
                _buildToggleButton(),
                const SizedBox(height: 20),

                // --- PIE CHART CARD ---
                SheepCard(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event
                                                  .isInterestedForInteractions ||
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
                                sectionsSpace: 4,
                                centerSpaceRadius: 70,
                                sections: List.generate(sortedStats.length, (
                                  i,
                                ) {
                                  final isTouched = i == _touchedIndex;
                                  final radius = isTouched ? 25.0 : 18.0;
                                  final stat = sortedStats[i];
                                  final color = _getPastelColor(i);

                                  return PieChartSectionData(
                                    color: color,
                                    value: stat.amount,
                                    title: '',
                                    radius: radius,
                                  );
                                }),
                              ),
                            ),
                            _buildCenterInfo(
                              sortedStats,
                              currentModeDisplayTotal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                ...sortedStats.map((stat) {
                  bool isVirtual = stat.category.id == 'virtual_prev_month';
                  return SheepListTile(
                    onTap: () {},
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isExpenseMode
                            ? AppColors.expense.withOpacity(0.08)
                            : AppColors.income.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isVirtual
                            ? LineIcons.history
                            : IconData(
                                stat.category.iconCode,
                                fontFamily: 'MaterialIcons',
                              ),
                        color: _isExpenseMode
                            ? AppColors.expense
                            : AppColors.income,
                        size: 22,
                      ),
                    ),
                    title: stat.category.name,
                    subtitle: isVirtual
                        ? 'Accumulated balance from previous months'
                        : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyUtil.formatMoney(stat.amount),
                          style: TextStyle(
                            color: _isExpenseMode
                                ? AppColors.expense
                                : AppColors.income,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${(stat.amount / currentModeDisplayTotal * 100).toStringAsFixed(1)}%',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 100),
              ],
            );
          },
        );
      },
    );
  }

  Color _getPastelColor(int index) {
    final List<Color> pastelPalette = [
      const Color(0xFF83EAF1),
      const Color(0xFF63A4FF),
      const Color(0xFFB983FF),
      const Color(0xFFFF83C1),
      const Color(0xFFFF9B83),
      const Color(0xFFFFD383),
      const Color(0xFFD3FF83),
      const Color(0xFF83FFB9),
    ];
    return pastelPalette[index % pastelPalette.length];
  }

  Widget _buildToggleButton() {
    return Container(
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
              "Expense",
              _isExpenseMode,
              AppColors.expense,
            ),
          ),
          Expanded(
            child: _buildToggleItem(
              "Income",
              !_isExpenseMode,
              AppColors.income,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool isActive, Color color) {
    return GestureDetector(
      onTap: () => setState(() {
        _isExpenseMode = (title.startsWith("Exp"));
        _touchedIndex = -1;
      }),
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

  Widget _buildCenterInfo(List<_StatEntry> sortedStats, double total) {
    String label = _isExpenseMode ? "TOTAL EXPENSE" : "TOTAL INCOME";
    String amount = CurrencyUtil.formatMoney(total);
    Color color = _isExpenseMode ? AppColors.expense : AppColors.income;

    if (_touchedIndex != -1 && _touchedIndex < sortedStats.length) {
      label = sortedStats[_touchedIndex].category.name;
      amount = CurrencyUtil.formatMoney(sortedStats[_touchedIndex].amount);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontSize: 10, letterSpacing: 1),
        ),
        const SizedBox(height: 5),
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 22,
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
    return SheepCard(
      padding: const EdgeInsets.all(18),
      color: AppColors.primaryLight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'WALLET BALANCE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            CurrencyUtil.formatMoney(balance),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
