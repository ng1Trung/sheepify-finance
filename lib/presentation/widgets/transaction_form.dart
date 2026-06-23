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
import '../../core/utils/transaction_image_store.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/sheepify_scan_ai_service.dart';

class TransactionForm extends StatefulWidget {
  final Transaction? transaction;
  final DateTime? initialDate;
  final List<Transaction>? dayTransactions;
  final ScannedTransactionModel? scannedData;
  final String? scannedImagePath;

  const TransactionForm({
    super.key,
    this.transaction,
    this.initialDate,
    this.dayTransactions,
    this.scannedData,
    this.scannedImagePath,
  });

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

  Transaction? _activeTransaction;
  List<Transaction> _imageTransactions = [];
  PageController? _pageController;
  static const int _loopFactor = 10000;

  int get _loopItemCount => _imageTransactions.length * _loopFactor;

  PageController get _effectivePageController {
    if (_pageController == null) {
      int initialPageIndex = 0;
      if (_activeTransaction != null) {
        initialPageIndex = _imageTransactions.indexWhere((tx) => tx.key == _activeTransaction!.key);
        if (initialPageIndex == -1) initialPageIndex = 0;
      }
      final int middlePage = (_loopFactor ~/ 2) * _imageTransactions.length + initialPageIndex;
      _pageController = PageController(
        viewportFraction: 0.82,
        initialPage: middlePage,
      );
    }
    return _pageController!;
  }

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

    _activeTransaction = widget.transaction;
    if (widget.dayTransactions != null) {
      _imageTransactions = widget.dayTransactions!.where((tx) {
        if (tx.amount == 0) return true;
        final imageFile = TransactionImageStore.resolve(tx.imagePath);
        return imageFile?.existsSync() ?? false;
      }).toList();
    }


    if (_activeTransaction != null) {
      // Initialize state with existing transaction data
      final tx = _activeTransaction!;
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
    } else if (widget.scannedData != null) {
      // Initialize state with pre-filled AI scanned/parsed data
      final data = widget.scannedData!;
      
      final settings =
          Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
      
      _amountController.text = data.amount > 0
          ? CurrencyUtil.formatNumber(
              data.amount.toDouble(),
              locale: settings.languageCode == 'vi' ? 'vi_VN' : 'en_US',
            )
          : '';
      _noteController.text = data.note;
      
      _selectedDate = widget.initialDate ?? DateTime.now();
      if (data.date != 'TODAY') {
        final parsedDate = DateTime.tryParse(data.date);
        if (parsedDate != null) {
          _selectedDate = parsedDate;
        }
      }
      
      _imagePath = widget.scannedImagePath;
      _selectedTypeIndex = 0; // Default Expense
      
      // Match category
      final catName = data.category.toLowerCase().trim();
      CategoryModel? matchedCat;
      for (final cat in _catBox.values) {
        if (cat.name.toLowerCase().trim() == catName) {
          matchedCat = cat;
          break;
        }
      }

      if (matchedCat != null) {
        _selectedCategoryId = matchedCat.id;
        _selectedTypeIndex = matchedCat.effectiveTypeIndex;
      } else {
        // Fallback mapping
        final mapping = {
          'ăn uống': 'cat_eat',
          'mua sắm': 'cat_shop',
          'hóa đơn': 'cat_bill',
          'hoá đơn': 'cat_bill',
        };
        final targetId = mapping[catName];
        if (targetId != null && _catBox.containsKey(targetId)) {
          _selectedCategoryId = targetId;
          final cat = _catBox.get(targetId);
          if (cat != null) {
            _selectedTypeIndex = cat.effectiveTypeIndex;
          }
        }
      }
    } else {
      // Default state for new transaction
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTypeIndex = 0; // Default Expense
      _imagePath = null;
      _amountController.text = ''; // Start empty to show hint '0'
    }

    // Refresh state on each character typed to update visual feedback
    _amountController.addListener(() => setState(() {}));
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _noteShakeController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _shakeNoteField() {
    HapticFeedback.selectionClick();
    _noteShakeController.forward(from: 0);
  }



  // Select transaction date
  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
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
    FocusManager.instance.primaryFocus?.unfocus();
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
          setState(() {
            _imagePath = storedImageRef;
          });
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
    if (_selectedCategoryId == null) {
      SheepNotifications.showError(context, l10n.get('error_select_category'));
      return;
    }

    final double enteredAmount = _amountController.text.isEmpty
        ? 0.0
        : CurrencyParsing.parseAmount(_amountController.text);
    if (enteredAmount < 0) return;

    HapticFeedback.mediumImpact();

