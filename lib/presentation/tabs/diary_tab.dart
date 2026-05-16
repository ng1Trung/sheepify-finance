import 'dart:io';

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
import 'stats_tab.dart';
import '../widgets/common/sheep_toggles.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_dialogs.dart';
import '../widgets/common/sheep_notifications.dart';

class DiaryTab extends StatefulWidget {
  final DateTimeRange selectedRange;
  const DiaryTab({super.key, required this.selectedRange});

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  int _selectedViewMode = 1; // 0: chart, 1: list, 2: image
  int _selectedChartTypeIndex = 0;
  int? _selectedListImageTypeIndex; // null means all
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

            final isSingleDay =
                widget.selectedRange.start.year ==
                    widget.selectedRange.end.year &&
                widget.selectedRange.start.month ==
                    widget.selectedRange.end.month &&
                widget.selectedRange.start.day == widget.selectedRange.end.day;

            // 2. Filter transactions for display (Include all transactions for the range)
            final displayTxs = box.values.cast<Transaction>().where((tx) {
              final cat = catBox.values.firstWhere(
                (c) => c.id == tx.categoryId,
                orElse: () => CategoryModel(
                  id: '',
                  name: '?',
                  iconCode: Icons.help.codePoint,
                  isExpense: tx.isExpense,
                  typeIndex: tx.isExpense ? 0 : 1,
                ),
              );
              return (_selectedListImageTypeIndex == null ||
                      cat.effectiveTypeIndex == _selectedListImageTypeIndex) &&
                  tx.date.isAfter(
                    widget.selectedRange.start.subtract(
                      const Duration(seconds: 1),
                    ),
                  ) &&
                  tx.date.isBefore(
                    widget.selectedRange.end.add(const Duration(seconds: 1)),
                  );
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
            final galleryTxs = displayTxs;
            final groupedGalleryTxs = <String, List<Transaction>>{};
            for (final tx in galleryTxs) {
              final dayKey = DateFormat('yyyy-MM-dd').format(tx.date);
              groupedGalleryTxs.putIfAbsent(dayKey, () => []).add(tx);
            }
            final sortedGalleryDayKeys = groupedGalleryTxs.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            Widget buildViewModeSelector() {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  SheepSpacing.page,
                  8,
                  SheepSpacing.page,
                  12,
                ),
                child: SheepTripleToggle(
                  selectedIndex: _selectedViewMode,
                  labels: [
                    l10n.get('chart_view'),
                    l10n.get('list_view'),
                    l10n.get('image_view'),
                  ],
                  onChanged: (index) =>
                      setState(() => _selectedViewMode = index),
                ),
              );
            }

