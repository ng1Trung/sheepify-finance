import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../core/utils/l10n.dart';
import '../widgets/common/sheep_widgets.dart';

class StatsTab extends StatefulWidget {
  final DateTimeRange selectedRange;
  final int selectedTypeIndex;
  final Widget typeFilter;

  const StatsTab({
    super.key,
    required this.selectedRange,
    required this.selectedTypeIndex,
    required this.typeFilter,
  });

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatEntry {
  final CategoryModel category;
  double amount;
  _StatEntry(this.category, this.amount);
}

class _StatsTabState extends State<StatsTab> {
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

            final filteredTransactions = allTransactions.where(
              (tx) =>
                  tx.date.isAfter(
                    widget.selectedRange.start.subtract(
                      const Duration(seconds: 1),
                    ),
                  ) &&
                  tx.date.isBefore(
                    widget.selectedRange.end.add(const Duration(seconds: 1)),
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

              if (cat.effectiveTypeIndex == widget.selectedTypeIndex) {
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
              return Expanded(
                child: buildStatsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      widget.typeFilter,
                      Expanded(child: _buildEmptyState(l10n)),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  buildStatsCard(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: widget.typeFilter,
                        ),
                        const SizedBox(height: 8),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(L10n l10n) {
    String message;
    switch (widget.selectedTypeIndex) {
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
