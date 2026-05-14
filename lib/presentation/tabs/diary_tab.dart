import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/transaction_form.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_dialogs.dart';
import '../widgets/common/sheep_notifications.dart';

class DiaryTab extends StatefulWidget {
  final DateTime selectedDate;
  final bool isMonthly;
  const DiaryTab({
    super.key,
    required this.selectedDate,
    required this.isMonthly,
  });

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, settingsBox, _) {
        final settings = settingsBox.get('current') ?? AppSettings();

        return ValueListenableBuilder(
          valueListenable: Hive.box<Transaction>(kMoneyBox).listenable(),
          builder: (context, box, _) {
            final catBox = Hive.box<CategoryModel>(kCatBox);

            // 1. Identify Goal categories to exclude from balance
            final goalCatIds = catBox.values
                .where((c) => c.effectiveTypeIndex == 2)
                .map((c) => c.id)
                .toSet();

            // 2. Filter transactions for display (Include all transactions for the date)
            final displayTxs = box.values.cast<Transaction>().where((tx) {
              if (widget.isMonthly) {
                return tx.date.month == widget.selectedDate.month &&
                    tx.date.year == widget.selectedDate.year;
              } else {
                return tx.date.day == widget.selectedDate.day &&
                    tx.date.month == widget.selectedDate.month &&
                    tx.date.year == widget.selectedDate.year;
              }
            }).toList();

            // 3. Summary Statistics (Exclude goals)
            double totalIncome = 0;
            double totalExpense = 0;
            for (var tx in displayTxs) {
              // Skip goals in summary
              if (goalCatIds.contains(tx.categoryId)) continue;

              if (tx.isExpense) {
                totalExpense += tx.amount;
              } else {
                totalIncome += tx.amount;
              }
            }

            // 4. Group by date
            Map<String, List<Transaction>> grouped = {};
            for (var tx in displayTxs) {
              final dayKey = DateFormat('yyyy-MM-dd').format(tx.date);
              if (grouped[dayKey] == null) grouped[dayKey] = [];
              grouped[dayKey]!.add(tx);
            }

            final sortedDayKeys = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return LayoutBuilder(
              builder: (context, viewportConstraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // --- SUMMARY CARD ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SheepSpacing.page,
                          vertical: 8,
                        ),
                        child: SheepCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                widget.isMonthly
                                    ? l10n.get('monthly_balance')
                                    : l10n.get('daily_balance'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.getTextSecondary(
                                        theme.brightness,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                CurrencyUtil.formatByCurrency(
                                  totalIncome - totalExpense,
                                  settings.currencyCode,
                                ),
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      color: (totalIncome - totalExpense) >= 0
                                          ? AppColors.income
                                          : AppColors.expense,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    l10n.income,
                                    totalIncome,
                                    AppColors.income,
                                    settings.languageCode,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: theme.dividerColor,
                                  ),
                                  _buildStatItem(
                                    l10n.expense,
                                    totalExpense,
                                    AppColors.expense,
                                    settings.languageCode,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: theme.dividerColor,
                                  ),
                                  _buildStatItem(
                                    l10n.balance,
                                    totalIncome - totalExpense,
                                    AppColors.getTextPrimary(theme.brightness),
                                    settings.languageCode,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          const topGap = 12.0;
                          const bottomGap = 24.0;
                          final minContentHeight =
                              viewportConstraints.maxHeight -
                              204 -
                              topGap -
                              bottomGap;

                          if (displayTxs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SheepSpacing.page,
                                topGap,
                                SheepSpacing.page,
                                bottomGap,
                              ),
                              child: SheepCard(
                                padding: EdgeInsets.zero,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: minContentHeight,
                                  ),
                                  child: SheepEmptyState(
                                    message: widget.isMonthly
                                        ? l10n.get('no_tx_month')
                                        : l10n.get('no_tx_today'),
                                  ),
                                ),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SheepSpacing.page,
                              topGap,
                              SheepSpacing.page,
                              bottomGap,
                            ),
                            child: SheepCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (
                                    var dayIdx = 0;
                                    dayIdx < sortedDayKeys.length;
                                    dayIdx++
                                  ) ...[
                                    Builder(
                                      builder: (context) {
                                        final dKey = sortedDayKeys[dayIdx];
                                        final dayTxs = grouped[dKey]!;
                                        dayTxs.sort((a, b) {
                                          int c = b.date.compareTo(a.date);
                                          if (c == 0) {
                                            return b.key.toString().compareTo(
                                              a.key.toString(),
                                            );
                                          }
                                          return c;
                                        });

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (widget.isMonthly)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      0,
                                                      8,
                                                      0,
                                                      10,
                                                    ),
                                                child: Text(
                                                  DateFormat(
                                                    'EEEE, dd/MM/yyyy',
                                                    'vi_VN',
                                                  ).format(
                                                    DateTime.parse(dKey),
                                                  ),
                                                  style:
                                                      SheepTextStyles.itemTitle(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            ...dayTxs.map((tx) {
                                              final cat = catBox.values
                                                  .firstWhere(
                                                    (c) =>
                                                        c.id == tx.categoryId,
                                                    orElse: () => CategoryModel(
                                                      id: '',
                                                      name: '?',
                                                      iconCode:
                                                          Icons.help.codePoint,
                                                      isExpense: true,
                                                    ),
                                                  );
                                              final isLastInDay =
                                                  tx == dayTxs.last;
                                              final isLastDay =
                                                  dayIdx ==
                                                  sortedDayKeys.length - 1;
                                              final isSavings = goalCatIds
                                                  .contains(tx.categoryId);
                                              final isExpense = tx.isExpense;

                                              return Dismissible(
                                                key: ValueKey(tx.key),
                                                direction:
                                                    DismissDirection.endToStart,
                                                background: Container(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 20,
                                                      ),
                                                  child: Icon(
                                                    LineIcons.trash,
                                                    color: AppColors.expense,
                                                  ),
                                                ),
                                                confirmDismiss: (direction) async {
                                                  return await showDialog(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        SheepConfirmDialog(
                                                          title: l10n.get(
                                                            'delete_confirm_title',
                                                          ),
                                                          content: l10n.get(
                                                            'delete_confirm_msg',
                                                          ),
                                                          confirmLabel:
                                                              l10n.delete,
                                                          onConfirm: () {},
                                                        ),
                                                  );
                                                },
                                                onDismissed: (_) {
                                                  tx.delete();
                                                  SheepNotifications.showSuccess(
                                                    context,
                                                    l10n.get('delete_success'),
                                                  );
                                                },
                                                child: SheepTransactionCard(
                                                  margin: EdgeInsets.only(
                                                    bottom:
                                                        !isLastInDay ||
                                                            !isLastDay
                                                        ? SheepSpacing.itemGap
                                                        : 0,
                                                  ),
                                                  onTap: () =>
                                                      showModalBottomSheet(
                                                        context: context,
                                                        isScrollControlled:
                                                            true,
                                                        isDismissible: true,
                                                        enableDrag: true,
                                                        builder: (_) =>
                                                            TransactionForm(
                                                              transaction: tx,
                                                            ),
                                                      ),
                                                  icon: IconData(
                                                    cat.iconCode,
                                                    fontFamily: 'MaterialIcons',
                                                  ),
                                                  title: cat.name,
                                                  dateText: tx.note.isNotEmpty
                                                      ? tx.note
                                                      : l10n.get('no_note'),
                                                  amountText:
                                                      '${isExpense ? '-' : '+'} ${CurrencyUtil.formatByCurrency(tx.amount, settings.currencyCode)}',
                                                  amountColor: isExpense
                                                      ? AppColors.expense
                                                      : AppColors.income,
                                                  badgeText: isSavings
                                                      ? l10n.savings
                                                      : isExpense
                                                      ? l10n.expense
                                                      : l10n.income,
                                                ),
                                              );
                                            }),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    double amount,
    Color color,
    String locale,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyUtil.formatCompact(amount, locale: locale),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
