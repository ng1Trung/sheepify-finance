import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/category_model.dart';
import '../../../data/services/bank_inbox_service.dart';
import '../../../data/services/payment_prefs_service.dart';
import '../common/sheep_kit.dart';
import '../common/sheep_notifications.dart';
import '../common/sheep_widgets.dart';
import '../transaction/transaction_category_picker.dart';

/// "Ngân hàng vừa báo…" — bank alerts waiting to be logged. Each one is a
/// category tap plus "Ghi sổ", so paying straight from a bank app costs the
/// user a couple of taps instead of typing it all in at night.
class BankInboxSheet {
  static bool _isShowing = false;

  static Future<void> show(BuildContext context) async {
    if (_isShowing || BankInboxService.items().isEmpty) return;
    _isShowing = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _InboxBody(hostContext: context),
      );
    } finally {
      _isShowing = false;
    }
  }
}

class _InboxBody extends StatefulWidget {
  final BuildContext hostContext;

  const _InboxBody({required this.hostContext});

  @override
  State<_InboxBody> createState() => _InboxBodyState();
}

class _InboxBodyState extends State<_InboxBody> {
  late List<BankInboxItem> _items;
  final Map<String, String> _chosenCategory = {};
  final _catBox = Hive.box<CategoryModel>(kCatBox);
  int _recorded = 0;

  @override
  void initState() {
    super.initState();
    _items = BankInboxService.items();
  }

  List<CategoryModel> _quickCategories(bool isExpense) {
    final ids = PaymentPrefsService.frequentCategoryIds(isExpense: isExpense);
    final cats = ids
        .map((id) => _catBox.values.where((c) => c.id == id).firstOrNull)
        .whereType<CategoryModel>()
        .toList();
    if (cats.length < 3) {
      // New users: fill up with the first categories of that kind.
      for (final c in _catBox.values) {
        if (cats.length >= 4) break;
        if (c.effectiveTypeIndex == (isExpense ? 0 : 1) && !cats.contains(c)) {
          cats.add(c);
        }
      }
    }
    return cats;
  }

  void _pickOther(BankInboxItem item) {
    final categories = _catBox.values
        .where((c) => c.effectiveTypeIndex == (item.isExpense ? 0 : 1))
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => TransactionCategoryPicker(
        categories: categories,
        selectedCategoryId: _chosenCategory[item.id],
        onCategorySelected: (id) {
          setState(() => _chosenCategory[item.id] = id);
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  Future<void> _record(BankInboxItem item) async {
    final categoryId = _chosenCategory[item.id];
    if (categoryId == null) return;
    HapticFeedback.lightImpact();
    await BankInboxService.record(item, categoryId: categoryId);
    _recorded++;
    _remove(item);
  }

  Future<void> _dismiss(BankInboxItem item) async {
    await BankInboxService.dismiss(item);
    _remove(item);
  }

  void _remove(BankInboxItem item) {
    setState(() => _items.removeWhere((i) => i.id == item.id));
    if (_items.isEmpty) {
      Navigator.pop(context);
      if (_recorded > 0 && widget.hostContext.mounted) {
        SheepNotifications.showSuccess(
          widget.hostContext,
          'Đã ghi sổ $_recorded giao dịch',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SheepSpacing.page,
          SheepSpacing.md,
          SheepSpacing.page,
          SheepSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheepDragHandle()),
            const SizedBox(height: SheepSpacing.lg),
            Text(
              'Ngân hàng vừa báo ${_items.length} giao dịch',
              textAlign: TextAlign.center,
              style: SheepTextStyles.sheetTitle(context),
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn danh mục rồi ghi sổ, hoặc bỏ qua nếu đã ghi rồi.',
              textAlign: TextAlign.center,
              style: SheepTextStyles.itemMeta(context),
            ),
            const SizedBox(height: SheepSpacing.lg),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: SheepSpacing.md),
                itemBuilder: (_, i) => _buildItem(_items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BankInboxItem item) {
    final brightness = Theme.of(context).brightness;
    final chosen = _chosenCategory[item.id];
    final quick = _quickCategories(item.isExpense);
    final chosenCat = chosen == null
        ? null
        : _catBox.values.where((c) => c.id == chosen).firstOrNull;
    final showChosenSeparately =
        chosenCat != null && !quick.any((c) => c.id == chosenCat.id);
    final sign = item.isExpense ? '−' : '+';
    final color = item.isExpense ? AppColors.expense : AppColors.income;
    final meta = [
      if (item.appName.isNotEmpty) item.appName,
      DateFormat('HH:mm · dd/MM').format(item.time),
    ].join(' · ');

    Widget chip(CategoryModel cat) {
      final selected = chosen == cat.id;
      return SheepChip(
        label: cat.name,
        selected: selected,
        leading: Icon(
          cat.iconData,
          size: 16,
          color: selected
              ? AppColors.getOnPrimaryFill(brightness)
              : Color(cat.colorValue ?? color.toARGB32()),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _chosenCategory[item.id] = cat.id);
        },
      );
    }

    return SheepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.note.isNotEmpty ? item.note : 'Không có nội dung',
                      style: SheepTextStyles.itemTitle(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(meta, style: SheepTextStyles.itemMeta(context)),
                  ],
                ),
              ),
              const SizedBox(width: SheepSpacing.sm),
              Text(
                '$sign${CurrencyUtil.formatMoney(item.amount, locale: 'vi_VN')}₫',
                style: SheepTextStyles.amount(context, color: color),
              ),
            ],
          ),
          const SizedBox(height: SheepSpacing.md),
          Wrap(
            spacing: SheepSpacing.sm,
            runSpacing: SheepSpacing.sm,
            children: [
              for (final cat in quick) chip(cat),
              if (showChosenSeparately) chip(chosenCat),
              SheepChip(
                label: 'Khác',
                leading: Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: AppColors.getTextSecondary(brightness),
                ),
                onTap: () => _pickOther(item),
              ),
            ],
          ),
          const SizedBox(height: SheepSpacing.md),
          Row(
            children: [
              Expanded(
                child: SheepButton(
                  label: 'Bỏ qua',
                  variant: SheepButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: () => _dismiss(item),
                ),
              ),
              const SizedBox(width: SheepSpacing.sm),
              Expanded(
                flex: 2,
                child: SheepButton(
                  label: chosen == null ? 'Chọn danh mục' : 'Ghi sổ',
                  isFullWidth: true,
                  onPressed: chosen == null ? null : () => _record(item),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
