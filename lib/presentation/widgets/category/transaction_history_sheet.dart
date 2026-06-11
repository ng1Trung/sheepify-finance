import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/currency_util.dart';
import '../../../core/utils/financial_cycle_util.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/transaction.dart';
import '../common/sheep_widgets.dart';
import '../../../core/utils/l10n.dart';
import '../transaction_form.dart';

class TransactionHistorySheet extends StatelessWidget {
  final CategoryModel category;
  final List<Transaction> transactions;
  final double typeTotal;
  final String? sharePercentText;

  const TransactionHistorySheet({
    super.key,
    required this.category,
    required this.transactions,
    required this.typeTotal,
    this.sharePercentText,
  });

  @override
  Widget build(BuildContext context) {
    final Color catColor = category.colorValue != null
        ? Color(category.colorValue!)
        : AppColors.primary;

    final double rangeTotal = transactions.fold(
      0.0,
      (sum, tx) => sum + tx.amount,
    );
    final bool isSavings = category.effectiveTypeIndex == 2;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(Theme.of(context).brightness),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SheepRadius.sheet),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: SheepSpacing.md),
            _buildDragHandle(),
            const SizedBox(height: SheepSpacing.lg),

            _buildHeader(context, catColor, rangeTotal),

            if (isSavings && category.targetAmount != null) ...[
              const SizedBox(height: SheepSpacing.lg),
              _buildGoalDashboard(context, catColor, rangeTotal),
            ],

            const SizedBox(height: SheepSpacing.lg),
            Expanded(child: _buildTransactionList(context, scrollController)),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(SheepRadius.sm),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color catColor, double total) {
    final l10n = L10n.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final typeIndex = category.effectiveTypeIndex;
    final hasTotal = total > 0;
    final share = typeTotal > 0 ? (total / typeTotal * 100) : 0.0;
    final shareText = sharePercentText ?? _formatSharePercent(share);
    final shareTargetLabel = typeIndex == 2
        ? l10n.savings.toLowerCase()
        : typeIndex == 1
        ? l10n.income.toLowerCase()
        : l10n.expense.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SheepSpacing.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SheepSpacing.lg,
          vertical: SheepSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.getBackground(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
        ),
        child: Row(
          children: [
            SheepCategoryIcon(
              icon: category.iconData,
              color: catColor,
              imagePath: category.imagePath,
            ),
            const SizedBox(width: SheepSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.get(
                      'num_transactions',
                      params: {'count': transactions.length.toString()},
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: SheepTypeScale.micro,
                    ),
                  ),
                ],
              ),
            ),
            if (hasTotal)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyUtil.formatDisplayAmount(
                      total,
                      settings.currencyCode,
                      isHidden: settings.hideAmounts,
                    ),
                    style: TextStyle(
                      fontSize: SheepTypeScale.bodyLarge,
                      fontWeight: FontWeight.bold,
                      color: typeIndex == 2
                          ? AppColors.savings
                          : (typeIndex == 0
                                ? AppColors.expense
                                : AppColors.income),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chi\u1EBFm $shareText% t\u1ED5ng $shareTargetLabel',
                    textAlign: TextAlign.right,
                    style: SheepTextStyles.itemMeta(
                      context,
                    ).copyWith(fontSize: SheepTypeScale.micro),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(
    BuildContext context,
    ScrollController controller,
  ) {
    final l10n = L10n.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.history, size: 50, color: Colors.grey[200]),
            const SizedBox(height: SheepSpacing.sm),
            Text(
              l10n.get('no_transactions'),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<Transaction>>{};
    for (final tx in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final sortedDayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final typeIndex = category.effectiveTypeIndex;
    final isSavings = typeIndex == 2;
    final isExpense = typeIndex == 0;
    final typeVisuals = SheepTransactionTypeVisuals.fromTypeIndex(typeIndex);
    final catColor = category.colorValue != null
        ? Color(category.colorValue!)
        : AppColors.primary;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        SheepSpacing.page,
        SheepSpacing.sm,
        SheepSpacing.page,
        SheepSpacing.xl,
      ),
      children: [
        SheepCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int dayIdx = 0; dayIdx < sortedDayKeys.length; dayIdx++)
                ..._buildDayGroup(
                  context,
                  sortedDayKeys[dayIdx],
                  grouped[sortedDayKeys[dayIdx]]!,
                  settings,
                  typeVisuals.color,
                  catColor,
                  isExpense,
                  isSavings,
                  dayIdx == sortedDayKeys.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDayGroup(
    BuildContext context,
    String dayKey,
    List<Transaction> dayTxs,
    AppSettings settings,
    Color amountColor,
    Color catColor,
    bool isExpense,
    bool isSavings,
    bool isLastDay,
  ) {
    dayTxs.sort((a, b) {
      final dateComparison = b.date.compareTo(a.date);
      if (dateComparison != 0) return dateComparison;
      return b.key.toString().compareTo(a.key.toString());
    });

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: Text(
          DateFormat(
            'EEEE, dd/MM/yyyy',
            settings.languageCode == 'vi' ? 'vi_VN' : 'en_US',
          ).format(DateTime.parse(dayKey)),
          style: SheepTextStyles.dateHeader(context),
        ),
      ),
      for (int i = 0; i < dayTxs.length; i++)
        _buildTransactionRow(
          context,
          dayTxs[i],
          settings,
          amountColor,
          catColor,
          isExpense,
          isSavings,
          i == dayTxs.length - 1,
          isLastDay,
        ),
    ];
  }

  Widget _buildTransactionRow(
    BuildContext context,
    Transaction tx,
    AppSettings settings,
    Color amountColor,
    Color catColor,
    bool isExpense,
    bool isSavings,
    bool isLastInDay,
    bool isLastDay,
  ) {
    final amountText = settings.hideAmounts
        ? CurrencyUtil.formatMaskedByCurrency(settings.currencyCode)
        : '${isExpense
              ? '-'
              : isSavings
              ? ''
              : '+'}${CurrencyUtil.formatMoney(tx.amount)}';

    final brightness = Theme.of(context).brightness;
    final noteText = tx.note.trim().isNotEmpty ? tx.note.trim() : category.name;

    return Container(
      margin: EdgeInsets.only(
        bottom: !isLastInDay || !isLastDay ? SheepSpacing.itemGap : 0,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: BorderRadius.circular(SheepRadius.lg),
        border: Border.all(color: AppColors.getBorder(brightness)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SheepRadius.lg),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: true,
          enableDrag: true,
          builder: (_) => TransactionForm(transaction: tx),
        ),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SheepCategoryIcon(
                  icon: category.iconData,
                  color: catColor,
                  size: 34,
                  imagePath: category.imagePath,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    noteText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheepTextStyles.itemTitle(context).copyWith(
                      fontSize: SheepTypeScale.item,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: Text(
                    amountText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: SheepTypeScale.item,
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSharePercent(double share) {
    if (share <= 0) return '0';
    if (share >= 10) return share.round().toString();
    return share.toStringAsFixed(1);
  }

  Widget _buildGoalDashboard(
    BuildContext context,
    Color catColor,
    double totalAllTime,
  ) {
    final l10n = L10n.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final now = DateTime.now();
    final cycleRange = FinancialCycleUtil.cycleRangeFor(
      now,
      settings.financialCycleStartDay,
    );
    final allCategoryTransactions = Hive.box<Transaction>(
      kMoneyBox,
    ).values.where((tx) => tx.categoryId == category.id);
    final totalInCycle = allCategoryTransactions
        .where((tx) => FinancialCycleUtil.isInRange(tx.date, cycleRange))
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final goalType = category.effectiveGoalTypeIndex;
    if (goalType == 1) {
      // --- LOẠI: ĐỊNH KỲ HÀNG THÁNG ---
      final target = category.targetAmount ?? 0;
      final remaining = target - totalInCycle;
      final progress = target > 0
          ? (totalInCycle / target).clamp(0.0, 1.0)
          : 0.0;

      final reminderDate = FinancialCycleUtil.cycleDateInRange(
        range: cycleRange,
        day: category.reminderDay ?? 10,
      );
      final today = DateTime(now.year, now.month, now.day);
      final daysLeft = reminderDate.difference(today).inDays;

      String infoText = "";
      String planningText = "";

      if (daysLeft > 0 && remaining > 0) {
        final daily = remaining / daysLeft;
        infoText = l10n.get(
          'need_more',
          params: {
            'amount': CurrencyUtil.formatDisplayAmount(
              daily,
              settings.currencyCode,
              isHidden: settings.hideAmounts,
            ),
          },
        );
        planningText =
            '${l10n.get('target_date')}: ${DateFormat('dd/MM/yyyy').format(reminderDate)} (${l10n.get('days_left', params: {'count': daysLeft.toString()})})';
      } else if (remaining <= 0) {
        planningText = l10n.get('done_this_month');
      } else {
        planningText =
            '${l10n.get('overdue')} (${DateFormat('dd/MM/yyyy').format(reminderDate)})';
      }

      return _buildDashboardCard(
        context,
        title:
            '${l10n.get('accumulate_periodic').toUpperCase()} - ${l10n.get('current_cycle').toUpperCase()}',
        subtitle: planningText,
        progress: progress,
        info: infoText,
        footerLeft:
            '${l10n.get('total_savings_label')}: ${CurrencyUtil.formatDisplayAmount(totalInCycle, settings.currencyCode, isHidden: settings.hideAmounts)}',
        footerRight:
            '${l10n.get('monthly_goal_label')}: ${CurrencyUtil.formatDisplayAmount(target, settings.currencyCode, isHidden: settings.hideAmounts)}',
      );
    } else if (goalType == 2 || goalType == 3) {
      // --- LOẠI: MỤC TIÊU DÀI HẠN / NGẮN HẠN ---
      final target = category.targetAmount ?? 0;
      final remaining = target - totalAllTime;
      final progress = target > 0
          ? (totalAllTime / target).clamp(0.0, 1.0)
          : 0.0;

      final targetDate =
          category.targetDate ??
          DateTime(category.targetYear ?? now.year, 12, 31);
      final monthsLeft =
          ((targetDate.year - now.year) * 12) + targetDate.month - now.month;

      String infoText = "";
      String planningText = "";

      if (monthsLeft > 0 && remaining > 0) {
        planningText =
            '${l10n.get('target_date')}: ${DateFormat('MM/yyyy').format(targetDate)} (${l10n.get('months_left', params: {'count': monthsLeft.toString()})})';
      } else if (remaining <= 0) {
        planningText = l10n.get('target_achieved');
      } else {
        planningText =
            '${l10n.get('overdue')} (${DateFormat('MM/yyyy').format(targetDate)})';
      }

      return _buildDashboardCard(
        context,
        title: l10n.get('accumulate_goal').toUpperCase(),
        subtitle: planningText,
        progress: progress,
        info: infoText,
        footerLeft:
            '${l10n.get('total_savings_label')}: ${CurrencyUtil.formatDisplayAmount(totalAllTime, settings.currencyCode, isHidden: settings.hideAmounts)}',
        footerRight:
            '${l10n.get('target_amount')}: ${CurrencyUtil.formatDisplayAmount(target, settings.currencyCode, isHidden: settings.hideAmounts)}',
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double progress,
    required String info,
    required String footerLeft,
    required String footerRight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SheepSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(SheepSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.savings.withValues(alpha: 0.05),
              AppColors.savings.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
          border: Border.all(color: AppColors.savings.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.savings,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: SheepTypeScale.body,
                    fontWeight: FontWeight.bold,
                    color: AppColors.savings,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: SheepSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(SheepRadius.sm),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.savings.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.savings,
                ),
              ),
            ),
            if (info.isNotEmpty) ...[
              const SizedBox(height: SheepSpacing.md),
              Row(
                children: [
                  const Icon(
                    LineIcons.calculator,
                    size: 16,
                    color: AppColors.savings,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    info,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.savings,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: SheepSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  footerLeft,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                Text(
                  footerRight,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
