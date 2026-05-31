import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/currency_util.dart';
import '../../core/utils/transaction_image_store.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../widgets/transaction_form.dart';
import '../../core/theme/app_colors.dart';
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
  int _selectedViewMode = 1; // 1: list, 2: image
  int? _selectedListTypeIndex; // null means all
  int? _selectedGalleryTypeIndex; // null means all
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

            List<Transaction> filterTransactions(int? selectedTypeIndex) {
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
                return selectedTypeIndex == null ||
                    cat.effectiveTypeIndex == selectedTypeIndex;
              }).toList();
            }

            // 3. Apply each content filter only to its own tab.
            final displayTxs = filterTransactions(_selectedListTypeIndex);
            final galleryTxs = filterTransactions(_selectedGalleryTypeIndex);

            // 4. Group by date
            Map<String, List<Transaction>> grouped = {};
            for (var tx in displayTxs) {
              final dayKey = DateFormat('yyyy-MM-dd').format(tx.date);
              if (grouped[dayKey] == null) grouped[dayKey] = [];
              grouped[dayKey]!.add(tx);
            }

            final sortedDayKeys = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));
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
                child: SheepTypeToggle(
                  isExpense: _selectedViewMode == 1,
                  leftLabel: l10n.get('list_view'),
                  rightLabel: l10n.get('image_view'),
                  onChanged: (isList) =>
                      setState(() => _selectedViewMode = isList ? 1 : 2),
                ),
              );
            }

            Widget buildTypeFilter({bool compactWhenAll = false}) {
              final labels = [
                l10n.get('expense'),
                l10n.get('income'),
                l10n.get('savings'),
              ];
              final selectedTypeIndex = _selectedViewMode == 1
                  ? _selectedListTypeIndex
                  : _selectedGalleryTypeIndex;
              final isCompactAllState =
                  compactWhenAll && selectedTypeIndex == null;

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
                  initialValue: selectedTypeIndex,
                  onSelected: (index) => setState(() {
                    if (_selectedViewMode == 1) {
                      _selectedListTypeIndex = _selectedListTypeIndex == index
                          ? null
                          : index;
                    } else {
                      _selectedGalleryTypeIndex =
                          _selectedGalleryTypeIndex == index ? null : index;
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
                                fontSize: SheepTypeScale.label,
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
                            selectedTypeIndex == null
                                ? l10n.get('all')
                                : labels[selectedTypeIndex],
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
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildContentHeader(galleryTxs.length),
                                  Expanded(
                                    child: SheepEmptyState(
                                      message: isSingleDay
                                          ? l10n.get('no_tx_today')
                                          : l10n.get('no_tx_range'),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildContentHeader(galleryTxs.length),
                                  const SizedBox(height: 14),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (isSingleDay) ...[
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
                                                final isSavings =
                                                    cat.effectiveTypeIndex == 2;
                                                final isExpense =
                                                    cat.effectiveTypeIndex == 0;

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
                                                      fontFamily:
                                                          'MaterialIcons',
                                                    ),
                                                    iconColor:
                                                        cat.colorValue != null
                                                        ? Color(cat.colorValue!)
                                                        : AppColors.getTextPrimary(
                                                            theme.brightness,
                                                          ),
                                                    title: cat.name,
                                                    dateText: tx.note.isNotEmpty
                                                        ? tx.note
                                                        : l10n.get('no_note'),
                                                    amountText:
                                                        !settings.hideAmounts
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
    final imageFile = TransactionImageStore.resolve(transaction.imagePath);
    final hasImage = imageFile?.existsSync() ?? false;

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
                if (hasImage)
                  Image.file(
                    imageFile!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholder(theme),
                  )
                else
                  _buildPlaceholder(theme),
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

  Widget _buildPlaceholder(ThemeData theme) {
    final placeholderBackground = theme.brightness == Brightness.dark
        ? const Color(0xFF252525)
        : const Color(0xFFF1F2F4);

    return DecoratedBox(
      decoration: BoxDecoration(color: placeholderBackground),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.getBorder(theme.brightness).withOpacity(0.52),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.image_outlined, size: 26, color: theme.hintColor),
        ),
      ),
    );
  }
}