            Widget buildTypeFilter() {
              final labels = [
                l10n.get('expense'),
                l10n.get('income'),
                l10n.get('savings'),
              ];
              final selectedTypeIndex = _selectedViewMode == 0
                  ? _selectedChartTypeIndex
                  : _selectedListImageTypeIndex;

              return PopupMenuTheme(
                data: PopupMenuThemeData(
                  color: AppColors.getSurface(theme.brightness),
                  surfaceTintColor: Colors.transparent,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: AppColors.getBorder(theme.brightness),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: PopupMenuButton<int>(
                  initialValue: selectedTypeIndex,
                  onSelected: (index) => setState(() {
                    final canClearFilter = _selectedViewMode != 0;
                    if (_selectedViewMode == 0) {
                      _selectedChartTypeIndex = index;
                    } else if (canClearFilter &&
                        _selectedListImageTypeIndex == index) {
                      _selectedListImageTypeIndex = null;
                    } else {
                      _selectedListImageTypeIndex = index;
                    }
                  }),
                  offset: const Offset(0, 38),
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => List.generate(
                    labels.length,
                    (index) => PopupMenuItem<int>(
                      value: index,
                      height: 42,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labels[index],
                              style: SheepTextStyles.itemMeta(context).copyWith(
                                color: AppColors.getTextPrimary(
                                  theme.brightness,
                                ),
                                fontSize: 13,
                                fontWeight: selectedTypeIndex == index
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selectedTypeIndex == index)
                            const Icon(Icons.check_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(theme.brightness),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.getBorder(theme.brightness),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tune_rounded, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          selectedTypeIndex == null
                              ? l10n.get('all')
                              : labels[selectedTypeIndex],
                          style: SheepTextStyles.itemMeta(context).copyWith(
                            color: AppColors.getTextPrimary(theme.brightness),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget buildSummaryCard() {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SheepSpacing.page,
                  vertical: 8,
                ),
                child: SheepCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        isSingleDay
                            ? l10n.get('daily_balance')
                            : l10n.get('range_balance'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.getTextSecondary(theme.brightness),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            CurrencyUtil.formatDisplayAmount(
                              totalIncome - totalExpense,
                              settings.currencyCode,
                              isHidden: settings.hideAmounts,
                            ),
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  color: (totalIncome - totalExpense) >= 0
                                      ? AppColors.income
                                      : AppColors.expense,
                                ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              settings.hideAmounts = !settings.hideAmounts;
                              settings.save();
                            },
                            icon: Icon(
                              !settings.hideAmounts
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            l10n.income,
                            totalIncome,
                            AppColors.income,
                            settings.languageCode,
                            isHidden: settings.hideAmounts,
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
                            isHidden: settings.hideAmounts,
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
                            isHidden: settings.hideAmounts,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_selectedViewMode == 0) {
              return Column(
                children: [
                  buildViewModeSelector(),
                  Expanded(
                    child: StatsTab(
                      selectedRange: widget.selectedRange,
                      selectedTypeIndex: _selectedChartTypeIndex,
                      typeFilter: buildTypeFilter(),
                    ),
                  ),
                ],
              );
            }

            if (_selectedViewMode == 2) {
              return Column(
                children: [
                  buildViewModeSelector(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SheepSpacing.page,
                        0,
                        SheepSpacing.page,
                        24,
                      ),
                      child: SheepCard(
                        padding: const EdgeInsets.all(16),
                        child: galleryTxs.isEmpty
                            ? Stack(
                                children: [
                                  SheepEmptyState(
                                    message: isSingleDay
                                        ? l10n.get('no_tx_today')
                                        : l10n.get('no_tx_range'),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: buildTypeFilter(),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (isSingleDay) ...[
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: buildTypeFilter(),
                                            ),
                                            const SizedBox(height: 10),
                                            _buildImageGrid(
                                              galleryTxs,
                                              catBox,
                                              settings,
                                            ),
                                          ] else
                                            for (final dayKey
                                                in sortedGalleryDayKeys) ...[
                                              if (dayKey !=
                                                  sortedGalleryDayKeys.first)
                                                const SizedBox(height: 18),
                                              Row(
                                                children: [
                                                  Text(
                                                    DateFormat(
                                                      'EEEE, dd/MM/yyyy',
                                                      settings.languageCode ==
                                                              'vi'
                                                          ? 'vi_VN'
                                                          : 'en_US',
                                                    ).format(
                                                      DateTime.parse(dayKey),
                                                    ),
                                                    style:
                                                        SheepTextStyles.itemTitle(
                                                          context,
                                                        ),
                                                  ),
                                                  const Spacer(),
                                                  if (dayKey ==
                                                      sortedGalleryDayKeys
                                                          .first)
                                                    buildTypeFilter(),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              _buildImageGrid(
                                                groupedGalleryTxs[dayKey]!,
                                                catBox,
                                                settings,
                                              ),
                                            ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              );
            }

            if (displayTxs.isEmpty) {
              return Column(
                children: [
                  buildViewModeSelector(),
                  buildSummaryCard(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SheepSpacing.page,
                        12,
                        SheepSpacing.page,
                        24,
                      ),
                      child: SheepCard(
                        padding: const EdgeInsets.all(16),
                        child: Stack(
                          children: [
                            SheepEmptyState(
                              message: isSingleDay
                                  ? l10n.get('no_tx_today')
                                  : l10n.get('no_tx_range'),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: buildTypeFilter(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                buildViewModeSelector(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // --- SUMMARY CARD ---
                        buildSummaryCard(),
                        Builder(
                          builder: (context) {
                            const topGap = 12.0;
                            const bottomGap = 24.0;

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
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (
                                          var dayIdx = 0;
                                          dayIdx < sortedDayKeys.length;
                                          dayIdx++
                                        ) ...[
                                          Builder(
                                            builder: (context) {
                                              final dKey =
                                                  sortedDayKeys[dayIdx];
                                              final dayTxs = grouped[dKey]!;
                                              dayTxs.sort((a, b) {
                                                int c = b.date.compareTo(
                                                  a.date,
                                                );
                                                if (c == 0) {
                                                  return b.key
                                                      .toString()
                                                      .compareTo(
                                                        a.key.toString(),
                                                      );
                                                }
                                                return c;
                                              });

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
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
                                                        settings.languageCode ==
                                                                'vi'
                                                            ? 'vi_VN'
                                                            : 'en_US',
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
                                                              c.id ==
                                                              tx.categoryId,
                                                          orElse: () =>
                                                              CategoryModel(
                                                                id: '',
                                                                name: '?',
                                                                iconCode: Icons
                                                                    .help
                                                                    .codePoint,
                                                                isExpense: true,
                                                              ),
                                                        );
                                                    final isLastInDay =
                                                        tx == dayTxs.last;
                                                    final isLastDay =
                                                        dayIdx ==
                                                        sortedDayKeys.length -
                                                            1;
                                                    final isSavings = goalCatIds
                                                        .contains(
                                                          tx.categoryId,
                                                        );
                                                    final isExpense =
                                                        tx.isExpense;

                                                    return Dismissible(
                                                      key: ValueKey(tx.key),
                                                      direction:
                                                          DismissDirection
                                                              .endToStart,
                                                      background: Container(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 20,
                                                            ),
                                                        child: Icon(
                                                          LineIcons.trash,
                                                          color:
                                                              AppColors.expense,
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
                                                                onConfirm:
                                                                    () {},
                                                              ),
                                                        );
                                                      },
                                                      onDismissed: (_) {
                                                        tx.delete();
                                                        SheepNotifications.showSuccess(
                                                          context,
                                                          l10n.get(
                                                            'delete_success',
                                                          ),
                                                        );
                                                      },
                                                      child: SheepTransactionCard(
                                                        margin: EdgeInsets.only(
                                                          bottom:
                                                              !isLastInDay ||
                                                                  !isLastDay
                                                              ? SheepSpacing
                                                                    .itemGap
                                                              : 0,
                                                        ),
                                                        onTap: () =>
                                                            showModalBottomSheet(
                                                              context: context,
                                                              isScrollControlled:
                                                                  true,
                                                              isDismissible:
                                                                  true,
                                                              enableDrag: true,
                                                              builder: (_) =>
                                                                  TransactionForm(
                                                                    transaction:
                                                                        tx,
                                                                  ),
                                                            ),
                                                        icon: IconData(
                                                          cat.iconCode,
                                                          fontFamily:
                                                              'MaterialIcons',
                                                        ),
                                                        iconColor:
                                                            cat.colorValue !=
                                                                null
                                                            ? Color(
                                                                cat.colorValue!,
                                                              )
                                                            : AppColors.getTextPrimary(
                                                                theme
                                                                    .brightness,
                                                              ),
                                                        title: cat.name,
                                                        dateText:
                                                            tx.note.isNotEmpty
                                                            ? tx.note
                                                            : l10n.get(
                                                                'no_note',
                                                              ),
                                                        amountText:
                                                            !settings
                                                                .hideAmounts
                                                            ? '${isExpense ? '-' : '+'} ${CurrencyUtil.formatByCurrency(tx.amount, settings.currencyCode)}'
                                                            : CurrencyUtil.formatMaskedByCurrency(
                                                                settings
                                                                    .currencyCode,
                                                              ),
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
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: buildTypeFilter(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
    String locale, {
    bool isHidden = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyUtil.formatDisplayCompact(
            amount,
            isHidden: isHidden,
            locale: locale,
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildImageGrid(
    List<Transaction> transactions,
    Box<CategoryModel> catBox,
    AppSettings settings,
  ) {
    final sortedTxs = [...transactions]
      ..sort((a, b) {
        final dateComparison = b.date.compareTo(a.date);
        if (dateComparison != 0) return dateComparison;
        return b.key.toString().compareTo(a.key.toString());
      });

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: sortedTxs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final tx = sortedTxs[index];
        final cat = catBox.values.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => CategoryModel(
            id: '',
            name: '?',
            iconCode: Icons.help.codePoint,
            isExpense: tx.isExpense,
            typeIndex: tx.isExpense ? 0 : 1,
          ),
        );
        return _TransactionImageTile(
          transaction: tx,
          category: cat,
          settings: settings,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            isDismissible: true,
            enableDrag: true,
            builder: (_) => TransactionForm(transaction: tx),
          ),
        );
      },
    );
  }
}

class _TransactionImageTile extends StatelessWidget {
  final Transaction transaction;
  final CategoryModel category;
  final AppSettings settings;
  final VoidCallback onTap;

  const _TransactionImageTile({
    required this.transaction,
    required this.category,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountPrefix = category.effectiveTypeIndex == 1 ? '+' : '-';
    final amountColor = category.effectiveTypeIndex == 1
        ? AppColors.income
        : AppColors.expense;
    final amountText = settings.hideAmounts
        ? CurrencyUtil.formatMaskedByCurrency(settings.currencyCode)
        : '$amountPrefix ${CurrencyUtil.formatByCurrency(transaction.amount, settings.currencyCode)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.getBorder(theme.brightness)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (transaction.imagePath != null &&
                    transaction.imagePath!.isNotEmpty)
                  Image.file(
                    File(transaction.imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholder(),
                  )
                else
                  _buildPlaceholder(),
                if (!settings.hideAmounts)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amountText,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: amountColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                      size: 14,
                      color: category.colorValue != null
                          ? Color(category.colorValue!)
                          : Colors.white,
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

  Widget _buildPlaceholder() {
    final categoryColor = category.colorValue != null
        ? Color(category.colorValue!)
        : null;
    final gradientColors = categoryColor != null
        ? [categoryColor, categoryColor.withOpacity(0.7)]
        : switch (category.effectiveTypeIndex) {
            0 => const [Color(0xFFC62828), Color(0xFF8E24AA)],
            1 => const [Color(0xFF2E7D32), Color(0xFF00ACC1)],
            _ => const [Color(0xFF1976D2), Color(0xFF00BCD4)],
          };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(
            IconData(category.iconCode, fontFamily: 'MaterialIcons'),
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
