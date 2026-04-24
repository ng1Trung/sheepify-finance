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
                        Text(
                          'Hi Jason.',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.getTextPrimary(theme.brightness),
                          ),
                        ),
                        Text(
                          _getGreeting(context),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.getTextSecondary(theme.brightness),
                            fontWeight: FontWeight.w600,
                          ),
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
                                  fontWeight: FontWeight.w900, // Đậm hơn để nổi bật
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
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        const SizedBox(height: 20), // Giảm từ 40 xuống 20
                      ],
                    ),
                  ),

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
                        l10n.get('today_transactions').toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800, // Đồng bộ
                          color: Colors.grey[700], // Đồng bộ
                        ),
                      ),
                    ),
                  ),
                ),

                if (todayTxs.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      height: 250,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có giao dịch nào.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(theme.brightness),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Các khoản thu chi trong ngày sẽ xuất hiện tại đây.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: SheepListTile(
                          title: cat.name,
                          subtitle: Text(
                            tx.note.isEmpty ? l10n.get('no_note') : tx.note,
                          ),
                          trailing: Text(
                            CurrencyUtil.formatByCurrency(
                              tx.amount,
                              settings.currencyCode ?? 'VND',
                            ),
                            style: TextStyle(
                              color: tx.isExpense
                                  ? AppColors.expense
                                  : AppColors.income,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              cat.iconData,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    }, childCount: todayTxs.length),
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
    final theme = Theme.of(context);
    double saved = allTxs
        .where((tx) => tx.categoryId == cat.id)
        .fold<double>(0.0, (sum, tx) => sum + tx.amount);
    double target = cat.targetAmount ?? 1.0;
    if (target <= 0) target = 1.0;
    double progress = (saved / target).clamp(0.0, 1.0);

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: SheepCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.income),
                  ),
                ),
                Icon(cat.iconData, color: AppColors.primary, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              cat.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyUtil.formatByCurrency(saved, currencyCode ?? 'VND'),
              style: TextStyle(
                color: AppColors.getTextSecondary(theme.brightness),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
