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
import 'transaction/transaction_actions.dart';
import 'transaction/voice_input_dialog.dart';
import 'common/sheep_toggles.dart';
import 'common/sheep_kit.dart';

import 'common/sheep_notifications.dart';
import 'common/sheep_dialogs.dart';
import '../../core/utils/transaction_image_store.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/sheepify_scan_ai_service.dart';
import '../../data/services/wallet_service.dart';
import '../screens/payment/quick_transfer_screen.dart';
import '../screens/scanner/smart_qr_scanner_screen.dart';

class TransactionForm extends StatefulWidget {
  final Transaction? transaction;
  final DateTime? initialDate;
  final List<Transaction>? dayTransactions;
  final ScannedTransactionModel? scannedData;
  final String? scannedImagePath;

  /// Called with the transaction a VietQR scan / quick transfer produced, so
  /// the host screen can show its undo banner.
  final ValueChanged<Transaction>? onPaymentTransactionCreated;

  const TransactionForm({
    super.key,
    this.transaction,
    this.initialDate,
    this.dayTransactions,
    this.scannedData,
    this.scannedImagePath,
    this.onPaymentTransactionCreated,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm>
    with SingleTickerProviderStateMixin {
  static const int _noteMaxLength = 50;
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
  late final AnimationController _noteShakeController;
  late final Animation<double> _noteShakeAnimation;

  late DateTime _selectedDate;
  late int _selectedTypeIndex; // 0: expense, 1: income, 2: savings

  String? _selectedCategoryId;
  String? _imagePath;

  Transaction? _activeTransaction;
  List<Transaction> _imageTransactions = [];
  PageController? _pageController;
  int _currentPage = 0;
  bool _isProcessingScan = false;

  // Values the active transaction had when it was loaded, used to detect
  // unsaved edits before switching to another transaction in the carousel.
  String _origAmountText = '';
  String _origNote = '';
  DateTime? _origDate;
  String? _origCategoryId;
  String? _origImagePath;

  bool get _isEditing => _activeTransaction != null;

  bool get _isDirty =>
      _isEditing &&
      (_amountController.text != _origAmountText ||
          _noteController.text != _origNote ||
          _selectedDate != _origDate ||
          _selectedCategoryId != _origCategoryId ||
          _imagePath != _origImagePath);

  void _captureSnapshot() {
    _origAmountText = _amountController.text;
    _origNote = _noteController.text;
    _origDate = _selectedDate;
    _origCategoryId = _selectedCategoryId;
    _origImagePath = _imagePath;
  }
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
      _currentPage = middlePage;
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
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTypeIndex = 0; // Default Expense
      _applyScannedData(widget.scannedData!, imageRef: widget.scannedImagePath);
    } else {
      // Default state for new transaction
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTypeIndex = 0; // Default Expense
      _imagePath = null;
      _amountController.text = ''; // Start empty to show hint '0'
    }

    if (_isEditing) _captureSnapshot();

    // Refresh state on each character typed to update visual feedback
    _amountController.addListener(() => setState(() {}));
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _amountFocusNode.dispose();
    _noteShakeController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _shakeNoteField() {
    HapticFeedback.selectionClick();
    _noteShakeController.forward(from: 0);
  }

  /// Fills the form from an AI scan / voice result. Fields the AI could not
  /// determine keep their current value. Wrap in setState once built.
  void _applyScannedData(ScannedTransactionModel data, {String? imageRef}) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();

    if (data.amount > 0) {
      _amountController.text = CurrencyUtil.formatNumber(
        data.amount.toDouble(),
        locale: settings.languageCode == 'vi' ? 'vi_VN' : 'en_US',
      );
    }
    if (data.note.isNotEmpty) {
      _noteController.text = data.note;
    }
    if (data.date != 'TODAY') {
      final parsedDate = DateTime.tryParse(data.date);
      if (parsedDate != null) _selectedDate = parsedDate;
    }
    if (imageRef != null) _imagePath = imageRef;

    final catName = data.category.toLowerCase().trim();
    CategoryModel? matchedCat;
    for (final cat in _catBox.values) {
      if (cat.name.toLowerCase().trim() == catName) {
        matchedCat = cat;
        break;
      }
    }
    if (matchedCat == null) {
      const mapping = {
        'ăn uống': 'cat_eat',
        'mua sắm': 'cat_shop',
        'hóa đơn': 'cat_bill',
        'hoá đơn': 'cat_bill',
      };
      final targetId = mapping[catName];
      if (targetId != null) {
        for (final cat in _catBox.values) {
          if (cat.id == targetId) {
            matchedCat = cat;
            break;
          }
        }
      }
    }
    if (matchedCat != null) {
      _selectedCategoryId = matchedCat.id;
      _selectedTypeIndex = matchedCat.effectiveTypeIndex;
    }
  }

  void _changeType(int typeIndex) {
    if (typeIndex == _selectedTypeIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTypeIndex = typeIndex;
      final current = _selectedCategory;
      if (current != null && current.effectiveTypeIndex != typeIndex) {
        _selectedCategoryId = null;
      }
    });
  }

