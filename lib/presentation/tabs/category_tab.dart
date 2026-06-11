import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/category_image_store.dart';
import '../../core/utils/category_util.dart';
import '../../core/utils/currency_util.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction.dart';
import '../widgets/category_form.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_toggles.dart';
import '../widgets/common/sheep_dialogs.dart';
import '../widgets/common/sheep_notifications.dart';
import '../../core/utils/l10n.dart';

class CategoryTab extends StatefulWidget {
  final int initialTypeIndex;
  final bool showTypeToggle;

  const CategoryTab({
    super.key,
    this.initialTypeIndex = 0,
    this.showTypeToggle = true,
  });

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  late int _selectedTypeIndex; // 0: expense, 1: income, 2: savings
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedTypeIndex = widget.initialTypeIndex;
    _pageController = PageController(initialPage: _selectedTypeIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showTypeToggle)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SheepSpacing.page,
              8,
              SheepSpacing.page,
              16,
            ),
            child: SheepTripleToggle(
              selectedIndex: _selectedTypeIndex,
              controller: _pageController,
              labels: [
                L10n.of(context).get('expense'),
                L10n.of(context).get('income'),
              ],
              onChanged: (val) {
                _pageController.animateToPage(
                  val,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              },
            ),
          ),

        Expanded(
          child: widget.showTypeToggle
              ? PageView(
                  controller: _pageController,
                  onPageChanged: (val) {
                    setState(() => _selectedTypeIndex = val);
                  },
                  children: [
                    _buildCategoryList(0), // Expense
                    _buildCategoryList(1), // Income
                  ],
                )
              : _buildCategoryList(_selectedTypeIndex),
        ),
      ],
    );
  }

  Widget _buildCategoryList(int typeIndex) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        Hive.box<CategoryModel>(kCatBox).listenable(),
        Hive.box<Transaction>(kMoneyBox).listenable(),
        Hive.box<AppSettings>(kSettingsBox).listenable(),
      ]),
      builder: (context, _) {
        final l10n = L10n.of(context);
        final box = Hive.box<CategoryModel>(kCatBox);
        final now = DateTime.now();

        final categories = box.values
            .where((c) => c.effectiveTypeIndex == typeIndex)
            .toList();

        if (categories.isEmpty) {
          return _buildEmptyState(context, typeIndex);
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: widget.showTypeToggle ? 0 : SheepSpacing.lg,
            bottom: 120,
            left: SheepSpacing.page,
            right: SheepSpacing.page,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];

            final spent = CategoryUtil.calculateCategorySpent(cat, now: now);

            final bool isOverBudget =
                typeIndex == 0 && cat.budget != null && spent > cat.budget!;
            final bool isGoalDone =
                typeIndex == 2 &&
                cat.targetAmount != null &&
                spent >= cat.targetAmount!;

            return Dismissible(
              key: ValueKey(cat.id),
              direction: DismissDirection.endToStart,
              background: _buildDeleteBackground(),
              confirmDismiss: (_) => _confirmDelete(context, cat),
              onDismissed: (_) async {
                final name = cat.name;
                final imagePath = cat.imagePath;
                await cat.delete();
                await CategoryImageStore.deleteStoredRef(imagePath);
                if (!context.mounted) return;
                SheepNotifications.showSuccess(
                  context,
                  l10n.get('delete_cat_success', params: {'name': name}),
                );
              },
              child: SheepCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                color: isOverBudget
                    ? AppColors.expense.withValues(alpha: 0.05)
                    : isGoalDone
                    ? AppColors.savings.withValues(alpha: 0.05)
                    : null,
                child: InkWell(
                  onTap: () => _showCategoryForm(context, cat),
                  borderRadius: BorderRadius.circular(SheepRadius.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SheepRadius.lg),
                      border: isOverBudget
                          ? Border.all(
                              color: AppColors.expense.withValues(alpha: 0.5),
                              width: 1.5,
                            )
                          : isGoalDone
                          ? Border.all(
                              color: AppColors.savings.withValues(alpha: 0.5),
                              width: 1.5,
                            )
                          : null,
                    ),
                    padding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _buildIcon(cat, typeIndex),
                              const SizedBox(width: 15),
                              _buildInfo(cat, spent, typeIndex),
                              IconButton(
                                icon: const Icon(
                                  LineIcons.edit,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    _showCategoryForm(context, cat),
                              ),
                            ],
                          ),
                        ),
                        if (isOverBudget)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.expense,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(SheepRadius.md),
                                  bottomLeft: Radius.circular(SheepRadius.md),
                                ),
                              ),
                              child: Text(
                                l10n.overBudget.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (isGoalDone)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.savings,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(SheepRadius.md),
                                  bottomLeft: Radius.circular(SheepRadius.md),
                                ),
                              ),
                              child: Text(
                                l10n.targetAchieved.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, int typeIndex) {
    final l10n = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SheepSpacing.page,
        widget.showTypeToggle ? 0 : SheepSpacing.lg,
        SheepSpacing.page,
        24,
      ),
      child: SizedBox.expand(
        child: SheepCard(
          padding: const EdgeInsets.all(16),
          child: SheepEmptyState(
            message: typeIndex == 0
                ? l10n.get('no_cat_expense')
                : (typeIndex == 1
                      ? l10n.get('no_cat_income')
                      : l10n.get('no_cat_savings')),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(CategoryModel cat, int typeIndex) {
    Color color;
    if (typeIndex == 0) {
      color = AppColors.expense;
    } else if (typeIndex == 1) {
      color = AppColors.income;
    } else {
      color = AppColors.savings;
    }

    if (cat.colorValue != null) color = Color(cat.colorValue!);

    return SheepCategoryIcon(
      icon: cat.iconData,
      color: color,
      imagePath: cat.imagePath,
    );
  }

  Widget _buildInfo(CategoryModel cat, double spent, int typeIndex) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    bool isSavings = typeIndex == 2;
    double? target = isSavings ? cat.targetAmount : cat.budget;
    final remaining = (target ?? 0) - spent;

    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final spentStr = CurrencyUtil.formatDisplayCompact(
      spent,
      isHidden: settings.hideAmounts,
    );
    final targetStr = target != null
        ? CurrencyUtil.formatDisplayCompact(
            target,
            isHidden: settings.hideAmounts,
          )
        : '';
    final infoLabel = (target != null && target > 0)
        ? '$spentStr / $targetStr'
        : spentStr;

    String goalSubtitle = '';
    if (isSavings) {
      final goalType = cat.effectiveGoalTypeIndex;
      if (goalType == 1) {
        goalSubtitle = l10n.recurringMonthly;
      } else {
        // Goal (merged 2 and 3)
        goalSubtitle =
            '${l10n.goal} • T${cat.targetMonth ?? cat.targetDate?.month ?? ''}/${cat.targetYear ?? cat.targetDate?.year ?? ''}';
      }
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cat.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (target != null && target > 0) ...[
            const SizedBox(height: 10),
            _buildProgressBar(cat, spent, typeIndex),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    infoLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: (typeIndex == 0 && remaining < 0)
                          ? AppColors.expense
                          : (typeIndex == 2 && remaining <= 0)
                          ? AppColors.savings
                          : null,
                      fontWeight: (remaining <= 0) ? FontWeight.bold : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSavings)
                  Flexible(
                    flex: 5,
                    child: Text(
                      goalSubtitle,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                      textAlign: TextAlign.right,
                      // Removed ellipsis to try to show more
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(CategoryModel cat, double spent, int typeIndex) {
    double? target = typeIndex == 2 ? cat.targetAmount : cat.budget;
    double progress = (target != null && target > 0) ? (spent / target) : 0.0;
    if (progress > 1.0) progress = 1.0;
    if (progress < 0) progress = 0;

    final baseColor = cat.colorValue != null
        ? Color(cat.colorValue!)
        : (typeIndex == 2 ? AppColors.savings : AppColors.primary);
    final barColor = (typeIndex == 0 && spent > (cat.budget ?? 0))
        ? AppColors.expense
        : baseColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: barColor.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(LineIcons.trash, color: AppColors.expense),
    );
  }

  void _showCategoryForm(BuildContext context, CategoryModel? category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CategoryForm(
        category: category,
        fixedTypeIndex: widget.showTypeToggle ? null : widget.initialTypeIndex,
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, CategoryModel item) {
    final txBox = Hive.box<Transaction>(kMoneyBox);
    final relatedTxsCount = txBox.values
        .where((tx) => tx.categoryId == item.id)
        .length;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = L10n.of(context);
        final theme = Theme.of(context);
        return SheepConfirmDialog(
          title: relatedTxsCount > 0
              ? l10n.get('delete_cat_confirm')
              : l10n.get('delete_cat_simple'),
          richContent: Text(
            relatedTxsCount > 0
                ? l10n.get(
                    'delete_cat_confirm_msg',
                    params: {
                      'name': item.name,
                      'count': relatedTxsCount.toString(),
                    },
                  )
                : l10n.get(
                    'delete_cat_simple_msg',
                    params: {'name': item.name},
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          confirmLabel: relatedTxsCount > 0
              ? l10n.get('delete_cat_confirm').split('?')[0]
              : l10n.delete,
          onConfirm: () {},
        );
      },
    );
  }
}
