import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/category_icon_resolver.dart';
import '../../core/utils/currency_util.dart';
import '../../core/utils/financial_cycle_util.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/transaction_image_store.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/transaction_form.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_dialogs.dart';
import '../widgets/common/sheep_notifications.dart';
import '../../data/services/notification_service.dart';

class DiaryTab extends StatefulWidget {
  final DateTimeRange selectedRange;
  final int selectedViewMode;
  final ValueChanged<int> onViewModeChanged;

  const DiaryTab({
    super.key,
    required this.selectedRange,
    required this.selectedViewMode,
    required this.onViewModeChanged,
  });

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  Set<int> _selectedListTypeIndexes = {}; // empty means all
  Set<int> _selectedTimelineTypeIndexes = {}; // empty means all
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
            final effectiveViewMode = widget.selectedViewMode == 3 ? 3 : 1;

            final isSingleDay =
                widget.selectedRange.start.year ==
                    widget.selectedRange.end.year &&
                widget.selectedRange.start.month ==
                    widget.selectedRange.end.month &&
                widget.selectedRange.start.day == widget.selectedRange.end.day;

            // 2. Keep the summary tied to the selected date range only.
            final rangeTxs = box.values.cast<Transaction>().where((tx) {
              return tx.date.isAfter(
                    widget.selectedRange.start.subtract(
                      const Duration(seconds: 1),
                    ),
                  ) &&
                  tx.date.isBefore(
                    widget.selectedRange.end.add(const Duration(seconds: 1)),
                  );
            }).toList();

            List<Transaction> filterTransactions(Set<int> selectedTypeIndexes) {
              return rangeTxs.where((tx) {
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
                return selectedTypeIndexes.isEmpty ||
                    selectedTypeIndexes.contains(cat.effectiveTypeIndex);
              }).toList();
            }

            // 3. Apply each content filter only to its own tab.
            final displayTxs = filterTransactions(_selectedListTypeIndexes);
            final timelineTxs = filterTransactions(
              _selectedTimelineTypeIndexes,
            );

            // 4. Group by date
            Map<String, List<Transaction>> grouped = {};
            for (var tx in displayTxs) {
              final dayKey = DateFormat('yyyy-MM-dd').format(tx.date);
              if (grouped[dayKey] == null) grouped[dayKey] = [];
              grouped[dayKey]!.add(tx);
            }

