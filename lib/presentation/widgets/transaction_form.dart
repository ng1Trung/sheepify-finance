import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/currency_util.dart';
import 'common/sheep_widgets.dart';
import 'transaction/transaction_image_area.dart';
import 'transaction/transaction_category_picker.dart';

import 'common/sheep_notifications.dart';
import 'common/sheep_dialogs.dart';
import '../../core/utils/category_util.dart';
import '../../core/utils/transaction_image_store.dart';

class TransactionForm extends StatefulWidget {
  final Transaction? transaction;
  final DateTime? initialDate;

  const TransactionForm({super.key, this.transaction, this.initialDate});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm>
    with SingleTickerProviderStateMixin {
  static const int _noteMaxLength = 50;
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  late final AnimationController _noteShakeController;
  late final Animation<double> _noteShakeAnimation;

  late DateTime _selectedDate;
  late int _selectedTypeIndex; // 0: expense, 1: income, 2: savings

  String? _selectedCategoryId;
  String? _imagePath;
  late final double? _initialAmount;
  late final String? _initialNote;
  late final DateTime? _initialDate;
  late final int? _initialTypeIndex;
  late final String? _initialCategoryId;
  late final String? _initialImagePath;

  final _box = Hive.box<Transaction>(kMoneyBox);
  final _catBox = Hive.box<CategoryModel>(kCatBox);

  @override
  void initState() {
    super.initState();
    _noteShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _noteShakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _noteShakeController, curve: Curves.easeOut),
        );
    if (widget.transaction != null) {
      // Initialize state with existing transaction data
      final tx = widget.transaction!;
      _amountController.text = CurrencyUtil.formatNumber(tx.amount);
      _noteController.text = tx.note;
      _selectedDate = tx.date;
      _selectedTypeIndex = tx.isExpense ? 0 : 1; // Default fallback
      _selectedCategoryId = tx.categoryId;
      _imagePath = tx.imagePath;

      // Use the current monthly cycle for budget/goal checks.
      final settings =
          Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
      _amountController.text = CurrencyUtil.formatNumber(
        tx.amount,
        locale: settings.languageCode == 'vi' ? 'vi_VN' : 'en_US',
      );

      // If we can find the category, get the exact type
      try {
        final cat = _catBox.values.firstWhere((c) => c.id == tx.categoryId);
        _selectedTypeIndex = cat.effectiveTypeIndex;
      } catch (_) {}

      _initialAmount = tx.amount;
      _initialNote = tx.note;
      _initialDate = tx.date;
      _initialTypeIndex = _selectedTypeIndex;
      _initialCategoryId = tx.categoryId;
      _initialImagePath = tx.imagePath;
    } else {
      // Default state for new transaction
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTypeIndex = 0; // Default Expense
      _imagePath = null;
      _amountController.text = ''; // Start empty to show hint '0'
      _initialAmount = null;
      _initialNote = null;
      _initialDate = null;
      _initialTypeIndex = null;
      _initialCategoryId = null;
      _initialImagePath = null;
    }

    // Refresh state on each character typed to update visual feedback
    _amountController.addListener(() => setState(() {}));
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteShakeController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _shakeNoteField() {
    HapticFeedback.selectionClick();
    _noteShakeController.forward(from: 0);
  }

  bool get _hasChanges {
    if (widget.transaction == null) return true;

    return CurrencyParsing.parseAmount(_amountController.text) !=
            _initialAmount ||
        _noteController.text != _initialNote ||
        _selectedDate != _initialDate ||
        _selectedTypeIndex != _initialTypeIndex ||
        _selectedCategoryId != _initialCategoryId ||
        _imagePath != _initialImagePath;
  }

  // Select transaction date
  Future<void> _pickDate() async {
    final picked = await SheepDatePicker.show(
      context: context,
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Upload image from camera or gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _buildDragHandle(),
          _buildPickerTitle(context, l10n.uploadImage),
          ListTile(
            leading: Icon(LineIcons.camera, color: theme.primaryColor),
            title: Text(l10n.takePhoto),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(LineIcons.image, color: theme.primaryColor),
            title: Text(l10n.chooseGallery),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final storedImageRef = await TransactionImageStore.saveFromSourcePath(
          pickedFile.path,
        );
        if (mounted) {
          setState(() => _imagePath = storedImageRef);
        }
      }
    }
  }

