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
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _selectedRange = DateTimeRange(
      start: DateTime(widget.currentMonth.year, widget.currentMonth.month, 1),
      end: DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0, 23, 59, 59),
    );
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedRange = picked);
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

            final filteredTransactions = allTransactions.where((tx) =>
                tx.date.isAfter(_selectedRange.start.subtract(const Duration(seconds: 1))) &&
                tx.date.isBefore(_selectedRange.end.add(const Duration(seconds: 1))));

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

            double displayTotal = statsMap.values.fold(0, (sum, item) => sum + item.amount);
            var sortedStats = statsMap.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));

            final screenHeight = MediaQuery.of(context).size.height;
            final headerHeight = topPadding + 20 + 44 + 28 + 48 + 28; //Ước tính chiều cao phần header
            final minCardHeight = screenHeight - headerHeight - 120; // Trừ đi khoảng trống phía dưới

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(top: topPadding + 20, bottom: 120), // Trả lại bottom padding lớn hơn để thoát khỏi Menu
              child: Column(
                children: [
                   _buildDateRangeBar(),
                  const SizedBox(height: 28),
                  _buildTabSelector(l10n),
                  const SizedBox(height: 28),

                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minCardHeight),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      width: double.infinity, // Đảm bảo luôn lấy hết chiều ngang
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.015),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: displayTotal == 0 
                        ? _buildEmptyState(l10n)
                        : Column(
                            children: [
                              _buildPieChart(sortedStats, displayTotal, settings.currencyCode, l10n),
                              
                              const SizedBox(height: 32),
                              const Divider(height: 1, color: Color(0xFFF8F8F8)),
                              const SizedBox(height: 16),

                              ...sortedStats.map((stat) => _buildStatRow(stat, displayTotal, settings.currencyCode)),
                            ],
                          ),
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
    final df = DateFormat('dd/MM/yy');
    final rangeText = "${df.format(_selectedRange.start)} - ${df.format(_selectedRange.end)}";

    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LineIcons.calendar, size: 16, color: Colors.black54),
            const SizedBox(width: 10),
            Text(
              rangeText,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(L10n l10n) {
    final labels = [l10n.get('expense'), l10n.get('income'), l10n.get('savings')];
    const unselectedColor = Color(0xFF8E8E93);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA), // Màu xám đậm hơn để nổi bật trên nền Scaffold
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.black.withOpacity(0.05)), // Thêm viền mỏng
      ),
      child: Stack(
        children: [
          // Sliding Pill Background
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            alignment: Alignment(
              _selectedTypeIndex == 0 ? -1 : (_selectedTypeIndex == 1 ? 0 : 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ),
          // Tab Buttons
          Row(
            children: List.generate(labels.length, (index) {
              final isSelected = _selectedTypeIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTypeIndex = index),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : unselectedColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<_StatEntry> stats, double total, String currency, L10n l10n) {
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
                    if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = response.touchedSection!.touchedSectionIndex;
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
                  (_touchedIndex != -1 ? stats[_touchedIndex].category.name : l10n.get('all_total')).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
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
                      currency
                    ),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
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
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyUtil.formatByCurrency(stat.amount, currency),
            style: TextStyle(
              fontFamily: 'Outfit',
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20), // Giảm từ 60 xuống 20 để bớt trống trải
        Lottie.asset(
          'assets/empty.json',
          width: 200,
          repeat: true,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), // Giảm từ 40 xuống 16 cho đồng bộ
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              color: Colors.black54,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 20), // Giảm từ 60 xuống 20
      ],
    );
  }
}
