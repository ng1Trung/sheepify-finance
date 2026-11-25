import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../core/utils/l10n.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction.dart';
import '../widgets/category/transaction_history_sheet.dart';
import '../widgets/common/sheep_kit.dart';
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

class _StatsPercentGroup {
  final double amount;
  final List<String> categoryIds;
  final double exact;
  _StatsPercentGroup(this.amount, this.categoryIds, this.exact);
}

class _TrendBucket {
  final String label;
  final String tooltip;
  final double value;
  final bool isCurrent;
  final bool isFuture;

  const _TrendBucket(
    this.label,
    this.tooltip,
    this.value,
    this.isCurrent, {
    this.isFuture = false,
  });
}

class _StatsTabState extends State<StatsTab> {
  int _selectedTypeIndex = 0;
  int _touchedIndex = -1;
  final Set<int> _expandedStatTypes = {};

  /// Colours handed to categories that have no colour of their own, by
  /// rank, so the donut never turns into one solid ring.
  Map<String, Color> _fallbackColors = const {};
  static const _chartPalette = [
    Color(0xFFEE6055),
    Color(0xFFF59F00),
    Color(0xFF7950F2),
    Color(0xFF1C7ED6),
    Color(0xFF12B886),
    Color(0xFFE64980),
    Color(0xFF0CA678),
    Color(0xFF845EF7),
    Color(0xFFFD7E14),
    Color(0xFF868E96),
  ];

  static const _typeKeys = ['expense', 'income', 'savings'];

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static Color _typeColor(int typeIndex) => switch (typeIndex) {
    0 => AppColors.expense,
    1 => AppColors.income,
    _ => AppColors.savings,
  };