            final sortedDayKeys = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            Widget buildViewModeSelector() {
              final options = [
                (1, l10n.get('list_view')),
                (3, l10n.get('timeline')),
              ];

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  SheepSpacing.page,
                  12,
                  SheepSpacing.page,
                  12,
                ),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.getSubtleSurface(theme.brightness),
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                    border: Border.all(
                      color: AppColors.getBorder(theme.brightness),
                    ),
                  ),
                  child: Row(
                    children: options.map((option) {
                      final isSelected = effectiveViewMode == option.$1;
                      final accent = AppColors.getInteractiveAccent(
                        theme.brightness,
                        theme.colorScheme.primary,
                      );
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(SheepRadius.sm),
                            onTap: () => widget.onViewModeChanged(option.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  SheepRadius.sm,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      option.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.getOnAccent(
                                                theme.brightness,
                                                accent,
                                              )
                                            : AppColors.getTextPrimary(
                                                theme.brightness,
                                              ),
                                        fontSize: SheepTypeScale.meta,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
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
                    }).toList(),
                  ),
                ),
              );
            }

            Widget buildTypeFilter({bool compactWhenAll = false}) {
              final labels = [
                l10n.get('expense'),
                l10n.get('income'),
                l10n.get('savings'),
              ];
              final selectedTypeIndexes = switch (effectiveViewMode) {
                1 => _selectedListTypeIndexes,
                3 => _selectedTimelineTypeIndexes,
                _ => _selectedListTypeIndexes,
              };
              const isCompactAllState = false;

              void updateSelectedTypeIndexes(Set<int> nextIndexes) {
                final normalized = nextIndexes.length >= labels.length
                    ? <int>{}
                    : nextIndexes;
                setState(() {
                  switch (effectiveViewMode) {
                    case 1:
                      _selectedListTypeIndexes = normalized;
                      break;
                    case 3:
                      _selectedTimelineTypeIndexes = normalized;
                      break;
                    default:
                      _selectedListTypeIndexes = normalized;
                  }
                });
              }

              String selectedLabel() {
                if (selectedTypeIndexes.isEmpty) return l10n.get('all');
                final sortedIndexes = selectedTypeIndexes.toList()..sort();
                return sortedIndexes.map((index) => labels[index]).join(', ');
              }

              return PopupMenuTheme(
                data: PopupMenuThemeData(
                  color: AppColors.getSurface(theme.brightness),
                  surfaceTintColor: Colors.transparent,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: AppColors.getBorder(theme.brightness),
                    ),
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                  ),
                ),
                child: PopupMenuButton<int>(
                  constraints: const BoxConstraints.tightFor(width: 168),
                  offset: const Offset(0, 38),
                  menuPadding: EdgeInsets.zero,
                  padding: const EdgeInsets.all(4),
                  itemBuilder: (context) {
                    var menuSelectedTypeIndexes = <int>{...selectedTypeIndexes};
                    final indexes = [
                      -1,
                      ...List<int>.generate(labels.length, (index) => index),
                    ];
                    return [
                      PopupMenuItem<int>(
                        enabled: false,
                        padding: EdgeInsets.zero,
                        child: StatefulBuilder(
                          builder: (context, menuSetState) {
                            return SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: indexes.map((index) {
                                    final isSelected = index == -1
                                        ? menuSelectedTypeIndexes.isEmpty
                                        : menuSelectedTypeIndexes.contains(
                                            index,
                                          );
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(
                                        SheepRadius.sm,
                                      ),
                                      onTap: () {
                                        final nextIndexes = <int>{
                                          ...menuSelectedTypeIndexes,
                                        };
                                        if (index == -1) {
                                          nextIndexes.clear();
                                        } else if (nextIndexes.contains(
                                          index,
                                        )) {
                                          nextIndexes.remove(index);
                                        } else {
                                          nextIndexes.add(index);
                                        }
                                        menuSelectedTypeIndexes =
                                            nextIndexes.length >= labels.length
                                            ? <int>{}
                                            : nextIndexes;
                                        updateSelectedTypeIndexes(
                                          menuSelectedTypeIndexes,
                                        );
                                        menuSetState(() {});
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              index == -1
                                                  ? l10n.get('all')
                                                  : labels[index],
                                              style:
                                                  SheepTextStyles.itemMeta(
                                                    context,
                                                  ).copyWith(
                                                    color:
                                                        AppColors.getTextPrimary(
                                                          theme.brightness,
                                                        ),
                                                    fontSize:
                                                        SheepTypeScale.label,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                              )
                                            else
                                              const SizedBox(width: 16),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ];
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(theme.brightness),
                      borderRadius: BorderRadius.circular(SheepRadius.sm),
                      border: Border.all(
                        color: AppColors.getBorder(theme.brightness),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tune_rounded, size: 14),
                        if (!isCompactAllState) ...[
                          const SizedBox(width: 6),
                          Text(
                            selectedLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SheepTextStyles.itemMeta(context).copyWith(
                              color: AppColors.getTextPrimary(theme.brightness),
                              fontSize: SheepTypeScale.meta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            Widget buildContentHeader(int count) {
              return Row(
                children: [
                  Text(
                    l10n
                        .get('num_transactions')
                        .replaceAll('{count}', '$count'),
                    style: SheepTextStyles.itemTitle(context),
                  ),
                  const Spacer(),
                  buildTypeFilter(compactWhenAll: true),
                ],
              );
            }

            if (effectiveViewMode == 3) {
              return Column(
                children: [
                  buildViewModeSelector(),
                  if (settings.showAvailableBalance)
                    _buildRemainingBalanceCard(context, settings),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SheepSpacing.page,
                      0,
                      SheepSpacing.page,
                      12,
                    ),
                    child: buildContentHeader(timelineTxs.length),
                  ),
                  Expanded(
                    child: _buildTimelineCalendar(
                      context,
                      timelineTxs,
                      catBox,
                      settings,
                    ),
                  ),
                ],
              );
            }

            if (displayTxs.isEmpty) {
              return Column(
                children: [
                  buildViewModeSelector(),
                  if (settings.showAvailableBalance)
                    _buildRemainingBalanceCard(context, settings),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildContentHeader(displayTxs.length),
                            Expanded(
                              child: SheepEmptyState(
                                message: isSingleDay
                                    ? l10n.get('no_tx_today')
                                    : l10n.get('no_tx_range'),
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

            return Column(
              children: [
                buildViewModeSelector(),
                if (settings.showAvailableBalance)
                  _buildRemainingBalanceCard(context, settings),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    buildContentHeader(displayTxs.length),
                                    const SizedBox(height: 8),
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
                                                      SheepTextStyles.dateHeader(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                              ...dayTxs.map((tx) {
                                                final cat = catBox.values
                                                    .firstWhere(
                                                      (c) =>
                                                          c.id == tx.categoryId,
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
                                                    sortedDayKeys.length - 1;
                                                final typeVisuals =
                                                    SheepTransactionTypeVisuals.fromTypeIndex(
                                                      cat.effectiveTypeIndex,
                                                    );
                                                final catColor =
                                                    cat.colorValue != null
                                                    ? Color(cat.colorValue!)
                                                    : AppColors.getTextPrimary(
                                                        theme.brightness,
                                                      );

                                                return Dismissible(
                                                  key: ValueKey(tx.key),
                                                  direction: DismissDirection
                                                      .endToStart,
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
                                                    NotificationService.checkDailyReminderReschedule();
                                                    SheepNotifications.showSuccess(
                                                      context,
                                                      l10n.get(
                                                        'delete_success',
                                                      ),
                                                    );
                                                  },
                                                  child: SheepTransactionCard(
                                                    margin: EdgeInsets.only(
                                                      bottom: !isLastInDay
                                                          ? 8.0
                                                          : (!isLastDay
                                                              ? SheepSpacing.itemGap
                                                              : 0.0),
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
                                                    icon: resolveCategoryIcon(
                                                      cat.iconCode,
                                                    ),
                                                    iconColor: catColor,
                                                    iconImagePath:
                                                        cat.imagePath,
                                                    title: cat.name,
                                                    dateText: tx.note,
                                                    amountText:
                                                        !settings.hideAmounts
                                                        ? '${cat.effectiveTypeIndex == 0
                                                              ? '-'
                                                              : cat.effectiveTypeIndex == 2
                                                              ? ''
                                                              : '+'}${cat.effectiveTypeIndex == 2 ? '' : ' '}${CurrencyUtil.formatByCurrency(tx.amount, settings.currencyCode)}'
                                                        : CurrencyUtil.formatMaskedByCurrency(
                                                            settings
                                                                .currencyCode,
                                                          ),
                                                    amountColor:
                                                        typeVisuals.color,
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
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineCalendar(
    BuildContext context,
    List<Transaction> transactions,
    Box<CategoryModel> catBox,
    AppSettings settings,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).toString();
    final month = DateTime(
      widget.selectedRange.start.year,
      widget.selectedRange.start.month,
    );
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingDays = _calendarLeadingDays(
      firstDay.weekday,
      settings.weekStartDay,
    );
    final cellCount = leadingDays + daysInMonth;
    final trailingDays = (7 - (cellCount % 7)) % 7;
    final totalCells = cellCount + trailingDays;
    final grouped = <String, List<Transaction>>{};

    for (final tx in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final calendarBackground = isDark
        ? const Color(0xFF1E1D23)
        : const Color(0xFFF4F0EA);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SheepSpacing.page,
          12,
          SheepSpacing.page,
          24,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
          decoration: BoxDecoration(
            color: calendarBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.getBorder(
                theme.brightness,
              ).withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: _weekdayLabels(settings.weekStartDay, locale)
                    .map(
                      (label) => Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: SheepTextStyles.itemMeta(context).copyWith(
                            color: AppColors.getTextSecondary(
                              theme.brightness,
                            ).withValues(alpha: 0.74),
                            fontSize: SheepTypeScale.label,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.64,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - leadingDays + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final date = DateTime(month.year, month.month, dayNumber);
                  final key = DateFormat('yyyy-MM-dd').format(date);
                  return _buildTimelineDayCell(
                    context,
                    date,
                    grouped[key] ?? const [],
                    catBox,
                    settings,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineDayCell(
    BuildContext context,
    DateTime date,
    List<Transaction> dayTxs,
    Box<CategoryModel> catBox,
    AppSettings settings,
  ) {
    final theme = Theme.of(context);
    final hasTx = dayTxs.isNotEmpty;
    double income = 0;
    double expense = 0;

    for (final tx in dayTxs) {
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
      if (cat.effectiveTypeIndex == 0) {
        expense += tx.amount;
      } else if (cat.effectiveTypeIndex == 1) {
        income += tx.amount;
      }
    }

    final borderColor = _timelineBorderColor(
      income: income,
      expense: expense,
      fallback: AppColors.getBorder(theme.brightness),
    );

    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              _showTimelineDayGallery(context, date, dayTxs, catBox, settings),
          child: Column(
            children: [
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: hasTx
                        ? (theme.brightness == Brightness.dark
                              ? const Color(0xFF292830)
                              : const Color(0xFFF9F7F4))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildTimelineImageStack(
                    context,
                    dayTxs,
                    catBox,
                    borderColor: borderColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                textAlign: TextAlign.center,
                style: SheepTextStyles.itemTitle(context).copyWith(
                  color: isToday
                      ? theme.primaryColor
                      : AppColors.getTextPrimary(
                          theme.brightness,
                        ).withValues(alpha: hasTx ? 0.94 : 0.42),
                  fontSize: isToday ? SheepTypeScale.micro + 1 : SheepTypeScale.micro,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTimelineDayGallery(
    BuildContext context,
    DateTime date,
    List<Transaction> dayTxs,
    Box<CategoryModel> catBox,
    AppSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          final theme = Theme.of(context);
          final locale = settings.languageCode == 'vi' ? 'vi_VN' : 'en_US';
          return Container(
            decoration: BoxDecoration(
              color: AppColors.getSurface(theme.brightness),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SheepRadius.sheet),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SheepSpacing.page,
                SheepSpacing.lg,
                SheepSpacing.page,
                SheepSpacing.page,
              ),
              child: SheepCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, dd/MM/yyyy', locale).format(date),
                            style: SheepTextStyles.dateHeader(context),
                          ),
                        ),
                        Text(
                          L10n.of(context).get(
                            'num_transactions',
                            params: {'count': dayTxs.length.toString()},
                          ),
                          style: SheepTextStyles.itemMeta(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        physics: const BouncingScrollPhysics(),
                        child: dayTxs.isEmpty
                            ? SheepEmptyState(
                                message: L10n.of(context).get('no_tx_today'),
                              )
                            : _buildImageGrid(dayTxs, catBox, settings),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineImageStack(
    BuildContext context,
    List<Transaction> dayTxs,
    Box<CategoryModel> catBox, {
    required Color borderColor,
  }) {
    final theme = Theme.of(context);
    final imageTxs = List<Transaction>.from(dayTxs)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (imageTxs.isEmpty) {
      return Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.getTextSecondary(theme.brightness).withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.16,
            ),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    final visibleTxs = imageTxs.take(2).toList().reversed.toList();
    final extraCount = imageTxs.length - visibleTxs.length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < visibleTxs.length; i++)
          Positioned.fill(
            left: visibleTxs.length == 1 ? 0 : (i == 0 ? -3 : 5),
            top: visibleTxs.length == 1 ? 0 : (i == 0 ? -3 : 5),
            right: visibleTxs.length == 1 ? 0 : (i == 0 ? 5 : -3),
            bottom: visibleTxs.length == 1 ? 0 : (i == 0 ? 5 : -3),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _timelineImageBorderColor(
                    visibleTxs[i],
                    catBox,
                    borderColor,
                  ),
                  width: 2.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _timelineImageBorderColor(
                      visibleTxs[i],
                      catBox,
                      borderColor,
                    ).withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Builder(
                  builder: (context) {
                    final imageFile = TransactionImageStore.resolve(visibleTxs[i].imagePath);
                    final hasImage = imageFile != null && imageFile.existsSync();
                    if (hasImage) {
                      return Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildCategoryPlaceholderForTimeline(visibleTxs[i], catBox),
                      );
                    } else {
                      return _buildCategoryPlaceholderForTimeline(visibleTxs[i], catBox);
                    }
                  },
                ),
              ),
            ),
          ),
        if (extraCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(SheepRadius.pill),
                border: Border.all(
                  color: Colors.black12,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                extraCount > 9 ? '+9' : '+$extraCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryPlaceholderForTimeline(Transaction tx, Box<CategoryModel> catBox) {
    final category = catBox.values.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => CategoryModel(
        id: '',
        name: '?',
        iconCode: Icons.help.codePoint,
        isExpense: tx.isExpense,
        typeIndex: tx.isExpense ? 0 : 1,
      ),
    );

    final Color categoryColor = category.colorValue != null
        ? Color(category.colorValue!)
        : (category.effectiveTypeIndex == 0
            ? AppColors.expense
            : (category.effectiveTypeIndex == 1
                ? AppColors.income
                : AppColors.savings));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor,
            categoryColor.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Center(
        child: SheepCategoryIcon(
          icon: category.iconData,
          color: Colors.white,
          size: 20,
          imagePath: category.imagePath,
          backgroundColor: Colors.transparent,
          borderColor: Colors.transparent,
        ),
      ),
    );
  }

  Color _timelineImageBorderColor(
    Transaction tx,
    Box<CategoryModel> catBox,
    Color fallback,
  ) {
    final category = catBox.values.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => CategoryModel(
        id: '',
        name: '?',
        iconCode: Icons.help.codePoint,
        isExpense: tx.isExpense,
        typeIndex: tx.isExpense ? 0 : 1,
      ),
    );
    return category.effectiveTypeIndex == 2 ? AppColors.savings : fallback;
  }

  Color _timelineBorderColor({
    required double income,
    required double expense,
    required Color fallback,
  }) {
    if (income <= 0 && expense <= 0) return fallback;
    if (income <= 0 && expense > 0) return AppColors.expense;
    if (expense <= 0 && income > 0) return AppColors.income;

    final ratio = expense / income;
    if (ratio >= 1) return AppColors.expense;
    if (ratio >= 0.8) return const Color(0xFFFF9E3D);
    if (ratio >= 0.6) return const Color(0xFFFFD166);
    return const Color(0xFFA6D854);
  }

  int _calendarLeadingDays(int firstWeekday, int weekStartDay) {
    return (firstWeekday - weekStartDay + 7) % 7;
  }

  List<String> _weekdayLabels(int weekStartDay, String locale) {
    final labels = locale.startsWith('vi')
        ? const {
            DateTime.monday: 'T2',
            DateTime.tuesday: 'T3',
            DateTime.wednesday: 'T4',
            DateTime.thursday: 'T5',
            DateTime.friday: 'T6',
            DateTime.saturday: 'T7',
            DateTime.sunday: 'CN',
          }
        : const {
            DateTime.monday: 'Mon',
            DateTime.tuesday: 'Tue',
            DateTime.wednesday: 'Wed',
            DateTime.thursday: 'Thu',
            DateTime.friday: 'Fri',
            DateTime.saturday: 'Sat',
            DateTime.sunday: 'Sun',
          };

    return List.generate(7, (index) {
      final weekday = ((weekStartDay - 1 + index) % 7) + 1;
      return labels[weekday]!;
    });
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
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
        childAspectRatio: 1,
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
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              isDismissible: true,
              enableDrag: true,
              builder: (_) => TransactionForm(
                transaction: tx,
                dayTransactions: transactions,
              ),
            );
          },
        );
      },
    );
  }

  double _calculateRemainingBalance(AppSettings settings, List<Transaction> transactions) {
    final catBox = Hive.box<CategoryModel>(kCatBox);
    final categoriesById = {
      for (final cat in catBox.values) cat.id: cat,
    };

    final now = DateTime.now();
    final currentRange = FinancialCycleUtil.cycleRangeFor(
      now,
      settings.financialCycleStartDay,
    );

    double currentIncome = 0;
    double currentExpense = 0;
    double currentSavings = 0;
    double previousBalance = 0;

    for (final tx in transactions) {
      final cat = categoriesById[tx.categoryId];
      final effectiveType = cat?.effectiveTypeIndex ?? (tx.isExpense ? 0 : 1);

      // Check if transaction is in current cycle
      final inCurrentCycle = FinancialCycleUtil.isInRange(tx.date, currentRange);

      if (inCurrentCycle) {
        if (effectiveType == 1) {
          currentIncome += tx.amount;
        } else if (effectiveType == 0) {
          currentExpense += tx.amount;
        } else if (effectiveType == 2) {
          currentSavings += tx.amount;
        }
      } else if (tx.date.isBefore(currentRange.start)) {
        // Transaction is in previous cycle
        if (settings.accumulateBalance) {
          if (effectiveType == 1) {
            previousBalance += tx.amount;
          } else if (effectiveType == 0) {
            previousBalance -= tx.amount;
          } else if (effectiveType == 2) {
            previousBalance -= tx.amount;
          }
        }
      }
    }

    if (settings.accumulateBalance) {
      double totalInitialSavings = 0;
      for (final cat in catBox.values) {
        if (cat.effectiveTypeIndex == 2) {
          totalInitialSavings += cat.initialAmount ?? 0;
        }
      }
      previousBalance -= totalInitialSavings;
    }

    return currentIncome + previousBalance - currentExpense - currentSavings;
  }

  bool _isBalanceLow(AppSettings settings, List<Transaction> transactions) {
    final catBox = Hive.box<CategoryModel>(kCatBox);
    final categoriesById = {
      for (final cat in catBox.values) cat.id: cat,
    };

    final now = DateTime.now();
    final currentRange = FinancialCycleUtil.cycleRangeFor(
      now,
      settings.financialCycleStartDay,
    );

    double currentIncome = 0;
    double currentExpense = 0;
    double currentSavings = 0;
    double previousBalance = 0;

    for (final tx in transactions) {
      final cat = categoriesById[tx.categoryId];
      final effectiveType = cat?.effectiveTypeIndex ?? (tx.isExpense ? 0 : 1);

      // Check if transaction is in current cycle
      final inCurrentCycle = FinancialCycleUtil.isInRange(tx.date, currentRange);

      if (inCurrentCycle) {
        if (effectiveType == 1) {
          currentIncome += tx.amount;
        } else if (effectiveType == 0) {
          currentExpense += tx.amount;
        } else if (effectiveType == 2) {
          currentSavings += tx.amount;
        }
      } else if (tx.date.isBefore(currentRange.start)) {
        // Transaction is in previous cycle
        if (settings.accumulateBalance) {
          if (effectiveType == 1) {
            previousBalance += tx.amount;
          } else if (effectiveType == 0) {
            previousBalance -= tx.amount;
          } else if (effectiveType == 2) {
            previousBalance -= tx.amount;
          }
        }
      }
    }

    if (settings.accumulateBalance) {
      double totalInitialSavings = 0;
      for (final cat in catBox.values) {
        if (cat.effectiveTypeIndex == 2) {
          totalInitialSavings += cat.initialAmount ?? 0;
        }
      }
      previousBalance -= totalInitialSavings;
    }

    final balance = currentIncome + previousBalance - currentExpense - currentSavings;
    final totalIncomePool = currentIncome + previousBalance;

    if (totalIncomePool <= 0) {
      return balance <= 0;
    }

    return balance <= 0.1 * totalIncomePool;
  }

  Widget _buildRemainingBalanceCard(BuildContext context, AppSettings settings) {
    final transactions = Hive.box<Transaction>(kMoneyBox).values.toList();
    final balance = _calculateRemainingBalance(settings, transactions);
    final theme = Theme.of(context);
    final isLow = _isBalanceLow(settings, transactions);

    final title = settings.languageCode == 'vi' ? 'Số dư khả dụng' : 'Available Balance';
    final amountText = CurrencyUtil.formatDisplayAmount(
      balance,
      settings.currencyCode,
      isHidden: settings.hideAmounts,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(SheepSpacing.page, 0, SheepSpacing.page, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLow
              ? AppColors.expense.withValues(alpha: 0.1)
              : theme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(SheepRadius.xl),
          border: Border.all(
            color: isLow
                ? AppColors.expense.withValues(alpha: 0.3)
                : theme.primaryColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLow
                    ? AppColors.expense.withValues(alpha: 0.15)
                    : theme.primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLow ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
                color: isLow ? AppColors.expense : theme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextSecondary(theme.brightness),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isLow ? AppColors.expense : AppColors.getTextPrimary(theme.brightness),
                    ),
                  ),
                ],
              ),
            ),
            if (isLow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.expense,
                  borderRadius: BorderRadius.circular(SheepRadius.sm),
                ),
                child: Text(
                  settings.languageCode == 'vi' ? 'Sắp hết' : 'Running Low',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
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
    final typeIndex = category.effectiveTypeIndex;
    final amountPrefix = typeIndex == 0
        ? '-'
        : typeIndex == 1
        ? '+'
        : '';
    final amountColor = typeIndex == 2
        ? AppColors.savings
        : typeIndex == 1
        ? AppColors.income
        : AppColors.expense;
    final amountText = settings.hideAmounts
        ? CurrencyUtil.formatMaskedByCurrency(settings.currencyCode)
        : '$amountPrefix ${CurrencyUtil.formatByCurrency(transaction.amount, settings.currencyCode)}';
    final imageFile = TransactionImageStore.resolve(transaction.imagePath);
    final hasImage = imageFile?.existsSync() ?? false;
    const radius = 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.getBorder(theme.brightness)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  Image.file(
                    imageFile!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholder(theme),
                  )
                else
                  _buildPlaceholder(theme),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 104),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      amountText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1,
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
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: SheepCategoryIcon(
                      icon: category.iconData,
                      color: category.colorValue != null
                          ? Color(category.colorValue!)
                          : Colors.white,
                      size: 24,
                      imagePath: category.imagePath,
                      backgroundColor: Colors.transparent,
                      borderColor: Colors.transparent,
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

  Widget _buildPlaceholder(ThemeData theme) {
    final Color categoryColor = category.colorValue != null
        ? Color(category.colorValue!)
        : (category.effectiveTypeIndex == 0
            ? AppColors.expense
            : (category.effectiveTypeIndex == 1
                ? AppColors.income
                : AppColors.savings));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor,
            categoryColor.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Center(
        child: SheepCategoryIcon(
          icon: category.iconData,
          color: Colors.white,
          size: 40,
          imagePath: category.imagePath,
          backgroundColor: Colors.transparent,
          borderColor: Colors.transparent,
        ),
      ),
    );
  }
}
