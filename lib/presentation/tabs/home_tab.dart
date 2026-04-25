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

            // 3. Filter Today's Transactions
            final now = DateTime.now();
            final todayTxs =
                transactions
                    .where(
                      (tx) =>
                          tx.date.year == now.year &&
                          tx.date.month == now.month &&
                          tx.date.day == now.day,
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
                    padding: EdgeInsets.fromLTRB(24, topPadding + 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'J',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hi Jason.',
                                      style: theme.textTheme.displayMedium
                                          ?.copyWith(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.getTextPrimary(
                                              theme.brightness,
                                            ),
                                          ),
                                    ),
                                    Text(
                                      _getGreeting(context),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.getTextSecondary(
                                              theme.brightness,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(LineIcons.bell, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // THE BALANCE CARD (BRIGHT MINIMALIST)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFE0E0E2), // Đậm hơn chút
                                Colors.white,
                                const Color(0xFFD2D2D4), // Đậm hơn chút
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
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
                                    l10n.totalBalance.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                      letterSpacing: 1.5,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
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
                                    ? '${settings.currencyCode ?? 'VND'} ${CurrencyUtil.formatNumber(totalBalance)}'
                                    : '${settings.currencyCode ?? 'VND'} **********',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight:
                                      FontWeight.w900, // Đậm hơn để nổi bật
                                  color: Colors.black,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  _buildMiniStat(
                                    label: 'THU',
                                    amount: totalIncome,
                                    color: AppColors.income,
                                    currencyCode:
                                        settings.currencyCode ?? 'VND',
                                    prefix: '+ ',
                                    isDark: false,
                                  ),
                                  const SizedBox(width: 24),
                                  _buildMiniStat(
                                    label: 'CHI',
                                    amount: totalExpense,
                                    color: AppColors.expense,
                                    currencyCode:
                                        settings.currencyCode ?? 'VND',
                                    prefix: '- ',
                                    isDark: false,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.get('savings').toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[700],
                                ),
                              ),
                              TextButton(
                                onPressed: widget.onViewAllSavings,
                                child: Text(
                                  l10n.get('view_all'),
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.015),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height:
                                  115, // Cân đối lại cho vòng tròn 60px + text
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 40,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // --- TODAY'S TRANSACTIONS (STICKY) ---
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    height: 60,
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.centerLeft,
                      color: AppColors.getBackground(theme.brightness),
                      child: Text(
                        "Giao dịch gần đây".toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),

                if (todayTxs.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      height: 120,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có giao dịch nào',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(theme.brightness),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 250,
                            child: Text(
                              'Các khoản thu chi trong ngày sẽ xuất hiện tại đây.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: todayTxs.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.grey[200]!.withOpacity(0.5),
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final tx = todayTxs[index];
                            final cat = categories.firstWhere(
                              (c) => c.id == tx.categoryId,
                              orElse: () => CategoryModel(
                                id: '?',
                                name: '?',
                                iconCode: Icons.help_outline.codePoint,
                                isExpense: tx.isExpense,
                              ),
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      cat.iconData,
                                      size: 18,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.note.isEmpty ? cat.name : tx.note,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          DateFormat('HH:mm').format(tx.date),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[400],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${settings.currencyCode ?? 'VND'} ${tx.isExpense ? '-' : '+'} ${CurrencyUtil.formatNumber(tx.amount)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: tx.isExpense
                                          ? AppColors.expense
                                          : AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMiniStat({
    required String label,
    required double amount,
    required Color color,
    required String currencyCode,
    String? prefix,
    bool isDark = false,
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
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${currencyCode.toUpperCase()} ${prefix ?? ''}${CurrencyUtil.formatNumber(amount)}',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng ☀️';
    if (hour < 18) return 'Chào buổi chiều 🌤️';
    return 'Chào buổi tối 🌙';
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _StickyHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