    try {
      if (_activeTransaction != null) {
        // Update existing transaction in Hive
        final tx = _activeTransaction!;
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
          id: Transaction.createId(),
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
        await NotificationService.checkAndTriggerNotifications(
          context,
          _selectedCategoryId!,
          _selectedDate,
        );
      } catch (_) {
        // Ignore errors in goal check to not block the main flow
      }

      if (mounted) {
        Navigator.of(context).pop(_selectedDate);
      }
    } catch (e) {
      if (mounted) {
        SheepNotifications.showError(
          context,
          '${l10n.get('error_prefix')}: $e',
        );
      }
    }
  }

  // Open the custom category picker dialog
  void _showCategoryPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Stack(
        children: [
          Container(
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
                  if (_imageTransactions.length > 1) ...[
                    AspectRatio(
                      aspectRatio: 1 / 0.82,
                      child: PageView.builder(
                        controller: _effectivePageController,
                        itemCount: _loopItemCount,
                        clipBehavior: Clip.none,
                        onPageChanged: (index) {
                          final realIndex = index % _imageTransactions.length;
                          _setActiveTransaction(_imageTransactions[realIndex], fromPageSwipe: true);
                        },
                        itemBuilder: (context, index) {
                          final realIndex = index % _imageTransactions.length;
                          final tx = _imageTransactions[realIndex];
                          final isCurrent = tx.key == _activeTransaction?.key;

                          CategoryModel? txCategory;
                          if (isCurrent) {
                            txCategory = selectedCategory;
                          } else {
                            try {
                              txCategory = _catBox.values.firstWhere((c) => c.id == tx.categoryId);
                            } catch (_) {}
                          }

                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: TransactionImageArea(
                                imagePath: tx.imagePath,
                                selectedIndex: isCurrent ? _selectedTypeIndex : (tx.isExpense ? 0 : 1),
                                selectedCategory: txCategory,
                                categoryColor: (txCategory != null && txCategory.colorValue != null)
                                    ? Color(txCategory.colorValue!)
                                    : null,
                                amountController: _amountController,
                                noteController: _noteController,
                                onRemoveImage: _confirmRemoveImage,
                                noteShakeAnimation: _noteShakeAnimation,
                                noteMaxLength: _noteMaxLength,
                                onNoteLimitExceeded: _shakeNoteField,
                                date: tx.date,
                                isActive: isCurrent,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: SheepSpacing.xs),
                    _buildMiniPreviews(),
                  ] else ...[
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
                      date: _selectedDate,
                      isActive: true,
                    ),
                  ],
                  const SizedBox(height: SheepSpacing.lg),
                  _buildMetaControls(selectedCategory),
                  const SizedBox(height: SheepSpacing.xl),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),

        ],
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

    final showArrow = hasCategory || _activeTransaction != null;

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
            imagePath: selectedCategory.imagePath,
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
              const SizedBox(
                width: 102,
              ), // Balance: 40 (gap) + 62 (photo button size)
            ],
          ),
          _buildCircleActionButton(
            icon: Icons.check_rounded,
            label: _activeTransaction == null
                ? L10n.of(context).get('create')
                : L10n.of(context).save,
            color: accent,
            onTap: _submit,
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
          border: Border.all(color: color.withValues(alpha: 0.38), width: 3.0),
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

  void _setActiveTransaction(Transaction tx, {bool fromPageSwipe = false}) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    setState(() {
      _activeTransaction = tx;
      _amountController.text = CurrencyUtil.formatNumber(
        tx.amount,
        locale: settings.languageCode == 'vi' ? 'vi_VN' : 'en_US',
      );
      _noteController.text = tx.note;
      _selectedDate = tx.date;
      _selectedTypeIndex = tx.isExpense ? 0 : 1;
      try {
        final cat = _catBox.values.firstWhere((c) => c.id == tx.categoryId);
        _selectedTypeIndex = cat.effectiveTypeIndex;
      } catch (_) {}
      _selectedCategoryId = tx.categoryId;
      _imagePath = tx.imagePath;
    });

    if (!fromPageSwipe) {
      final index = _imageTransactions.indexWhere((t) => t.key == tx.key);
      if (index != -1 && _effectivePageController.hasClients) {
        final currentPage = _effectivePageController.page?.round() ?? 0;
        final currentRealIndex = currentPage % _imageTransactions.length;
        
        final int n = _imageTransactions.length;
        int diff = index - currentRealIndex;
        while (diff < -n / 2) {
          diff += n;
        }
        while (diff > n / 2) {
          diff -= n;
        }
        final targetPage = currentPage + diff;

        _effectivePageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Widget _buildMiniPreviews() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 68,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_imageTransactions.length, (index) {
              final tx = _imageTransactions[index];
              final isSelected = _activeTransaction?.key == tx.key;
              final imageFile = TransactionImageStore.resolve(tx.imagePath);
              final hasImage = imageFile != null && imageFile.existsSync();

              CategoryModel? txCategory;
              try {
                txCategory = _catBox.values.firstWhere((c) => c.id == tx.categoryId);
              } catch (_) {}

              Widget childWidget;
              if (hasImage) {
                childWidget = Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                );
              } else {
                final catColor = txCategory?.colorValue != null
                    ? Color(txCategory!.colorValue!)
                    : AppColors.getInteractiveAccent(theme.brightness, theme.colorScheme.primary);
                childWidget = Container(
                  color: catColor.withValues(alpha: 0.18),
                  child: Icon(
                    txCategory?.iconData ?? Icons.help_outline_rounded,
                    color: catColor,
                    size: 20,
                  ),
                );
              }

              return GestureDetector(
                onTap: () {
                  if (tx.key != _activeTransaction?.key) {
                    _setActiveTransaction(tx);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : AppColors.getBorder(theme.brightness),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: childWidget,
                    ),
                  ),
                ),
              );
            }),
          ),
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
