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

        if (_selectedTypeIndex == 1) {
          for (final category in catBox.values.where(
            (cat) => cat.effectiveTypeIndex == 1,
          )) {
            statsMap[category.id] = _StatEntry(category, 0);
          }
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
                child: _selectedTypeIndex == 0 && selectedTotal == 0
                    ? SheepCard(
                        child: Column(
                          children: [
                            _buildTransactionCount(
                              context,
                              selectedTransactionCount,
                            ),
                            Expanded(
                              child: SheepEmptyState(
                                message: _emptyMessage(
                                  context,
                                  _selectedTypeIndex,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _selectedTypeIndex == 0
                    ? _buildExpenseCard(
                        context,
                        stats,
                        selectedTotal,
                        selectedTransactionCount,
                        settings,
                      )
                    : _buildIncomeCard(
                        context,
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
            _buildTransactionCount(context, transactionCount),
            const SizedBox(height: 8),
            _buildPieChart(context, stats, total, settings),
            const SizedBox(height: 18),
            Divider(color: AppColors.getBorder(Theme.of(context).brightness)),
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
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.of(context).get('total_income'),
                  style: SheepTextStyles.itemMeta(context),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyUtil.formatDisplayAmount(
                    total,
                    settings.currencyCode,
                    isHidden: settings.hideAmounts,
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.income,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildTransactionCount(context, transactionCount),
          const SizedBox(height: 8),
          Divider(color: AppColors.getBorder(Theme.of(context).brightness)),
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
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 75,
              sections: List.generate(stats.length, (index) {
                final stat = stats[index];
                return PieChartSectionData(
                  color: _categoryColor(stat.category),
                  value: stat.amount < total * 0.02
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
                    style: SheepTextStyles.itemMeta(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
    final progress = total > 0 ? stat.amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: () => _showTransactionHistory(context, stat.category),
        borderRadius: BorderRadius.circular(SheepRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(stat.category.iconData, color: color, size: 20),
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
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionHistory(BuildContext context, CategoryModel category) {
    final transactions = Hive.box<Transaction>(kMoneyBox).values
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

  String _emptyMessage(BuildContext context, int typeIndex) {
    final l10n = L10n.of(context);
    return typeIndex == 0
        ? l10n.get('no_data_expense')
        : l10n.get('no_data_income');
  }
}