  String _money(AppSettings settings, double value) =>
      CurrencyUtil.formatDisplayAmount(
        value,
        settings.currencyCode,
        isHidden: settings.hideAmounts,
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        Hive.box<AppSettings>(kSettingsBox).listenable(),
        Hive.box<Transaction>(kMoneyBox).listenable(),
        Hive.box<CategoryModel>(kCatBox).listenable(),
      ]),
      builder: (context, _) {
        final l10n = L10n.of(context);
        final settings =
            Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
        final catBox = Hive.box<CategoryModel>(kCatBox);
        final categoriesById = {for (final c in catBox.values) c.id: c};
        final locale = settings.languageCode == 'vi' ? 'vi_VN' : 'en_US';

        final start = _day(widget.selectedRange.start);
        final end = _day(widget.selectedRange.end);
        final dayCount = end.difference(start).inDays + 1;
        final today = _day(DateTime.now());
        // Days of the range that have actually happened. A running cycle is
        // compared with the same number of days of the previous one, so
        // "day 10 of this month" is never measured against a full month.
        final elapsedDays = (today.isBefore(start) || today.isAfter(end))
            ? dayCount
            : today.difference(start).inDays + 1;
        final prevStart = DateTime(start.year, start.month, start.day - dayCount);

        final totals = [0.0, 0.0, 0.0];
        final prevTotals = [0.0, 0.0, 0.0];
        final counts = [0, 0, 0];
        final daily = <DateTime, double>{};
        final statsMap = <String, _StatEntry>{};
        Transaction? biggestTx;

        for (final category in catBox.values.where(
          (cat) => cat.effectiveTypeIndex == _selectedTypeIndex,
        )) {
          statsMap[category.id] = _StatEntry(category, 0);
        }

        for (final tx in Hive.box<Transaction>(kMoneyBox).values) {
          // Pending / cancelled transfers are not real money movement yet.
          if (!tx.isCompleted) continue;
          final day = _day(tx.date);
          final inRange = !day.isBefore(start) && !day.isAfter(end);
          final inPrev =
              !inRange &&
              !day.isBefore(prevStart) &&
              day.isBefore(start) &&
              day.difference(prevStart).inDays < elapsedDays;
          if (!inRange && !inPrev) continue;

          final category =
              categoriesById[tx.categoryId] ??
              CategoryModel(
                id: 'unknown-${tx.isExpense}',
                name: l10n.get('other'),
                iconCode: Icons.help_outline.codePoint,
                isExpense: tx.isExpense,
                typeIndex: tx.isExpense ? 0 : 1,
              );
          final type = category.effectiveTypeIndex.clamp(0, 2);
          if (inPrev) {
            prevTotals[type] += tx.amount;
            continue;
          }
          totals[type] += tx.amount;
          counts[type]++;
          if (type != _selectedTypeIndex) continue;

          daily.update(day, (v) => v + tx.amount, ifAbsent: () => tx.amount);
          if (biggestTx == null || tx.amount > biggestTx.amount) {
            biggestTx = tx;
          }
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
        // Default categories all share their type's colour, which turns the
        // donut into one solid ring. Walk the ranking: a category keeps its
        // own colour only if nobody above it already uses that colour;
        // otherwise it gets the next unused palette colour.
        final taken = <int>{};
        final overrides = <String, Color>{};
        var paletteIndex = 0;
        for (final s in stats) {
          final own = s.category.colorValue;
          if (own != null && taken.add(own)) continue;
          Color next;
          var guard = 0;
          do {
            next = _chartPalette[paletteIndex++ % _chartPalette.length];
          } while (taken.contains(next.toARGB32()) &&
              ++guard < _chartPalette.length);
          taken.add(next.toARGB32());
          overrides[s.category.id] = next;
        }
        _fallbackColors = overrides;
        final selectedTotal = totals[_selectedTypeIndex];
        final percentLabels = _buildPercentLabels(stats, selectedTotal);

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            SheepSpacing.page,
            8,
            SheepSpacing.page,
            96, // keep the last card clear of the FAB
          ),
          children: [
            SheepTripleToggle(
              selectedIndex: _selectedTypeIndex,
              onChanged: (index) => setState(() {
                _selectedTypeIndex = index;
                _touchedIndex = -1;
              }),
            ),
            const SizedBox(height: SheepSpacing.lg),
            _buildOverviewCard(
              context,
              settings,
              totals,
              prevTotals,
              counts,
              elapsedDays,
              dayCount,
            ),
            if (selectedTotal <= 0) ...[
              const SizedBox(height: SheepSpacing.lg),
              SheepCard(
                padding: const EdgeInsets.symmetric(vertical: SheepSpacing.xl),
                child: SheepEmptyState(
                  message: l10n.get('no_tx_range'),
                  assetWidth: 140,
                ),
              ),
            ] else ...[
              _sectionHeader(context, l10n.get('stats_trend')),
              _buildTrendCard(context, settings, daily, start, end, locale),
              _sectionHeader(context, l10n.get('stats_breakdown')),
              _buildBreakdownCard(
                context,
                chartStats,
                stats,
                selectedTotal,
                counts[_selectedTypeIndex],
                percentLabels,
                settings,
              ),
              _sectionHeader(context, l10n.get('stats_highlights')),
              _buildHighlightsCard(
                context,
                settings,
                stats,
                percentLabels,
                biggestTx,
                categoriesById,
                daily,
                dayCount,
                locale,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, SheepSpacing.xl, 4, SheepSpacing.sm),
      child: Text(title, style: SheepTextStyles.sectionTitle(context)),
    );
  }

  // ---------------------------------------------------------------- overview

  Widget _buildOverviewCard(
    BuildContext context,
    AppSettings settings,
    List<double> totals,
    List<double> prevTotals,
    List<int> counts,
    int elapsedDays,
    int dayCount,
  ) {
    final l10n = L10n.of(context);
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.getTextSecondary(brightness);
    final metaStyle = SheepTextStyles.itemMeta(context);
    final type = _selectedTypeIndex;
    final total = totals[type];
    final prev = prevTotals[type];
    final average = elapsedDays > 0 ? total / elapsedDays : 0.0;

    Widget? delta;
    if (prev > 0) {
      final pct = (total - prev) / prev * 100;
      final isUp = pct >= 0;
      // More spending is bad; more income / savings is good.
      final isGood = type == 0 ? !isUp : isUp;
      final color = pct.abs() < 0.5
          ? secondary
          : (isGood ? AppColors.income : AppColors.expense);
      delta = Row(
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${pct.abs().toStringAsFixed(pct.abs() < 10 ? 1 : 0)}%',
            style: metaStyle.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.get(
                elapsedDays < dayCount ? 'stats_vs_prev_same' : 'stats_vs_prev',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
          ),
        ],
      );
    } else if (total > 0) {
      delta = Text(l10n.get('stats_no_prev'), style: metaStyle);
    }

    Widget metric(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: metaStyle),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SheepTextStyles.amount(context),
          ),
        ],
      ),
    );

    final income = totals[1];
    final expense = totals[0];

    return SheepCard(
      padding: const EdgeInsets.all(SheepSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.get('stats_total_${_typeKeys[type]}'), style: metaStyle),
          const SizedBox(height: 4),
          Text(
            _money(settings, total),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SheepTextStyles.amount(
              context,
              size: SheepTypeScale.amountLarge,
              color: _typeColor(type),
            ),
          ),
          if (delta != null) ...[const SizedBox(height: 4), delta],
          const SizedBox(height: SheepSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: SheepSpacing.md),
          Row(
            children: [
              metric(l10n.get('stats_avg_day'), _money(settings, average)),
              metric(
                l10n.get('stats_tx_count'),
                '${counts[type]}',
              ),
            ],
          ),
          if (income > 0) ...[
            const SizedBox(height: SheepSpacing.lg),
            _buildIncomeUsage(context, income, expense),
          ],
        ],
      ),
    );
  }

  /// "Spent 72% of income" with a bar that turns amber past 80 % and red
  /// once spending exceeds income.
  Widget _buildIncomeUsage(BuildContext context, double income, double expense) {
    final l10n = L10n.of(context);
    final brightness = Theme.of(context).brightness;
    final ratio = expense / income;
    final color = ratio > 1
        ? AppColors.expense
        : ratio >= 0.8
        ? AppColors.warning
        : AppColors.income;
    final percent = (ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.get(
                  ratio > 1 ? 'stats_overspent' : 'stats_spent_of_income',
                  params: {'p': '$percent'},
                ),
                style: SheepTextStyles.itemMeta(context).copyWith(
                  color: AppColors.getTextPrimary(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (ratio <= 1)
              Text(
                l10n.get('stats_kept', params: {'p': '${100 - percent}'}),
                style: SheepTextStyles.itemMeta(context),
              ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          minHeight: 6,
          borderRadius: BorderRadius.circular(SheepRadius.pill),
          backgroundColor: AppColors.getSubtleSurface(brightness),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- trend

  Widget _buildTrendCard(
    BuildContext context,
    AppSettings settings,
    Map<DateTime, double> daily,
    DateTime start,
    DateTime end,
    String locale,
  ) {
    final l10n = L10n.of(context);
    final brightness = Theme.of(context).brightness;
    final today = _day(DateTime.now());
    final dayCount = end.difference(start).inDays + 1;
    final buckets = <_TrendBucket>[];
    final String unitKey;

    double sumBetween(DateTime from, DateTime to) {
      var sum = 0.0;
      for (final entry in daily.entries) {
        if (!entry.key.isBefore(from) && !entry.key.isAfter(to)) {
          sum += entry.value;
        }
      }
      return sum;
    }

    if (dayCount <= 31) {
      unitKey = 'day';
      for (var i = 0; i < dayCount; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        buckets.add(
          _TrendBucket(
            '${d.day}',
            DateFormat('EEE dd/MM', locale).format(d),
            daily[d] ?? 0,
            d == today,
            isFuture: d.isAfter(today),
          ),
        );
      }
    } else if (dayCount <= 120) {
      unitKey = 'week';
      for (
        var from = start;
        !from.isAfter(end);
        from = DateTime(from.year, from.month, from.day + 7)
      ) {
        var to = DateTime(from.year, from.month, from.day + 6);
        if (to.isAfter(end)) to = end;
        buckets.add(
          _TrendBucket(
            DateFormat('dd/MM').format(from),
            '${DateFormat('dd/MM').format(from)} – ${DateFormat('dd/MM').format(to)}',
            sumBetween(from, to),
            !today.isBefore(from) && !today.isAfter(to),
            isFuture: from.isAfter(today),
          ),
        );
      }
    } else {
      unitKey = 'month';
      for (
        var month = DateTime(start.year, start.month);
        !month.isAfter(end);
        month = DateTime(month.year, month.month + 1)
      ) {
        var from = month.isBefore(start) ? start : month;
        var to = DateTime(month.year, month.month + 1, 0);
        if (to.isAfter(end)) to = end;
        buckets.add(
          _TrendBucket(
            DateFormat('MM/yy').format(month),
            DateFormat('MM/yyyy').format(month),
            sumBetween(from, to),
            today.year == month.year && today.month == month.month,
            isFuture: from.isAfter(today),
          ),
        );
      }
    }

    final color = _typeColor(_selectedTypeIndex);
    final maxValue = buckets.fold<double>(0, (m, b) => math.max(m, b.value));
    final pastBuckets = buckets.where((b) => !b.isFuture).toList();
    final average = pastBuckets.isEmpty
        ? 0.0
        : pastBuckets.fold<double>(0, (s, b) => s + b.value) /
              pastBuckets.length;
    final barWidth = buckets.length > 20
        ? 6.0
        : buckets.length > 10
        ? 10.0
        : 18.0;
    final labelStep = (buckets.length / 6).ceil().clamp(1, 1000);
    final mutedBar = color.withValues(alpha: 0.35);

    return SheepCard(
      padding: const EdgeInsets.fromLTRB(
        SheepSpacing.md,
        SheepSpacing.lg,
        SheepSpacing.md,
        SheepSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                minY: 0,
                maxY: maxValue <= 0 ? 1 : maxValue * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 ||
                            i >= buckets.length ||
                            i % labelStep != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            buckets[i].label,
                            style: SheepTextStyles.itemMeta(context),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (average > 0)
                      HorizontalLine(
                        y: average,
                        color: AppColors.getTextSecondary(
                          brightness,
                        ).withValues(alpha: 0.6),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                  ],
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.getTextPrimary(brightness),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          '${buckets[groupIndex].tooltip}\n',
                          TextStyle(
                            color: AppColors.getSurface(brightness),
                            fontSize: SheepTypeScale.meta,
                          ),
                          children: [
                            TextSpan(
                              text: _money(settings, rod.toY),
                              style: TextStyle(
                                color: AppColors.getSurface(brightness),
                                fontSize: SheepTypeScale.body,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < buckets.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: buckets[i].value,
                          // Highlight the current day / week / month; the
                          // rest stay softer so the eye lands on "now".
                          color: buckets[i].isCurrent ||
                                  !buckets.any((b) => b.isCurrent)
                              ? color
                              : mutedBar,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SheepSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 16,
                child: CustomPaint(
                  size: const Size(16, 1),
                  painter: _DashPainter(
                    AppColors.getTextSecondary(brightness),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${l10n.get('stats_avg_per_$unitKey')}: ${_money(settings, average)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheepTextStyles.itemMeta(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- breakdown

  Widget _buildBreakdownCard(
    BuildContext context,
    List<_StatEntry> chartStats,
    List<_StatEntry> stats,
    double total,
    int transactionCount,
    Map<String, String> percentLabels,
    AppSettings settings,
  ) {
    return SheepCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          _buildPieChart(context, chartStats, total, transactionCount, settings),
          ..._buildStatRows(context, stats, total, percentLabels, settings),
        ],
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
    final l10n = L10n.of(context);

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
        _buildMoreCategoriesButton(
          context,
          l10n.get(
            'stats_more_categories',
            params: {'count': '$remainingCount'},
          ),
          Icons.keyboard_arrow_down_rounded,
          () => setState(() => _expandedStatTypes.add(_selectedTypeIndex)),
        )
      else if (isExpanded && stats.length > defaultVisibleCount)
        _buildMoreCategoriesButton(
          context,
          l10n.get('stats_show_less'),
          Icons.keyboard_arrow_up_rounded,
          () => setState(() => _expandedStatTypes.remove(_selectedTypeIndex)),
        ),
    ];
  }

  Widget _buildMoreCategoriesButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: SheepSpacing.sm),
      child: Center(
        child: TextButton.icon(
          onPressed: onTap,
          iconAlignment: IconAlignment.end,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, SheepControl.heightSmall),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- highlights

  Widget _buildHighlightsCard(
    BuildContext context,
    AppSettings settings,
    List<_StatEntry> stats,
    Map<String, String> percentLabels,
    Transaction? biggestTx,
    Map<String, CategoryModel> categoriesById,
    Map<DateTime, double> daily,
    int dayCount,
    String locale,
  ) {
    final l10n = L10n.of(context);
    final rows = <Widget>[];

    Widget row({
      required Widget leading,
      required String label,
      required String title,
      required String trailing,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SheepSpacing.lg,
          vertical: SheepSpacing.md,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: SheepSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: SheepTextStyles.itemMeta(context)),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheepTextStyles.itemTitle(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SheepSpacing.sm),
            Text(trailing, style: SheepTextStyles.amount(context)),
          ],
        ),
      );
    }

    final top = stats.isNotEmpty && stats.first.amount > 0 ? stats.first : null;
    if (top != null) {
      rows.add(
        row(
          leading: SheepCategoryIcon(
            icon: top.category.iconData,
            color: _categoryColor(top.category),
            imagePath: top.category.imagePath,
            size: 36,
          ),
          label: l10n.get('stats_top_category'),
          title: top.category.name,
          trailing: '${percentLabels[top.category.id] ?? '0'}%',
        ),
      );
    }

    if (biggestTx != null) {
      final cat = categoriesById[biggestTx.categoryId];
      final note = biggestTx.note.trim();
      rows.add(
        row(
          leading: SheepCategoryIcon(
            icon: cat?.iconData ?? Icons.receipt_long_rounded,
            color: cat != null
                ? _categoryColor(cat)
                : _typeColor(_selectedTypeIndex),
            imagePath: cat?.imagePath,
            size: 36,
          ),
          label:
              '${l10n.get('stats_biggest_tx')} · ${DateFormat('dd/MM').format(biggestTx.date)}',
          title: note.isNotEmpty ? note : (cat?.name ?? l10n.get('other')),
          trailing: _money(settings, biggestTx.amount),
        ),
      );
    }

    // Weekday pattern only means something once every weekday has shown up
    // at least twice.
    if (dayCount >= 14 && daily.isNotEmpty) {
      final byWeekday = List<double>.filled(7, 0);
      for (final entry in daily.entries) {
        byWeekday[entry.key.weekday - 1] += entry.value;
      }
      var best = 0;
      for (var i = 1; i < 7; i++) {
        if (byWeekday[i] > byWeekday[best]) best = i;
      }
      // 2024-01-01 is a Monday; shift by `best` to name the weekday.
      final name = toBeginningOfSentenceCase(
        DateFormat('EEEE', locale).format(DateTime(2024, 1, 1 + best)),
      );
      final brightness = Theme.of(context).brightness;
      rows.add(
        row(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tint(_typeColor(_selectedTypeIndex), brightness),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: _typeColor(_selectedTypeIndex),
            ),
          ),
          label: l10n.get('stats_busiest_weekday_${_typeKeys[_selectedTypeIndex]}'),
          title: name,
          trailing: _money(settings, byWeekday[best]),
        ),
      );
    }

    return SheepGroup(dividerIndent: 64, children: rows);
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

    final percentLabels = _buildPercentLabels(stats, total);

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
            key: ValueKey('pie-chart-$_selectedTypeIndex-${stats.length}'),
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
                      ? L10n.of(context).get(_typeKeys[_selectedTypeIndex])
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
                      color: _typeColor(_selectedTypeIndex),
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
              SheepCategoryIcon(
                icon: stat.category.iconData,
                color: color,
                imagePath: stat.category.imagePath,
              ),
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
                  tx.isCompleted &&
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

    // Group by amount
    final amountToIds = <double, List<String>>{};
    for (final stat in activeStats) {
      amountToIds.putIfAbsent(stat.amount, () => []).add(stat.category.id);
    }

    final groups = <_StatsPercentGroup>[];
    for (final entry in amountToIds.entries) {
      final amount = entry.key;
      final ids = entry.value;
      final exactPercent = (amount / total) * 100;
      groups.add(_StatsPercentGroup(amount, ids, exactPercent));
    }

    int gcd(int a, int b) {
      while (b != 0) {
        final t = b;
        b = a % b;
        a = t;
      }
      return a;
    }

    int overallGcd = groups[0].categoryIds.length;
    for (int i = 1; i < groups.length; i++) {
      overallGcd = gcd(overallGcd, groups[i].categoryIds.length);
    }

    int target = 100;
    if (100 % overallGcd != 0) {
      final lower = (100 ~/ overallGcd) * overallGcd;
      final upper = lower + overallGcd;
      if ((100 - lower).abs() <= (upper - 100).abs()) {
        target = lower;
      } else {
        target = upper;
      }
      if (target == 0) {
        target = overallGcd;
      }
    }

    double bestError = double.infinity;
    List<int> bestP = [];

    void search(
      int index,
      int remainingSum,
      List<int> currentP,
      double currentError,
    ) {
      if (currentError >= bestError) return;
      if (index == groups.length) {
        if (remainingSum == 0) {
          bestError = currentError;
          bestP = List.from(currentP);
        }
        return;
      }

      final group = groups[index];
      final s = group.categoryIds.length;
      final e = group.exact;

      final rounded = e.round();
      final minP = math.max(0, rounded - 5);
      final maxP = math.min(remainingSum ~/ s, rounded + 5);

      final candidates = List.generate(maxP - minP + 1, (i) => minP + i);
      candidates.sort((a, b) => ((a - e).abs()).compareTo((b - e).abs()));

      for (final p in candidates) {
        final err = s * (p - e) * (p - e);
        currentP.add(p);
        search(index + 1, remainingSum - s * p, currentP, currentError + err);
        currentP.removeLast();
      }
    }

    search(0, target, [], 0.0);

    if (bestP.isEmpty) {
      void searchFallback(
        int index,
        int remainingSum,
        List<int> currentP,
        double currentError,
      ) {
        if (currentError >= bestError) return;
        if (index == groups.length) {
          if (remainingSum == 0) {
            bestError = currentError;
            bestP = List.from(currentP);
          }
          return;
        }

        final group = groups[index];
        final s = group.categoryIds.length;
        final e = group.exact;

        final minP = 0;
        final maxP = remainingSum ~/ s;

        final candidates = List.generate(maxP - minP + 1, (i) => minP + i);
        candidates.sort((a, b) => ((a - e).abs()).compareTo((b - e).abs()));

        for (final p in candidates) {
          final err = s * (p - e) * (p - e);
          currentP.add(p);
          searchFallback(
            index + 1,
            remainingSum - s * p,
            currentP,
            currentError + err,
          );
          currentP.removeLast();
        }
      }

      searchFallback(0, target, [], 0.0);
    }

    final labels = <String, String>{};
    if (bestP.isNotEmpty) {
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];
        final p = bestP[i];
        for (final id in group.categoryIds) {
          labels[id] = p.toString();
        }
      }
    } else {
      for (final stat in activeStats) {
        labels[stat.category.id] = (stat.amount / total * 100)
            .round()
            .toString();
      }
    }

    return labels;
  }

  Color _categoryColor(CategoryModel category) {
    final fallback = _fallbackColors[category.id];
    if (fallback != null) return fallback;
    return category.colorValue != null
        ? Color(category.colorValue!)
        : _typeColor(_selectedTypeIndex);
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

/// Short dashed stroke used as the legend for the chart's average line.
class _DashPainter extends CustomPainter {
  final Color color;

  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}
