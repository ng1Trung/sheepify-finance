import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/transaction_form.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';

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
    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, settingsBox, _) {
        final settings = settingsBox.get('current') ?? AppSettings();

        return ValueListenableBuilder(
          valueListenable: Hive.box<Transaction>(kMoneyBox).listenable(),
          builder: (context, box, _) {
            final catBox = Hive.box<CategoryModel>(kCatBox);

            // 1. Fetch and filter transactions for balance calculation
            var calcTxs = box.values.cast<Transaction>().toList();

            if (!settings.accumulateBalance) {
              calcTxs = calcTxs
                  .where(
                    (tx) =>
                        tx.date.year == widget.selectedDate.year &&
                        tx.date.month == widget.selectedDate.month,
                  )
                  .toList();
            }

            calcTxs.sort((a, b) {
              int cmp = a.date.compareTo(b.date);
              if (cmp == 0) return a.key.toString().compareTo(b.key.toString());
              return cmp;
            });

            Map<dynamic, double> runningBalances = {};
            double currentTotal = 0;
            for (var tx in calcTxs) {
              if (tx.isExpense) {
                currentTotal -= tx.amount;
              } else {
                currentTotal += tx.amount;
              }
              runningBalances[tx.key] = currentTotal;
            }

            // 2. Filter transactions for display
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

            // 3. Summary Statistics
            double totalIncome = 0;
            double totalExpense = 0;
            for (var tx in displayTxs) {
              if (tx.isExpense)
                totalExpense += tx.amount;
              else
                totalIncome += tx.amount;
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

            return Column(
              children: [
                // --- SUMMARY CARD ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SheepCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          widget.isMonthly
                              ? 'MONTHLY BALANCE'
                              : 'DAILY BALANCE',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          CurrencyUtil.formatMoney(totalIncome - totalExpense),
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: (totalIncome - totalExpense) >= 0
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Income',
                              totalIncome,
                              AppColors.income,
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey[200],
                            ),
                            _buildStatItem(
                              'Expense',
                              totalExpense,
                              AppColors.expense,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: displayTxs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Lottie.asset('assets/empty.json', width: 200),
                              const SizedBox(height: 10),
                              Text(
                                widget.isMonthly
                                    ? 'No transactions this month'
                                    : 'No transactions today',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            bottom: 120,
                            left: 16,
                            right: 16,
                          ),
                          itemCount: sortedDayKeys.length,
                          itemBuilder: (context, dayIdx) {
                            final dKey = sortedDayKeys[dayIdx];
                            final dayTxs = grouped[dKey]!;
                            dayTxs.sort((a, b) {
                              int c = b.date.compareTo(a.date);
                              if (c == 0)
                                return b.key.toString().compareTo(
                                  a.key.toString(),
                                );
                              return c;
                            });

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.isMonthly)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      15,
                                      4,
                                      10,
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'EEEE, dd/MM/yyyy',
                                        'en_US',
                                      ).format(DateTime.parse(dKey)),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ...dayTxs.map((tx) {
                                  final cat = catBox.values.firstWhere(
                                    (c) => c.id == tx.categoryId,
                                    orElse: () => CategoryModel(
                                      id: '',
                                      name: '?',
                                      iconCode: Icons.help.codePoint,
                                      isExpense: true,
                                    ),
                                  );
                                  return Dismissible(
                                    key: ValueKey(tx.key),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(
                                        LineIcons.trash,
                                        color: AppColors.expense,
                                      ),
                                    ),
                                    onDismissed: (_) => tx.delete(),
                                    child: SheepListTile(
                                      onTap: () => showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) =>
                                            TransactionForm(transaction: tx),
                                      ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: tx.isExpense
                                              ? AppColors.expense.withOpacity(
                                                  0.08,
                                                )
                                              : AppColors.income.withOpacity(
                                                  0.08,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          IconData(
                                            cat.iconCode,
                                            fontFamily: 'MaterialIcons',
                                          ),
                                          color: tx.isExpense
                                              ? AppColors.expense
                                              : AppColors.income,
                                          size: 20,
                                        ),
                                      ),
                                      title: cat.name,
                                      subtitle: tx.note.isNotEmpty
                                          ? tx.note
                                          : null,
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            CurrencyUtil.formatMoney(tx.amount),
                                            style: TextStyle(
                                              color: tx.isExpense
                                                  ? AppColors.expense
                                                  : AppColors.income,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'Wallet: ${CurrencyUtil.formatMoney(runningBalances[tx.key] ?? 0)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyUtil.formatMoney(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
