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

class _TransactionFormState extends State<TransactionForm> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

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
    if (widget.transaction != null) {
      // Initialize state with existing transaction data
      final tx = widget.transaction!;
      _amountController.text = CurrencyUtil.formatNumber(tx.amount);
      _noteController.text = tx.note;
      _selectedDate = tx.date;
      _selectedTypeIndex = tx.isExpense ? 0 : 1; // Default fallback
      _selectedCategoryId = tx.categoryId;
      _imagePath = tx.imagePath;

      // Load current settings for currency
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
        final spent = CategoryUtil.calculateCategorySpent(cat);

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
            _buildDatePill(),
            const SizedBox(height: SheepSpacing.xl),
            TransactionImageArea(
              imagePath: _imagePath,
              isExpense: _selectedTypeIndex == 0,
              selectedIndex: _selectedTypeIndex, // PASSING NEW PROP
              selectedCategory: selectedCategory,
              categoryColor: selectedCategory?.colorValue != null
                  ? Color(selectedCategory!.colorValue!)
                  : null,
              amountController: _amountController,
              noteController: _noteController,
              onPickImage: _pickImage,
              onRemoveImage: () => setState(() => _imagePath = null),
              onShowCategoryPicker: _showCategoryPicker,
            ),
            const SizedBox(height: SheepSpacing.xl),
            _buildSaveButton(),
            const SizedBox(height: SheepSpacing.sm),
          ],
        ),
      ),
    );
  }

  // Interactive pill to display and change date/time
  Widget _buildDatePill() {
    final theme = Theme.of(context);
    return SheepDatePill(
      label: DateFormat(
        'dd/MM/yyyy',
        Localizations.localeOf(context).toString(),
      ).format(_selectedDate),
      onTap: _pickDate,
      backgroundColor: AppColors.getSubtleSurface(theme.brightness),
      border: Border.all(color: AppColors.getBorder(theme.brightness)),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: SheepButton(
        label: widget.transaction == null
            ? L10n.of(context).get('create')
            : L10n.of(context).save,
        onPressed: widget.transaction == null || _hasChanges ? _submit : null,
      ),
    );
  }
}
