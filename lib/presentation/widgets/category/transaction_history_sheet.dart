import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/transaction.dart';
import '../common/sheep_widgets.dart';
import '../../../core/utils/l10n.dart';

class TransactionHistorySheet extends StatelessWidget {
  final CategoryModel category;
  final List<Transaction> transactions;

  const TransactionHistorySheet({
    super.key,
    required this.category,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final Color catColor = category.colorValue != null
        ? Color(category.colorValue!)
        : AppColors.primary;

    final double totalAccumulated = transactions.fold(
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

            _buildHeader(context, catColor, totalAccumulated),

            if (isSavings && category.targetAmount != null) ...[
              const SizedBox(height: SheepSpacing.lg),
              _buildGoalDashboard(context, catColor, totalAccumulated),
            ],

            const SizedBox(height: SheepSpacing.lg),
            Expanded(
              child: _buildTransactionList(context, scrollController, catColor),
            ),
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
            SheepCategoryIcon(icon: category.iconData, color: catColor),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.effectiveTypeIndex == 2
                      ? l10n.get('total_target')
                      : l10n.get('total_spent_cat'),
                  style: TextStyle(
                    fontSize: SheepTypeScale.micro,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                Text(
                  CurrencyUtil.formatDisplayAmount(
                    total,
                    settings.currencyCode,
                    isHidden: settings.hideAmounts,
                  ),
                  style: TextStyle(
                    fontSize: SheepTypeScale.bodyLarge,
                    fontWeight: FontWeight.bold,
                    color: category.effectiveTypeIndex == 2
                        ? AppColors.savings
                        : (category.effectiveTypeIndex == 0
                              ? AppColors.expense
                              : AppColors.income),
                  ),
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
    Color catColor,
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

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(
        horizontal: SheepSpacing.sm,
        vertical: SheepSpacing.sm,
      ),
      itemCount: transactions.length,
      itemBuilder: (_, i) {
        final tx = transactions[i];
        final typeIndex = category.effectiveTypeIndex;
        final isSavings = typeIndex == 2;
        final isExpense = typeIndex == 0;
        return SheepTransactionCard(
          icon: category.iconData,
          iconColor: catColor,
          title: category.name,
          dateText: tx.note.isNotEmpty ? tx.note : l10n.get('no_note'),
          amountText: settings.hideAmounts
              ? CurrencyUtil.formatMaskedByCurrency(settings.currencyCode)
              : '${isExpense
                    ? '-'
                    : isSavings
                    ? ''
                    : '+'}${CurrencyUtil.formatMoney(tx.amount)}',
          amountIcon: isSavings ? Icons.arrow_upward_rounded : null,
          amountColor: isSavings
              ? AppColors.savings
              : isExpense
              ? AppColors.expense
              : AppColors.income,
          badgeText: isSavings
              ? l10n.savings
              : isExpense
              ? l10n.expense
              : l10n.income,
        );
      },
    );
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
    final totalInMonth = transactions
        .where((tx) => tx.date.month == now.month && tx.date.year == now.year)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final goalType = category.effectiveGoalTypeIndex;
    if (goalType == 1) {
      // --- LOẠI: ĐỊNH KỲ HÀNG THÁNG ---
      final target = category.targetAmount ?? 0;
      final remaining = target - totalInMonth;
      final progress = target > 0
          ? (totalInMonth / target).clamp(0.0, 1.0)
          : 0.0;

      // Calculate days left until reminder day in this month
      int reminderDay = category.reminderDay ?? 10;
      // Handle end of month
      int lastDay = DateTime(now.year, now.month + 1, 0).day;
      if (reminderDay > lastDay) reminderDay = lastDay;

      int daysLeft = reminderDay - now.day;
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
            '${l10n.get('target_date')}: ${l10n.get('day')} $reminderDay ${l10n.get('month')} ${now.month} (${l10n.get('days_left', params: {'count': daysLeft.toString()})})';
      } else if (remaining <= 0) {
        planningText = l10n.get('done_this_month');
      } else {
        planningText =
            '${l10n.get('overdue')} (${l10n.get('day')} $reminderDay)';
      }

      return _buildDashboardCard(
        context,
        title:
            '${l10n.get('accumulate_periodic').toUpperCase()} ${l10n.get('month').toUpperCase()} ${now.month}',
        subtitle: planningText,
        progress: progress,
        info: infoText,
        footerLeft:
            '${l10n.get('total_savings_label')}: ${CurrencyUtil.formatDisplayAmount(totalInMonth, settings.currencyCode, isHidden: settings.hideAmounts)}',
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
              AppColors.savings.withOpacity(0.05),
              AppColors.savings.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
          border: Border.all(color: AppColors.savings.withOpacity(0.1)),
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
                backgroundColor: AppColors.savings.withOpacity(0.1),
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
