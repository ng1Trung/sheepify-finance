import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../core/utils/l10n.dart';
import '../widgets/common/sheep_toggles.dart';
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
  int _selectedTypeIndex = 0; // 0: expense, 1: income, 2: savings
  int _touchedIndex = -1;
  late DateTime _selectedMonth;
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(
      widget.currentMonth.year,
      widget.currentMonth.month,
      1,
    );
    _syncSelectedRange();
  }

  @override
  void didUpdateWidget(covariant StatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMonth.year != widget.currentMonth.year ||
        oldWidget.currentMonth.month != widget.currentMonth.month) {
      _selectedMonth = DateTime(
        widget.currentMonth.year,
        widget.currentMonth.month,
        1,
      );
      _syncSelectedRange();
    }
  }

  void _syncSelectedRange() {
    _selectedRange = DateTimeRange(
      start: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
      end: DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
        1,
      );
      _syncSelectedRange();
    });
  }

  Future<void> _pickMonth() async {
    final picked = await SheepDatePicker.show(
      context: context,
      initialDate: _selectedMonth,
      mode: SheepDateMode.month,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _syncSelectedRange();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

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

            final filteredTransactions = allTransactions.where(
              (tx) =>
                  tx.date.isAfter(
                    _selectedRange.start.subtract(const Duration(seconds: 1)),
                  ) &&
                  tx.date.isBefore(
                    _selectedRange.end.add(const Duration(seconds: 1)),
                  ),
            );

            Map<String, _StatEntry> statsMap = {};
            for (var tx in filteredTransactions) {
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

              if (cat.effectiveTypeIndex == _selectedTypeIndex) {
                if (statsMap.containsKey(cat.id)) {
                  statsMap[cat.id]!.amount += tx.amount;
                } else {
                  statsMap[cat.id] = _StatEntry(cat, tx.amount);
                }
              }
            }

            double displayTotal = statsMap.values.fold(
              0,
              (sum, item) => sum + item.amount,
            );
            var sortedStats = statsMap.values.toList()
              ..sort((a, b) => b.amount.compareTo(a.amount));

            Widget buildStatsCard({required Widget child}) {
              return Container(
                margin: SheepSpacing.pageHorizontal,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                child: child,
              );
            }

            if (displayTotal == 0) {
              return Padding(
                padding: EdgeInsets.only(top: topPadding + 20, bottom: 24),
                child: Column(
                  children: [
                    _buildDateRangeBar(),
                    const SizedBox(height: 28),
                    _buildTabSelector(l10n),
                    const SizedBox(height: 28),
                    Expanded(
                      child: buildStatsCard(child: _buildEmptyState(l10n)),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(top: topPadding + 20, bottom: 24),
              child: Column(
                children: [
                  _buildDateRangeBar(),
                  const SizedBox(height: 28),
                  _buildTabSelector(l10n),
                  const SizedBox(height: 28),

                  buildStatsCard(
                    child: Column(
                      children: [
                        _buildPieChart(
                          sortedStats,
                          displayTotal,
                          settings.currencyCode,
                          l10n,
                        ),
                        const SizedBox(height: 32),
                        const Divider(height: 1, color: Color(0xFFF8F8F8)),
                        const SizedBox(height: 16),
                        ...sortedStats.map(
                          (stat) => _buildStatRow(
                            stat,
                            displayTotal,
                            settings.currencyCode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateRangeBar() {
    final locale = Localizations.localeOf(context).toString();
    final monthText = DateFormat('MMMM yyyy', locale).format(_selectedMonth);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => _changeMonth(-1),
        ),
        InkWell(
          onTap: _pickMonth,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, size: 16, color: Colors.black),
                const SizedBox(width: 10),
                Text(
                  monthText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildTabSelector(L10n l10n) {
    return Padding(
      padding: SheepSpacing.pageHorizontal,
      child: SheepTripleToggle(
        selectedIndex: _selectedTypeIndex,
        labels: [l10n.get('expense'), l10n.get('income'), l10n.get('savings')],
        onChanged: (index) => setState(() => _selectedTypeIndex = index),
      ),
    );
  }

  Widget _buildPieChart(
    List<_StatEntry> stats,
    double total,
    String currency,
    L10n l10n,
  ) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 75,
              sections: List.generate(stats.length, (i) {
                final isTouched = i == _touchedIndex;
                final stat = stats[i];
                final catColor = stat.category.colorValue != null
                    ? Color(stat.category.colorValue!)
                    : Colors.black;

                double visualValue = stat.amount;
                double minVisualThreshold = total * 0.02;
                if (visualValue < minVisualThreshold) {
                  visualValue = minVisualThreshold;
                }

                return PieChartSectionData(
                  color: catColor,
                  value: visualValue,
                  title: '',
                  radius: isTouched ? 28 : 22,
                );
              }),
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _touchedIndex != -1
                      ? stats[_touchedIndex].category.name
                      : l10n.get('all_total'),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyUtil.formatByCurrency(
                      _touchedIndex != -1 ? stats[_touchedIndex].amount : total,
                      currency,
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(_StatEntry stat, double total, String currency) {
    final percent = (stat.amount / total * 100).toStringAsFixed(1);
    final catColor = stat.category.colorValue != null
        ? Color(stat.category.colorValue!)
        : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              IconData(stat.category.iconCode, fontFamily: 'MaterialIcons'),
              size: 20,
              color: catColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.category.name,
                  style: SheepTextStyles.itemTitle(context),
                ),
                Text('$percent%', style: SheepTextStyles.itemMeta(context)),
              ],
            ),
          ),
          Text(
            CurrencyUtil.formatByCurrency(stat.amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: catColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(L10n l10n) {
    String message;
    switch (_selectedTypeIndex) {
      case 0:
        message = l10n.get('no_data_expense');
        break;
      case 1:
        message = l10n.get('no_data_income');
        break;
      default:
        message = l10n.get('no_data_savings');
    }

    return SheepEmptyState(message: message);
  }
}