  Future<void> _confirmRemoveImage() async {
    final l10n = L10n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => SheepConfirmDialog(
        title: 'Xoá ảnh đính kèm?',
        content: 'Ảnh giao dịch hiện tại sẽ bị xoá khỏi biểu mẫu.',
        confirmLabel: l10n.delete,
        confirmColor: AppColors.expense,
        icon: Icons.delete_outline_rounded,
        onConfirm: () {},
      ),
    );
    if (confirm == true) {
      setState(() => _imagePath = null);
    }
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(SheepRadius.sm),
      ),
    );
  }

  Widget _buildPickerTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
      ),
    );
  }

  // Validate and persist transaction data
  Future<void> _submit() async {
    final l10n = L10n.of(context);
    if (_amountController.text.isEmpty || _selectedCategoryId == null) {
      SheepNotifications.showError(context, l10n.get('error_input'));
      return;
    }

    final enteredAmount = CurrencyParsing.parseAmount(_amountController.text);
    if (enteredAmount <= 0) return;

    HapticFeedback.mediumImpact();

    try {
      if (widget.transaction != null) {
        // Update existing transaction in Hive
        final tx = widget.transaction!;
        tx.amount = enteredAmount;
        tx.note = _noteController.text;
        tx.date = _selectedDate;
        tx.isExpense = _selectedTypeIndex == 0;
        tx.categoryId = _selectedCategoryId!;
        tx.imagePath = _imagePath;
        tx.save();
        SheepNotifications.showSuccess(context, l10n.get('tx_updated'));
      } else {
        // Create and add new transaction to Hive
        final newTx = Transaction(
          note: _noteController.text,
          amount: enteredAmount,
          date: _selectedDate,
          isExpense: _selectedTypeIndex == 0,
          categoryId: _selectedCategoryId!,
          imagePath: _imagePath,
        );
        _box.add(newTx);
        SheepNotifications.showSuccess(context, l10n.get('tx_added'));
      }

      // Check if we hit budget or reached goal
      try {
        final cat = _catBox.values.firstWhere(
          (c) => c.id == _selectedCategoryId,
        );
        final spent = CategoryUtil.calculateCategorySpent(
          cat,
          now: _selectedDate,
        );

        if (cat.effectiveTypeIndex == 0) {
          // Expense
          if (cat.budget != null && cat.budget! > 0 && spent > cat.budget!) {
            await showDialog(
              context: context,
              builder: (_) => SheepGoalDialog(
                title: l10n.get('budget_warning'),
                message: l10n.get('budget_msg', params: {'name': cat.name}),
                color: AppColors.expense,
                isSuccess: false,
                buttonLabel: l10n.get('understood'),
              ),
            );
          }
        } else if (cat.effectiveTypeIndex == 2) {
          // Savings
          if (cat.targetAmount != null &&
              cat.targetAmount! > 0 &&
              spent >= cat.targetAmount!) {
            await showDialog(
              context: context,
              builder: (_) => SheepGoalDialog(
                title: l10n.get('goal_congrats'),
                message: l10n.get('goal_msg'),
                color: AppColors.savings,
                isSuccess: true,
                buttonLabel: l10n.get('awesome'),
              ),
            );
          }
        }
      } catch (_) {
        // Ignore errors in goal check to not block the main flow
      }

      if (mounted) {
        Navigator.of(context).pop(_selectedDate);
      }
    } catch (e) {
      SheepNotifications.showError(context, '${l10n.get('error_prefix')}: $e');
    }
  }

  // Open the custom category picker dialog
  void _showCategoryPicker() {
    final cats = _catBox.values
        .where((c) => c.effectiveTypeIndex == _selectedTypeIndex)
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionCategoryPicker(
        categories: cats,
        selectedCategoryId: _selectedCategoryId,
        onCategorySelected: (id) {
          final selected = _catBox.values.firstWhere((c) => c.id == id);
          setState(() {
            _selectedCategoryId = id;
            _selectedTypeIndex = selected.effectiveTypeIndex;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    CategoryModel? selectedCategory;
    if (_selectedCategoryId != null) {
      try {
        selectedCategory = _catBox.values.firstWhere(
          (c) => c.id == _selectedCategoryId,
        );
      } catch (_) {}
    }

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(theme.brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        top: SheepSpacing.xl,
        left: SheepSpacing.page,
        right: SheepSpacing.page,
        bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            const SizedBox(height: SheepSpacing.xl),
            TransactionImageArea(
              imagePath: _imagePath,
              selectedIndex: _selectedTypeIndex,
              selectedCategory: selectedCategory,
              categoryColor: selectedCategory?.colorValue != null
                  ? Color(selectedCategory!.colorValue!)
                  : null,
              amountController: _amountController,
              noteController: _noteController,
              onRemoveImage: _confirmRemoveImage,
              noteShakeAnimation: _noteShakeAnimation,
              noteMaxLength: _noteMaxLength,
              onNoteLimitExceeded: _shakeNoteField,
            ),
            const SizedBox(height: SheepSpacing.lg),
            _buildMetaControls(selectedCategory),
            const SizedBox(height: SheepSpacing.xl),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaControls(CategoryModel? selectedCategory) {
    return Row(
      children: [
        Expanded(child: _buildCategoryPill(selectedCategory)),
        const SizedBox(width: 10),
        Expanded(child: _buildDatePill()),
      ],
    );
  }

  Widget _buildCategoryPill(CategoryModel? selectedCategory) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final hasCategory = selectedCategory != null;
    final accent = hasCategory
        ? (selectedCategory.colorValue != null
              ? Color(selectedCategory.colorValue!)
              : AppColors.getInteractiveAccent(
                  theme.brightness,
                  theme.colorScheme.primary,
                ))
        : AppColors.getTextSecondary(theme.brightness);

    final showArrow = hasCategory || widget.transaction != null;

    Widget content;
    if (!hasCategory) {
      // Centered placeholder text without arrow
      content = Center(
        child: Text(
          l10n.get('category_placeholder'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: SheepTextStyles.itemTitle(context).copyWith(
            color: AppColors.getTextPrimary(theme.brightness),
            fontSize: SheepTypeScale.item,
          ),
        ),
      );
    } else {
      // With icon and arrow at the end
      content = Row(
        children: [
          SheepCategoryIcon(
            icon: selectedCategory.iconData,
            color: accent,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selectedCategory.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SheepTextStyles.itemTitle(context).copyWith(
                color: AppColors.getTextPrimary(theme.brightness),
                fontSize: SheepTypeScale.item,
              ),
            ),
          ),
          if (showArrow)
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.getTextSecondary(theme.brightness),
              size: 18,
            ),
        ],
      );
    }

    return _TransactionPill(
      onTap: _showCategoryPicker,
      color: accent,
      backgroundColor: hasCategory
          ? AppColors.getAccentSurface(theme.brightness, accent)
          : AppColors.getSubtleSurface(theme.brightness),
      borderColor: hasCategory
          ? accent.withValues(alpha: 0.32)
          : AppColors.getBorder(theme.brightness),
      child: content,
    );
  }

  Widget _buildDatePill() {
    final theme = Theme.of(context);
    final accent = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );
    return _TransactionPill(
      onTap: _pickDate,
      color: accent,
      backgroundColor: AppColors.getSubtleSurface(theme.brightness),
      borderColor: AppColors.getBorder(theme.brightness),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              DateFormat(
                'dd/MM/yyyy',
                Localizations.localeOf(context).toString(),
              ).format(_selectedDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SheepTextStyles.itemTitle(
                context,
              ).copyWith(fontSize: SheepTypeScale.item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    final enteredAmount = CurrencyParsing.parseAmount(_amountController.text);
    final isAmountValid = _amountController.text.isNotEmpty && enteredAmount > 0;
    final isCategoryValid = _selectedCategoryId != null;
    final canSubmit = isAmountValid && isCategoryValid && (widget.transaction == null || _hasChanges);
    final accent = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );

    return SizedBox(
      height: 86,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCircleActionButton(
                icon: Icons.photo_library_rounded,
                label: L10n.of(context).uploadImage,
                color: AppColors.getTextSecondary(theme.brightness),
                onTap: _pickImage,
                size: 62,
              ),
              const SizedBox(width: 40),
              const SizedBox(width: 78), // Placeholder for primary button
              const SizedBox(width: 102), // Balance: 40 (gap) + 62 (photo button size)
            ],
          ),
          _buildCircleActionButton(
            icon: Icons.check_rounded,
            label: widget.transaction == null
                ? L10n.of(context).get('create')
                : L10n.of(context).save,
            color: accent,
            onTap: canSubmit ? _submit : null,
            size: 78,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    required double size,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;
    final buttonColor = isPrimary
        ? color
        : AppColors.getSubtleSurface(theme.brightness);
    final iconColor = isPrimary
        ? AppColors.getOnAccent(theme.brightness, color)
        : AppColors.getTextSecondary(theme.brightness);

    Widget buttonContent = Container(
      width: isPrimary ? size - 14 : size,
      height: isPrimary ? size - 14 : size,
      decoration: BoxDecoration(
        color: buttonColor,
        shape: BoxShape.circle,
        border: isPrimary
            ? null
            : Border.all(
                color: AppColors.getBorder(theme.brightness),
                width: 1,
              ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: iconColor, size: isPrimary ? 30 : 26),
    );

    if (isPrimary) {
      buttonContent = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.38),
            width: 3.0,
          ),
        ),
        child: buttonContent,
      );
    }

    return Semantics(
      button: true,
      label: label,
      enabled: isEnabled,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: isEnabled ? 1 : 0.45,
          child: buttonContent,
        ),
      ),
    );
  }
}

class _TransactionPill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  const _TransactionPill({
    required this.child,
    required this.onTap,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SheepRadius.md),
        child: Ink(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(SheepRadius.md),
            border: Border.all(color: borderColor),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
