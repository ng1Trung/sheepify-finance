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
import '../../core/utils/l10n.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_toggles.dart';

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
  int _selectedTypeIndex = 0; // 0: expense, 1: income, 2: savings
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, settingsBox, _) {
        final settings = settingsBox.get('current') ?? AppSettings();
        final l10n = L10n.of(context);

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
              final cat = catBox.values.firstWhere((c) => c.id == tx.categoryId, orElse: () => CategoryModel(id: '?', name: '?', iconCode: 0, isExpense: tx.isExpense));
              if (cat.effectiveTypeIndex == 0) {
                prevExpense += tx.amount;
              } else if (cat.effectiveTypeIndex == 1) {
                prevIncome += tx.amount;
              }
            }
            double carriedOverBalance = prevIncome - prevExpense;

            // 3. Category Analysis
            Map<String, _StatEntry> statsMap = {};
            double monthIncome = 0;
            double monthExpense = 0;

            for (var tx in monthTransactions) {
              final cat = catBox.values.firstWhere(
                (c) => c.id == tx.categoryId,
                orElse: () => CategoryModel(
                  id: 'unknown',
                  name: l10n.get('other'),
                  iconCode: 58263,
                  isExpense: tx.isExpense,
                  typeIndex: tx.isExpense ? 0 : 1,
                ),
              );

              if (cat.effectiveTypeIndex == 0) {
                monthExpense += tx.amount;
              } else if (cat.effectiveTypeIndex == 1) {
                monthIncome += tx.amount;
              }

              if (cat.effectiveTypeIndex == _selectedTypeIndex) {
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
 
              if (_selectedTypeIndex == 1 && carriedOverBalance > 0) {
                final prevMonthCat = CategoryModel(
                  id: 'virtual_prev_month',
                  name: l10n.get('prev_balance'),
                  iconCode: LineIcons.history.codePoint,
                  isExpense: false,
                  typeIndex: 1,
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
                    _buildBalanceCard(availableBalance, settings.currencyCode),
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
                              _selectedTypeIndex == 0 
                                  ? l10n.get('no_data_expense')
                                  : (_selectedTypeIndex == 1 ? l10n.get('no_data_income') : l10n.get('no_data_savings')),
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
                _buildBalanceCard(availableBalance, settings.currencyCode),
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
                                  final color = stat.category.colorValue != null
                                      ? Color(stat.category.colorValue!)
                                      : _getPastelColor(i);

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
                              settings.currencyCode,
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
                  Color color;
                  if (_selectedTypeIndex == 0) color = AppColors.expense;
                  else if (_selectedTypeIndex == 1) color = AppColors.income;
                  else color = AppColors.savings;
                  
                  if (stat.category.colorValue != null) color = Color(stat.category.colorValue!);

                  return SheepListTile(
                    onTap: () {},
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isVirtual
                            ? LineIcons.history
                            : IconData(
                                stat.category.iconCode,
                                fontFamily: 'MaterialIcons',
                              ),
                        color: color,
                        size: 22,
                      ),
                    ),
                    title: stat.category.name,
                    subtitle: isVirtual
                        ? Text(
                            l10n.get('accumulated_from_prev'),
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          )
                        : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyUtil.formatByCurrency(stat.amount, settings.currencyCode),
                          style: TextStyle(
                            color: color,
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
    return SheepTripleToggle(
      selectedIndex: _selectedTypeIndex,
      onChanged: (val) => setState(() {
        _selectedTypeIndex = val;
        _touchedIndex = -1;
      }),
    );
  }

  Widget _buildCenterInfo(List<_StatEntry> sortedStats, double total, String currencyCode) {
    final l10n = L10n.of(context);
    String label;
    Color color;
    switch (_selectedTypeIndex) {
      case 0: label = l10n.get('total_expense'); color = AppColors.expense; break;
      case 1: label = l10n.get('total_income'); color = AppColors.income; break;
      default: label = l10n.get('total_savings'); color = AppColors.savings; break;
    }
    
    String amount = CurrencyUtil.formatByCurrency(total, currencyCode);
 
    if (_touchedIndex != -1 && _touchedIndex < sortedStats.length) {
      label = sortedStats[_touchedIndex].category.name;
      amount = CurrencyUtil.formatByCurrency(sortedStats[_touchedIndex].amount, currencyCode);
      if (sortedStats[_touchedIndex].category.colorValue != null) {
        color = Color(sortedStats[_touchedIndex].category.colorValue!);
      }
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

  Widget _buildBalanceCard(double balance, String currencyCode) {
    final l10n = L10n.of(context);
    return SheepCard(
      padding: const EdgeInsets.all(18),
      color: Theme.of(context).primaryColor.withOpacity(0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.get('wallet_balance'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            CurrencyUtil.formatByCurrency(balance, currencyCode),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).primaryColor,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
