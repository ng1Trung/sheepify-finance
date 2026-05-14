import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../core/utils/l10n.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/common/sheep_widgets.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onViewAllSavings;

  const HomeTab({super.key, required this.onViewAllSavings});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isBalanceVisible = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return ValueListenableBuilder(
      valueListenable: Hive.box<AppSettings>(kSettingsBox).listenable(),
      builder: (context, settingsBox, _) {
        final settings = settingsBox.get('current') ?? AppSettings();

        return ValueListenableBuilder(
          valueListenable: Hive.box<Transaction>(kMoneyBox).listenable(),
          builder: (context, box, _) {
            final transactions = box.values.cast<Transaction>().toList();
            final categories = Hive.box<CategoryModel>(kCatBox).values.toList();

            // 1. Calculate Total Balance Safely
            double totalIncome = transactions
                .where((tx) => !tx.isExpense)
                .fold<double>(0.0, (sum, tx) => sum + tx.amount);
            double totalExpense = transactions
                .where((tx) => tx.isExpense)
                .fold<double>(0.0, (sum, tx) => sum + tx.amount);
            double totalBalance = totalIncome - totalExpense;

            // 2. Filter Savings Categories
            final savingsCategories = categories
                .where((c) => c.typeIndex == 2)
                .toList();

            // 3. Filter Recent Transactions (Last 7 Days)
            final now = DateTime.now();
            final sevenDaysAgo = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 6));
            final recentTxs =
                transactions
                    .where(
                      (tx) => tx.date.isAfter(
                        sevenDaysAgo.subtract(const Duration(seconds: 1)),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

            final topPadding = MediaQuery.of(context).padding.top;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- HEADER & BALANCE CARD ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      SheepSpacing.page,
                      topPadding + 20,
                      SheepSpacing.page,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.getTextSecondary(
                                      theme.brightness,
                                    ),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Jason',
                                  style: theme.textTheme.displayMedium
                                      ?.copyWith(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.getTextPrimary(
                                          theme.brightness,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 40, height: 40),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // THE BALANCE CARD
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFEAEAEA),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.totalBalance,
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                      letterSpacing: 0,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _isBalanceVisible =
                                          !_isBalanceVisible,
                                    ),
                                    child: Icon(
                                      _isBalanceVisible
                                          ? LineIcons.eye
                                          : LineIcons.eyeSlash,
                                      color: Colors.black.withOpacity(0.3),
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isBalanceVisible
                                    ? '${settings.currencyCode} ${CurrencyUtil.formatNumber(totalBalance)}'
                                    : '${settings.currencyCode} **********',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight:
                                      FontWeight.w900, // Đậm hơn để nổi bật
                                  color: Colors.black,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  _buildMiniStat(
                                    label: 'THU',
                                    amount: totalIncome,
                                    color: AppColors.income,
                                    currencyCode: settings.currencyCode,
                                    prefix: '+ ',
                                    isDark: false,
                                    isVisible: _isBalanceVisible,
                                  ),
                                  const SizedBox(width: 24),
                                  _buildMiniStat(
                                    label: 'CHI',
                                    amount: totalExpense,
                                    color: AppColors.expense,
                                    currencyCode: settings.currencyCode,
                                    prefix: '- ',
                                    isDark: false,
                                    isVisible: _isBalanceVisible,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 10),
                ), // Giảm từ 20 xuống 10
                // --- SAVINGS SECTION ---
                if (savingsCategories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: SheepSpacing.pageHorizontal,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEAEAEA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.get('savings'),
                              style: SheepTextStyles.sectionTitle(context),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 115,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  right: 24,
                                ),
                                itemCount: savingsCategories.length,
                                itemBuilder: (context, index) {
                                  final cat = savingsCategories[index];
                                  return _buildSavingsCard(
                                    context,
                                    cat,
                                    transactions,
                                    settings.currencyCode,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                if (recentTxs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SheepSpacing.page,
                        0,
                        SheepSpacing.page,
                        24,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEAEAEA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Giao dịch gần đây",
                              style: SheepTextStyles.sectionTitle(context),
                            ),
                            const Expanded(
                              child: SheepEmptyState(
                                message: 'Chưa có giao dịch gần đây',
                                description:
                                    'Các khoản thu chi trong 7 ngày qua sẽ xuất hiện tại đây.',
                                assetWidth: 170,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: SheepSpacing.pageHorizontal,
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEAEAEA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Giao dịch gần đây",
                              style: SheepTextStyles.sectionTitle(context),
                            ),
                            const SizedBox(height: 16),
                            ...recentTxs.map((tx) {
                              final cat = categories.firstWhere(
                                (c) => c.id == tx.categoryId,
                                orElse: () => CategoryModel(
                                  id: '?',
                                  name: '?',
                                  iconCode: Icons.help_outline.codePoint,
                                  isExpense: tx.isExpense,
                                ),
                              );
                              return _buildRecentTransactionCard(
                                context,
                                tx,
                                cat,
                                settings.currencyCode,
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (recentTxs.isNotEmpty)
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRecentTransactionCard(
    BuildContext context,
    Transaction tx,
    CategoryModel cat,
    String currencyCode,
  ) {
    final isExpense = tx.isExpense;
    return SheepTransactionCard(
      icon: cat.iconData,
      title: cat.name,
      dateText: tx.note.isNotEmpty ? tx.note : L10n.of(context).get('no_note'),
      amountText:
          '${isExpense ? '-' : '+'} ${CurrencyUtil.formatByCurrency(tx.amount, currencyCode)}',
      amountColor: isExpense ? AppColors.expense : AppColors.income,
      badgeText: isExpense ? 'Chi tiêu' : 'Thu nhập',
    );
  }

  Widget _buildMiniStat({
    required String label,
    required double amount,
    required Color color,
    required String currencyCode,
    String? prefix,
    bool isDark = false,
    bool isVisible = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white38 : Colors.grey[500],
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isVisible
              ? '${currencyCode.toUpperCase()} ${prefix ?? ''}${CurrencyUtil.formatNumber(amount)}'
              : '${currencyCode.toUpperCase()} ********',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Chào buổi sáng,';
    if (hour < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  Widget _buildSavingsCard(
    BuildContext context,
    CategoryModel cat,
    List<Transaction> allTxs,
    String? currencyCode,
  ) {
    double saved = allTxs
        .where((tx) => tx.categoryId == cat.id)
        .fold<double>(0.0, (sum, tx) => sum + tx.amount);
    double target = cat.targetAmount ?? 1.0;
    if (target <= 0) target = 1.0;
    double progress = (saved / target).clamp(0.0, 1.0);

    return Container(
      width: 96, // Thu hẹp card
      margin: const EdgeInsets.only(
        right: 4,
      ), // Thu hẹp khoảng cách giữa các item
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.5,
                  backgroundColor: Colors.grey[100],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
              Icon(
                cat.iconData,
                color: Color(cat.colorValue ?? Colors.black.value),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            cat.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${currencyCode ?? 'VND'} ${CurrencyUtil.formatCompact(saved)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
