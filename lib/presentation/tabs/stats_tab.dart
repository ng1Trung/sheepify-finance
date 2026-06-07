import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../core/utils/l10n.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction.dart';
import '../widgets/category/transaction_history_sheet.dart';
import '../widgets/common/sheep_toggles.dart';
import '../widgets/common/sheep_widgets.dart';

class StatsTab extends StatefulWidget {
  final DateTimeRange selectedRange;

  const StatsTab({super.key, required this.selectedRange});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatEntry {
  final CategoryModel category;
  double amount;

  _StatEntry(this.category, this.amount);
}

class _StatsTabState extends State<StatsTab> {
  int _selectedTypeIndex = 0;
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        Hive.box<AppSettings>(kSettingsBox).listenable(),
        Hive.box<Transaction>(kMoneyBox).listenable(),
        Hive.box<CategoryModel>(kCatBox).listenable(),
      ]),
      builder: (context, _) {
        final settings =
            Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
        final catBox = Hive.box<CategoryModel>(kCatBox);
        final rangeTransactions = Hive.box<Transaction>(kMoneyBox).values.where(
          (tx) =>
              !tx.date.isBefore(widget.selectedRange.start) &&
              !tx.date.isAfter(widget.selectedRange.end),
        );

        final totals = [0.0, 0.0];
        final transactionCounts = [0, 0];
        final statsMap = <String, _StatEntry>{};

        for (final category in catBox.values.where(
          (cat) => cat.effectiveTypeIndex == _selectedTypeIndex,
        )) {
          statsMap[category.id] = _StatEntry(category, 0);
        }

        for (final tx in rangeTransactions) {
          final category = catBox.values.firstWhere(
            (cat) => cat.id == tx.categoryId,
            orElse: () => CategoryModel(
              id: 'unknown-${tx.isExpense}',
              name: L10n.of(context).get('other'),
              iconCode: Icons.help_outline.codePoint,
              isExpense: tx.isExpense,
              typeIndex: tx.isExpense ? 0 : 1,
            ),
          );
          final typeIndex = category.effectiveTypeIndex;
          if (typeIndex > 1) continue;
          totals[typeIndex] += tx.amount;
          transactionCounts[typeIndex]++;
          if (typeIndex != _selectedTypeIndex) continue;

          statsMap.update(
            category.id,
            (entry) => entry..amount += tx.amount,
            ifAbsent: () => _StatEntry(category, tx.amount),
          );
        }

        final stats = statsMap.values.toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
        final chartStats = stats.where((stat) => stat.amount > 0).toList();
        final selectedTotal = totals[_selectedTypeIndex];
        final selectedTransactionCount = transactionCounts[_selectedTypeIndex];

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            SheepSpacing.page,
            8,
            SheepSpacing.page,
            24,
          ),
          child: Column(
            children: [
              SheepTypeToggle(
                isExpense: _selectedTypeIndex == 0,
                onChanged: (isExpense) => setState(() {
                  _selectedTypeIndex = isExpense ? 0 : 1;
                  _touchedIndex = -1;
                }),
              ),
              const SizedBox(height: SheepSpacing.lg),
              Expanded(
                child: _selectedTypeIndex == 0
                    ? _buildExpenseCard(
                        context,
                        chartStats,
                        stats,
                        selectedTotal,
                        selectedTransactionCount,
                        settings,
                      )
                    : _buildIncomeCard(
                        context,
                        chartStats,
                        stats,
                        selectedTotal,
                        selectedTransactionCount,
                        settings,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    List<_StatEntry> chartStats,
    List<_StatEntry> stats,
    double total,
    int transactionCount,
    AppSettings settings,
  ) {
    return SheepCard(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildPieChart(context, chartStats, total, settings),
            const SizedBox(height: 12),
            Divider(color: AppColors.getBorder(Theme.of(context).brightness)),
            const SizedBox(height: 8),
            _buildTransactionCount(context, transactionCount),
            const SizedBox(height: 8),
            ...stats.map(
              (stat) => _buildProgressRow(context, stat, total, settings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeCard(
    BuildContext context,
    List<_StatEntry> chartStats,
    List<_StatEntry> stats,
    double total,
    int transactionCount,
    AppSettings settings,
  ) {
    return SheepCard(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildPieChart(context, chartStats, total, settings),
            const SizedBox(height: 12),
            Divider(color: AppColors.getBorder(Theme.of(context).brightness)),
            const SizedBox(height: 8),
            _buildTransactionCount(context, transactionCount),
            const SizedBox(height: 8),
            ...stats.map(
              (stat) => _buildProgressRow(context, stat, total, settings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCount(BuildContext context, int count) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        L10n.of(
          context,
        ).get('num_transactions', params: {'count': count.toString()}),
        style: SheepTextStyles.itemMeta(context),
      ),
    );
  }

  Widget _buildPieChart(
    BuildContext context,
    List<_StatEntry> stats,
    double total,
    AppSettings settings,
  ) {
    final touchedIndex = _touchedIndex >= 0 && _touchedIndex < stats.length
        ? _touchedIndex
        : -1;
    final hasTotal = total > 0;
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 75,
              sections: List.generate(stats.isEmpty ? 1 : stats.length, (
                index,
              ) {
                if (stats.isEmpty) {
                  return PieChartSectionData(
                    color: AppColors.getBorder(Theme.of(context).brightness),
                    value: 1,
                    title: '',
                    radius: 22,
                  );
                }
                final stat = stats[index];
                return PieChartSectionData(
                  color: _categoryColor(stat.category),
                  value: !hasTotal
                      ? 1
                      : stat.amount < total * 0.02
                      ? total * 0.02
                      : stat.amount,
                  title: '',
                  radius: index == touchedIndex ? 28 : 22,
                );
              }),
              pieTouchData: PieTouchData(
                touchCallback: (event, response) => setState(() {
                  if (!event.isInterestedForInteractions ||
                      response?.touchedSection == null) {
                    _touchedIndex = -1;
                    return;
                  }
                  _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (touchedIndex != -1) ...[
                  Text(
                    stats[touchedIndex].category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: SheepTextStyles.itemMeta(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                ],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyUtil.formatDisplayAmount(
                      touchedIndex == -1 ? total : stats[touchedIndex].amount,
                      settings.currencyCode,
                      isHidden: settings.hideAmounts,
                    ),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(
                        Theme.of(context).brightness,
                      ),
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

  Widget _buildProgressRow(
    BuildContext context,
    _StatEntry stat,
    double total,
    AppSettings settings,
  ) {
    final color = _categoryColor(stat.category);
    final budget = stat.category.budget;
    final progressBase = _selectedTypeIndex == 0 && budget != null && budget > 0
        ? budget
        : total;
    final progress = progressBase > 0 ? stat.amount / progressBase : 0.0;
    final barColor =
        _selectedTypeIndex == 0 &&
            budget != null &&
            budget > 0 &&
            stat.amount > budget
        ? AppColors.expense
        : color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: () => _showTransactionHistory(context, stat.category, total),
        borderRadius: BorderRadius.circular(SheepRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Row(
                children: [
                  SheepCategoryIcon(icon: stat.category.iconData, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stat.category.name,
                      style: SheepTextStyles.itemTitle(context),
                    ),
                  ),
                  Text(
                    CurrencyUtil.formatDisplayAmount(
                      stat.amount,
                      settings.currencyCode,
                      isHidden: settings.hideAmounts,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: barColor.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionHistory(
    BuildContext context,
    CategoryModel category,
    double typeTotal,
  ) {
    final transactions =
        Hive.box<Transaction>(kMoneyBox).values
            .where(
              (tx) =>
                  tx.categoryId == category.id &&
                  !tx.date.isBefore(widget.selectedRange.start) &&
                  !tx.date.isAfter(widget.selectedRange.end),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionHistorySheet(
        category: category,
        transactions: transactions,
        typeTotal: typeTotal,
      ),
    );
  }

  Color _categoryColor(CategoryModel category) {
    return category.colorValue != null
        ? Color(category.colorValue!)
        : _selectedTypeIndex == 0
        ? AppColors.expense
        : AppColors.income;
  }
}