  CategoryModel? get _selectedCategory {
    if (_selectedCategoryId == null) return null;
    for (final c in _catBox.values) {
      if (c.id == _selectedCategoryId) return c;
    }
    return null;
  }

  /// Categories of the current type, most used first.
  List<CategoryModel> _quickCategories() {
    final usage = <String, int>{};
    for (final tx in _box.values) {
      usage[tx.categoryId] = (usage[tx.categoryId] ?? 0) + 1;
    }
    final cats = _catBox.values
        .where((c) => c.effectiveTypeIndex == _selectedTypeIndex)
        .toList()
      ..sort((a, b) => (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0));
    return cats.take(8).toList();
  }

  Future<void> _scanReceipt() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _buildDragHandle(),
            _buildPickerTitle(context, l10n.get('scan_source_title')),
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
      ),
    );
    if (source == null || !mounted) return;

    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null || !mounted) return;

      setState(() => _isProcessingScan = true);
      final result = await SheepifyScanAIService.processInvoiceScan(pickedFile);
      if (!mounted) return;

      if (result == null) {
        setState(() => _isProcessingScan = false);
        SheepNotifications.showError(context, l10n.get('scan_failed'));
        return;
      }

      final storedImageRef = await TransactionImageStore.saveFromSourcePath(
        pickedFile.path,
      );
      if (!mounted) return;
      setState(() {
        _isProcessingScan = false;
        _applyScannedData(result, imageRef: storedImageRef);
      });
    } catch (e) {
      debugPrint('Sheepify scan failed: $e');
      if (!mounted) return;
      setState(() => _isProcessingScan = false);
      SheepNotifications.showError(context, l10n.get('scan_failed'));
    }
  }

  Future<void> _openVoiceInput() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showModalBottomSheet<ScannedTransactionModel>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceInputDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _applyScannedData(result));
  }

  Future<bool> _confirmDiscardChanges() async {
    final l10n = L10n.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => SheepConfirmDialog(
        title: l10n.get('discard_changes_title'),
        content: l10n.get('discard_changes_msg'),
        confirmLabel: l10n.get('discard'),
        cancelLabel: l10n.get('keep_editing'),
        confirmColor: AppColors.expense,
        onConfirm: () {},
      ),
    );
    return discard == true;
  }

  Future<void> _handlePageChanged(int index) async {
    final target = _imageTransactions[index % _imageTransactions.length];
    if (target.key == _activeTransaction?.key) {
      _currentPage = index;
      return;
    }
    if (_isDirty && !await _confirmDiscardChanges()) {
      if (mounted && _effectivePageController.hasClients) {
        _effectivePageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (!mounted) return;
    _currentPage = index;
    _setActiveTransaction(target, fromPageSwipe: true);
  }

  Future<void> _requestSwitchTo(Transaction tx) async {
    if (tx.key == _activeTransaction?.key) return;
    if (_isDirty && !await _confirmDiscardChanges()) return;
    if (!mounted) return;
    _setActiveTransaction(tx);
  }

  void _deleteActiveTransaction() {
    final tx = _activeTransaction;
    if (tx == null) return;
    HapticFeedback.mediumImpact();
    TransactionActions.deleteWithUndo(context, tx);
    Navigator.of(context).pop();
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

  Widget _buildDragHandle() => const SheepDragHandle();

  Widget _buildStatusBadge(Transaction tx) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final isVi = settings.languageCode == 'vi';

    String statusText;
    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;

    if (tx.isPending) {
      statusText = isVi ? 'Chờ xác nhận' : 'Pending';
      statusBgColor = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      statusTextColor = const Color(0xFFD97706);
      statusIcon = Icons.hourglass_top_rounded;
    } else if (tx.isCancelled) {
      statusText = isVi ? 'Đã hủy' : 'Cancelled';
      statusBgColor = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusTextColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_outlined;
    } else {
      statusText = isVi ? 'Thành công' : 'Completed';
      statusBgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
      statusTextColor = const Color(0xFF059669);
      statusIcon = Icons.check_circle_outline_rounded;
    }

    String? sourceText;
    if (tx.walletId != null) {
      try {
        final wallet = WalletService.getWallet(tx.walletId!);
        if (wallet != null) {
          sourceText = wallet.name;
        }
      } catch (_) {}
    } else {
      sourceText = isVi ? 'Thủ công' : 'Manual';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: BorderRadius.circular(SheepRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 13, color: statusTextColor),
          const SizedBox(width: 4),
          Text(
            '$statusText${sourceText != null ? ' • $sourceText' : ''}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: statusTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SheepSpacing.lg,
        SheepSpacing.lg,
        SheepSpacing.lg,
        SheepSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: SheepTextStyles.sheetTitle(context)),
      ),
    );
  }

  // Validate and persist transaction data
  Future<void> _submit() async {
    final l10n = L10n.of(context);
    final double enteredAmount = _amountController.text.isEmpty
        ? 0.0
        : CurrencyParsing.parseAmount(_amountController.text);
    if (enteredAmount <= 0) {
      HapticFeedback.heavyImpact();
      SheepNotifications.showError(context, l10n.get('error_amount_required'));
      _amountFocusNode.requestFocus();
      return;
    }

    if (_selectedCategoryId == null) {
      SheepNotifications.showError(context, l10n.get('error_select_category'));
      _showCategoryPicker();
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      final cat = Hive.box<CategoryModel>(kCatBox).get(_selectedCategoryId);

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
        NotificationService.showTransactionActionNotification(
          action: TransactionActionType.updated,
          note: tx.note,
          amount: enteredAmount,
          categoryName: cat?.name,
          isExpense: tx.isExpense,
        );
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
          status: TransactionStatus.completed,
        );
        _box.add(newTx);
        SheepNotifications.showSuccess(context, l10n.get('tx_added'));
        NotificationService.showTransactionActionNotification(
          action: TransactionActionType.created,
          note: newTx.note,
          amount: enteredAmount,
          categoryName: cat?.name,
          isExpense: newTx.isExpense,
        );
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
        debugPrint('Sheepify save failed: $e');
        SheepNotifications.showError(context, l10n.get('error_prefix'));
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
        initialTypeIndex: _selectedTypeIndex,
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
                  // Status pill only when it says something: a pending /
                  // cancelled transfer, or which wallet paid.
                  if (_activeTransaction != null &&
                      (!_activeTransaction!.isCompleted ||
                          _activeTransaction!.walletId != null)) ...[
                    const SizedBox(height: SheepSpacing.md),
                    Center(child: _buildStatusBadge(_activeTransaction!)),
                  ],
                  const SizedBox(height: SheepSpacing.lg),
                  if (!_isEditing) ...[
                    _buildSmartEntryRow(),
                    const SizedBox(height: SheepSpacing.md),
                  ],
                  SheepTripleToggle(
                    selectedIndex: _selectedTypeIndex,
                    onChanged: _changeType,
                    labels: [
                      L10n.of(context).expense,
                      L10n.of(context).income,
                      L10n.of(context).savings,
                    ],
                  ),
                  const SizedBox(height: SheepSpacing.lg),
                  if (_imageTransactions.length > 1) ...[
                    AspectRatio(
                      aspectRatio: 1 / 0.82,
                      child: PageView.builder(
                        controller: _effectivePageController,
                        itemCount: _loopItemCount,
                        clipBehavior: Clip.none,
                        onPageChanged: _handlePageChanged,
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
                                amountFocusNode:
                                    isCurrent ? _amountFocusNode : null,
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
                      amountFocusNode: _amountFocusNode,
                      autofocusAmount:
                          !_isEditing && widget.scannedData == null,
                      compact: !_isEditing,
                    ),
                  ],
                  if (!_isEditing) ...[
                    const SizedBox(height: SheepSpacing.lg),
                    _buildQuickCategories(),
                  ],
                  const SizedBox(height: SheepSpacing.md),
                  _buildMetaControls(selectedCategory),
                  const SizedBox(height: SheepSpacing.xl),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          if (_isProcessingScan) _buildScanOverlay(),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    final theme = Theme.of(context);
    final accent = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SheepRadius.sheet),
          ),
        ),
        child: Center(
          child: Card(
            color: AppColors.getSurface(theme.brightness),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SheepRadius.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    L10n.of(context).get('scanning'),
                    textAlign: TextAlign.center,
                    style: SheepTextStyles.itemTitle(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Leaves the form for a payment flow (VietQR scan / quick transfer). The
  /// payment screen records its own transaction, which is handed back to
  /// the host screen.
  Future<void> _openPaymentFlow(Widget screen) async {
    if (_isDirty && !await _confirmDiscardChanges()) return;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final onCreated = widget.onPaymentTransactionCreated;
    navigator.pop();
    final tx = await navigator.push<Transaction>(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (tx != null) onCreated?.call(tx);
  }

  Widget _buildSmartEntryRow() {
    final l10n = L10n.of(context);
    final items = [
      (LineIcons.qrcode, l10n.get('qr_short'),
          () => _openPaymentFlow(const SmartQrScannerScreen())),
      (Icons.send_rounded, l10n.get('transfer_short'),
          () => _openPaymentFlow(const QuickTransferScreen())),
      (Icons.document_scanner_rounded, l10n.get('receipt_short'), _scanReceipt),
      (Icons.mic_rounded, l10n.get('voice_short'), _openVoiceInput),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: SheepSpacing.sm),
          Expanded(
            child: _SmartEntryButton(
              icon: items[i].$1,
              label: items[i].$2,
              onTap: items[i].$3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickCategories() {
    final theme = Theme.of(context);
    final cats = _quickCategories();
    if (cats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: SheepSpacing.sm),
        itemBuilder: (context, index) {
          final cat = cats[index];
          final color = cat.colorValue != null
              ? Color(cat.colorValue!)
              : AppColors.getInteractiveAccent(
                  theme.brightness,
                  theme.colorScheme.primary,
                );
          return SheepChip(
            label: cat.name,
            selected: cat.id == _selectedCategoryId,
            leading: SheepCategoryIcon(
              icon: cat.iconData,
              color: color,
              size: 28,
              imagePath: cat.imagePath,
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategoryId = cat.id);
            },
          );
        },
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
    final l10n = L10n.of(context);
    return Row(
      children: [
        SheepIconButton(
          icon: Icons.add_photo_alternate_outlined,
          tooltip: l10n.uploadImage,
          onPressed: _pickImage,
        ),
        const SizedBox(width: SheepSpacing.md),
        Expanded(
          child: SheepButton(
            label: _isEditing ? l10n.get('save_edit') : l10n.get('add_transaction'),
            large: true,
            onPressed: _submit,
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(width: SheepSpacing.md),
          SheepIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.get('delete_tx'),
            color: AppColors.expense,
            onPressed: _deleteActiveTransaction,
          ),
        ],
      ],
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
      _captureSnapshot();
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
                onTap: () => _requestSwitchTo(tx),
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

class _SmartEntryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmartEntryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.getSubtleSurface(brightness),
      borderRadius: BorderRadius.circular(SheepRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SheepRadius.md),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.getTextPrimary(brightness)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SheepTextStyles.itemMeta(context).copyWith(
                  color: AppColors.getTextPrimary(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
