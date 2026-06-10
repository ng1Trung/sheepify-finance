import 'dart:math' as math;
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
  int count;

  _StatEntry(this.category, this.amount, {this.count = 0});
}

class _StatsTabState extends State<StatsTab> {
  int _selectedTypeIndex = 0;
  int _touchedIndex = -1;
  final Set<int> _expandedStatTypes = {};

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
            (entry) => entry
              ..amount += tx.amount
              ..count += 1,
            ifAbsent: () => _StatEntry(category, tx.amount, count: 1),
          );
        }

        final stats = statsMap.values.toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
        final chartStats = stats.where((stat) => stat.amount > 0).toList();
        final selectedTotal = totals[_selectedTypeIndex];
        final selectedTransactionCount = transactionCounts[_selectedTypeIndex];
        final percentLabels = _buildPercentLabels(stats, selectedTotal);

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
                        percentLabels,
                        settings,
                      )
                    : _buildIncomeCard(
                        context,
                        chartStats,
                        stats,
                        selectedTotal,
                        selectedTransactionCount,
                        percentLabels,
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
    Map<String, String> percentLabels,
    AppSettings settings,
  ) {
    return SheepCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildPieChart(
              context,
              chartStats,
              total,
              transactionCount,
              settings,
            ),
            ..._buildStatRows(context, stats, total, percentLabels, settings),
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
    Map<String, String> percentLabels,
    AppSettings settings,
  ) {
    return SheepCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildPieChart(
              context,
              chartStats,
              total,
              transactionCount,
              settings,
            ),
            ..._buildStatRows(context, stats, total, percentLabels, settings),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatRows(
    BuildContext context,
    List<_StatEntry> stats,
    double total,
    Map<String, String> percentLabels,
    AppSettings settings,
  ) {
    const defaultVisibleCount = 5;
    final isExpanded = _expandedStatTypes.contains(_selectedTypeIndex);
    final visibleStats = isExpanded
        ? stats
        : stats.take(defaultVisibleCount).toList();
    final remainingCount = stats.length - visibleStats.length;

    return [
      const SizedBox(height: 12),
      ...visibleStats.map(
        (stat) => _buildProgressRow(
          context,
          stat,
          total,
          settings,
          percentLabels[stat.category.id] ?? '0',
        ),
      ),
      if (remainingCount > 0)
        _buildMoreCategoriesButton(context, remainingCount),
    ];
  }

  Widget _buildMoreCategoriesButton(BuildContext context, int remainingCount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(SheepRadius.pill),
          onTap: () {
            setState(() {
              _expandedStatTypes.add(_selectedTypeIndex);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getSubtleSurface(theme.brightness),
              borderRadius: BorderRadius.circular(SheepRadius.pill),
              border: Border.all(
                color: AppColors.getBorder(
                  theme.brightness,
                ).withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+$remainingCount danh mục khác',
                  style: SheepTextStyles.itemMeta(context).copyWith(
                    color: AppColors.getInteractiveAccent(
                      theme.brightness,
                      theme.colorScheme.primary,
                    ),
                    fontSize: SheepTypeScale.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.getInteractiveAccent(
                    theme.brightness,
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(
    BuildContext context,
    List<_StatEntry> stats,
    double total,
    int transactionCount,
    AppSettings settings,
  ) {
    final touchedIndex = _touchedIndex >= 0 && _touchedIndex < stats.length
        ? _touchedIndex
        : -1;
    final hasTotal = total > 0;
    final displayCount = touchedIndex == -1
        ? transactionCount
        : stats[touchedIndex].count;

    // Calculate angles of sections to place labels outside
    final List<double> sectionValues = [];
    for (final stat in stats) {
      final val = stat.amount < total * 0.02 ? total * 0.02 : stat.amount;
      sectionValues.add(val);
    }
    final double sectionValuesSum = sectionValues.fold(
      0.0,
      (sum, val) => sum + val,
    );

    final List<double> midAngles = [];
    if (hasTotal && sectionValuesSum > 0) {
      double currentSum = 0.0;
      for (final val in sectionValues) {
        final double startAngle =
            270.0 + (currentSum / sectionValuesSum) * 360.0;
        final double sweepAngle = (val / sectionValuesSum) * 360.0;
        final double midAngle = startAngle + sweepAngle / 2.0;
        midAngles.add(midAngle);
        currentSum += val;
      }
    }

    const double centerSpaceRadius = 65.0;
    const double normalRadius = 32.0;
    const double touchedRadius = 40.0;
    const double badgeDistance =
        107.0; // Optimized spacing to prevent clipping on the sides and make leader lines shorter

    return SizedBox(
      height:
          230, // Optimized height to balance top and bottom spacing inside parent card
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2, // Smaller gap between segments
              centerSpaceRadius: centerSpaceRadius,
              startDegreeOffset: 270,
              sections: List.generate(stats.isEmpty ? 1 : stats.length, (
                index,
              ) {
                if (stats.isEmpty) {
                  return PieChartSectionData(
                    color: AppColors.getBorder(Theme.of(context).brightness),
                    value: 1,
                    title: '',
                    radius: normalRadius,
                  );
                }

                final stat = stats[index];
                final isTouched = index == touchedIndex;
                final radius = isTouched ? touchedRadius : normalRadius;

                Widget? badgeWidget;
                double badgeOffset = 1.0;
                double deltaD = 0.0;

                if (hasTotal && index < 4) {
                  final exactPercent = (stat.amount / total) * 100;
                  if (exactPercent >= 5.0) {
                    final percentLabels = _buildPercentLabels(stats, total);
                    final percentText =
                        percentLabels[stat.category.id] ??
                        exactPercent.toStringAsFixed(0);
                    final midAngleDeg = midAngles[index];
                    final midAngleRad = midAngleDeg * math.pi / 180.0;
                    final isLeft = math.cos(midAngleRad) < 0;

                    badgeOffset = (badgeDistance - centerSpaceRadius) / radius;
                    deltaD = badgeDistance - (centerSpaceRadius + radius);

                    badgeWidget = PieChartLabelWidget(
                      categoryName: stat.category.name,
                      percentText: percentText,
                      color: _categoryColor(stat.category),
                      angle: midAngleRad,
                      isLeft: isLeft,
                      deltaD: deltaD,
                    );
                  }
                }

                return PieChartSectionData(
                  color: _categoryColor(stat.category),
                  value: !hasTotal
                      ? 1
                      : stat.amount < total * 0.02
                      ? total * 0.02
                      : stat.amount,
                  title: '',
                  radius: radius,
                  cornerRadius:
                      8, // Smoother rounded corner (prevents distortion on small segments)
                  borderSide: BorderSide(
                    color: Theme.of(context).cardColor,
                    width: 2.0,
                  ),
                  badgeWidget: badgeWidget,
                  badgePositionPercentageOffset: badgeOffset,
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
                Text(
                  touchedIndex == -1
                      ? L10n.of(
                          context,
                        ).get(_selectedTypeIndex == 0 ? 'expense' : 'income')
                      : stats[touchedIndex].category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SheepTextStyles.itemMeta(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
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
                      color: _selectedTypeIndex == 0
                          ? AppColors.expense
                          : AppColors.income,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  L10n.of(context).get(
                    'num_transactions',
                    params: {'count': displayCount.toString()},
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SheepTextStyles.itemMeta(context),
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
    String percentText,
  ) {
    final color = _categoryColor(stat.category);
    final hasAmount = stat.amount > 0;
    final showProgress = _selectedTypeIndex == 0;
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () =>
            _showTransactionHistory(context, stat.category, total, percentText),
        borderRadius: BorderRadius.circular(SheepRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SheepCategoryIcon(icon: stat.category.iconData, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            stat.category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SheepTextStyles.itemTitle(
                              context,
                            ).copyWith(fontSize: SheepTypeScale.bodyLarge),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: hasAmount
                                ? Text(
                                    CurrencyUtil.formatDisplayAmount(
                                      stat.amount,
                                      settings.currencyCode,
                                      isHidden: settings.hideAmounts,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: SheepTextStyles.itemTitle(context)
                                        .copyWith(
                                          fontSize: SheepTypeScale.bodyLarge,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: barColor.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 58,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: hasAmount
                          ? Text(
                              '$percentText%',
                              maxLines: 1,
                              textAlign: TextAlign.right,
                              style: SheepTextStyles.itemTitle(context)
                                  .copyWith(
                                    color: barColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.getTextSecondary(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.45),
                    ),
                  ],
                ),
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
    String sharePercentText,
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
        sharePercentText: sharePercentText,
      ),
    );
  }

  Map<String, String> _buildPercentLabels(
    List<_StatEntry> stats,
    double total,
  ) {
    final activeStats = stats.where((stat) => stat.amount > 0).toList();
    if (total <= 0 || activeStats.isEmpty) return const {};

    final floors = <String, int>{};
    final remainders = <({String id, double remainder})>[];
    var floorSum = 0;

    for (final stat in activeStats) {
      final exact = stat.amount / total * 100;
      final floorValue = exact.floor();
      floors[stat.category.id] = floorValue;
      floorSum += floorValue;
      remainders.add((id: stat.category.id, remainder: exact - floorValue));
    }

    var remaining = 100 - floorSum;
    remainders.sort((a, b) => b.remainder.compareTo(a.remainder));
    for (var i = 0; i < remainders.length && remaining > 0; i++, remaining--) {
      final id = remainders[i].id;
      floors[id] = (floors[id] ?? 0) + 1;
    }

    return {
      for (final entry in floors.entries) entry.key: entry.value.toString(),
    };
  }

  Color _categoryColor(CategoryModel category) {
    return category.colorValue != null
        ? Color(category.colorValue!)
        : _selectedTypeIndex == 0
        ? AppColors.expense
        : AppColors.income;
  }
}

class LeaderLinePainter extends CustomPainter {
  final double angle;
  final Color color;
  final bool isLeft;
  final double deltaD;

  LeaderLinePainter({
    required this.angle,
    required this.color,
    required this.isLeft,
    required this.deltaD,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final dx = cx - deltaD * math.cos(angle);
    final dy = cy - deltaD * math.sin(angle);

    // Draw dot on the slice edge
    canvas.drawCircle(Offset(dx, dy), 2.5, dotPaint);

    // Draw line from dot to elbow, then horizontal bend
    final path = Path();
    path.moveTo(dx, dy);
    path.lineTo(cx, cy);

    final horizontalEnd = isLeft ? cx - 5.0 : cx + 5.0;
    path.lineTo(horizontalEnd, cy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LeaderLinePainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.color != color ||
        oldDelegate.isLeft != isLeft ||
        oldDelegate.deltaD != deltaD;
  }
}

class PieChartLabelWidget extends StatelessWidget {
  final String categoryName;
  final String percentText;
  final Color color;
  final double angle;
  final bool isLeft;
  final double deltaD;

  const PieChartLabelWidget({
    super.key,
    required this.categoryName,
    required this.percentText,
    required this.color,
    required this.angle,
    required this.isLeft,
    required this.deltaD,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double width = 80.0;
    const double height = 50.0;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: LeaderLinePainter(
                angle: angle,
                color: color,
                isLeft: isLeft,
                deltaD: deltaD,
              ),
            ),
          ),
          Positioned(
            left: isLeft ? null : (width / 2) + 8,
            right: isLeft ? (width / 2) + 8 : null,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isLeft
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isLeft ? TextAlign.end : TextAlign.start,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$percentText%',
                    textAlign: isLeft ? TextAlign.end : TextAlign.start,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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
}
