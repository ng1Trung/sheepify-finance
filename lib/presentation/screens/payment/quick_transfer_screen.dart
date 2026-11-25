import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../core/utils/vietqr_parser.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/saved_payee.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/services/bank_deeplink_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/payment_prefs_service.dart';
import '../../../data/services/pending_transfer_service.dart';
import '../../../data/services/sheepify_scan_ai_service.dart';
import '../../../data/services/wallet_service.dart';
import '../../widgets/common/sheep_notifications.dart';
import '../../widgets/common/sheep_kit.dart';
import '../../widgets/common/sheep_widgets.dart';
import '../../widgets/payment/bank_app_picker_modal.dart';
import '../../widgets/transaction/transaction_category_picker.dart';

class QuickTransferScreen extends StatefulWidget {
  final String? initialAccountNo;
  final String? initialBankBin;
  final double? initialAmount;
  final String? initialNote;
  final String? initialPayeeName;

  /// The VietQR string that was scanned, kept as-is for the record.
  final String? initialQrPayload;

  const QuickTransferScreen({
    super.key,
    this.initialAccountNo,
    this.initialBankBin,
    this.initialAmount,
    this.initialNote,
    this.initialPayeeName,
    this.initialQrPayload,
  });

  @override
  State<QuickTransferScreen> createState() => _QuickTransferScreenState();
}

class _QuickTransferScreenState extends State<QuickTransferScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _accountNoController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _payeeNameController;

  /// Recipient bank as a NAPAS BIN. Kept even when we don't have that bank's
  /// app in our list, so a SeABank / MSB / … QR still pays the right bank.
  String? _recipientBin;
  String? get _recipientName => BankDeeplinkService.bankNameForBin(_recipientBin);
  WalletModel? _selectedWallet;
  BankAppModel? _sendingBank;
  CategoryModel? _selectedCategory;
  bool _savePayee = false;
  final FocusNode _amountFocus = FocusNode();

  /// Most-used expense categories, offered as one-tap chips.
  late final List<CategoryModel> _quickCategories;

  late final Box<CategoryModel> _catBox;
  late final Box<AppSettings> _settingsBox;
  late final Box<String> _payeesBox;

  List<SavedPayee> _savedPayees = [];

  // Voice AI
  late final stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isProcessingVoice = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _catBox = Hive.box<CategoryModel>(kCatBox);
    _settingsBox = Hive.box<AppSettings>(kSettingsBox);
    _payeesBox = Hive.box<String>(kSavedPayeesBox);

    _accountNoController =
        TextEditingController(text: widget.initialAccountNo ?? '');
    _amountController = TextEditingController(
      text: (widget.initialAmount != null && widget.initialAmount! > 0)
          ? NumberFormat('#,###', 'vi_VN').format(widget.initialAmount!.toInt())
          : '',
    );
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _payeeNameController =
        TextEditingController(text: widget.initialPayeeName ?? '');

    // Recipient bank comes from the QR / payee only — never a default.
    final initialBin = widget.initialBankBin?.trim();
    _recipientBin = (initialBin != null && initialBin.isNotEmpty)
        ? initialBin
        : null;

    // Ngân hàng gửi mặc định lấy từ Ví ngân hàng đã cài đặt trong app (loại bỏ ví tiền mặt)
    final bankWallets = WalletService.getWallets()
        .where((w) => w.bankId != null && w.bankId!.trim().isNotEmpty)
        .toList();
    final defaultWallet = WalletService.getDefaultWallet();
    if (defaultWallet != null &&
        defaultWallet.bankId != null &&
        defaultWallet.bankId!.trim().isNotEmpty) {
      _selectedWallet = defaultWallet;
    } else if (bankWallets.isNotEmpty) {
      _selectedWallet = bankWallets.first;
    }

    if (_selectedWallet != null) {
      _sendingBank = BankDeeplinkService.findById(_selectedWallet!.bankId);
    }

    // Category is chosen by the user (or a saved payee), not silently set to
    // whatever expense category happens to be first.

    // No bank wallet set up: reuse the app they paid with last time.
    _sendingBank ??=
        BankDeeplinkService.findById(PaymentPrefsService.lastSendingBankId);

    _quickCategories = PaymentPrefsService.frequentExpenseCategoryIds()
        .map((id) => _catBox.values.where((c) => c.id == id).firstOrNull)
        .whereType<CategoryModel>()
        .toList();

    // Load danh bạ người nhận
    _loadSavedPayees();

    // Paid this account before? Same category as last time.
    _selectedCategory ??= _categoryById(
      PaymentPrefsService.categoryFor(_recipientBin, widget.initialAccountNo),
    );

    // A static QR names the recipient but not the amount: go straight there.
    if (_amountController.text.isEmpty &&
        (widget.initialAccountNo ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }

    // Voice AI
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initSpeech();
  }

  @override
  void dispose() {
    _accountNoController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _payeeNameController.dispose();
    _amountFocus.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _loadSavedPayees() {
    final list = <SavedPayee>[];
    for (final raw in _payeesBox.values) {
      try {
        list.add(SavedPayee.fromJson(raw));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() => _savedPayees = list);

    // Nếu tên người nhận chưa có và có tài khoản + ngân hàng nhận, thử tìm trong danh bạ
    if (_payeeNameController.text.trim().isEmpty &&
        widget.initialAccountNo != null &&
        widget.initialBankBin != null) {
      try {
        final match = list.firstWhere(
          (p) =>
              p.accountNo == widget.initialAccountNo &&
              p.bankBin == widget.initialBankBin,
        );
        _payeeNameController.text = match.nickname;
        _selectedCategory ??= _categoryById(match.defaultCategoryId);
      } catch (_) {}
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _isListening = (status == 'listening'));
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() => _isSpeechAvailable = available);
    } catch (_) {}
  }

  void _toggleVoice() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_isSpeechAvailable) {
      SheepNotifications.showError(context, 'Không thể bật micro lúc này');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isListening = true);

    try {
      await _speech.listen(
        onResult: (result) async {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            await _processVoiceText(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(localeId: 'vi_VN'),
      );
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _processVoiceText(String speechText) async {
    setState(() {
      _isListening = false;
      _isProcessingVoice = true;
    });

    try {
      // 1. Kiểm tra xem câu nói có nhắc đến tên người nhận trong danh bạ không
      final lower = speechText.toLowerCase();
      SavedPayee? matchedPayee;
      for (final payee in _savedPayees) {
        if (lower.contains(payee.nickname.toLowerCase())) {
          matchedPayee = payee;
          break;
        }
      }

      if (matchedPayee != null) {
        _applyPayee(matchedPayee);
      }

      // 2. Phân tích số tiền, danh mục, nội dung bằng AI
      final parsed =
          await SheepifyScanAIService.processVoiceDescription(speechText);
      if (parsed != null && mounted) {
        setState(() {
          if (parsed.amount > 0) {
            _amountController.text =
                NumberFormat('#,###', 'vi_VN').format(parsed.amount);
          }
          if (parsed.note.isNotEmpty) {
            _noteController.text = parsed.note;
          }
          if (parsed.category.isNotEmpty) {
            try {
              final cat = _catBox.values.firstWhere(
                (c) =>
                    c.name.toLowerCase() == parsed.category.toLowerCase() &&
                    c.effectiveTypeIndex == 0,
              );
              _selectedCategory = cat;
            } catch (_) {}
          }
        });

        HapticFeedback.lightImpact();
        if (mounted) {
          SheepNotifications.showSuccess(
            context,
            'AI đã điền: ${CurrencyUtil.formatMoney(parsed.amount.toDouble(), locale: 'vi_VN')}₫',
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isProcessingVoice = false);
    }
  }

  CategoryModel? _categoryById(String? id) {
    if (id == null) return null;
    return _catBox.values.where((c) => c.id == id).firstOrNull;
  }

  void _applyPayee(SavedPayee payee) {
    HapticFeedback.selectionClick();
    setState(() {
      _accountNoController.text = payee.accountNo;
      _recipientBin = payee.bankBin;
      if (payee.defaultNote != null && payee.defaultNote!.isNotEmpty) {
        _noteController.text = payee.defaultNote!;
      }
      if (payee.defaultCategoryId != null) {
        try {
          _selectedCategory = _catBox.values.firstWhere(
            (c) => c.id == payee.defaultCategoryId,
          );
        } catch (_) {}
      } else {
        _selectedCategory ??= _categoryById(
          PaymentPrefsService.categoryFor(payee.bankBin, payee.accountNo),
        );
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        SheepNotifications.showError(context, 'Bộ nhớ tạm rỗng');
      }
      return;
    }

    // Trích xuất các chữ số liên tục (8-19 số) làm STK
    final digitsMatch = RegExp(r'\b\d{8,19}\b').firstMatch(text);
    if (digitsMatch != null) {
      final stk = digitsMatch.group(0)!;
      setState(() => _accountNoController.text = stk);
      HapticFeedback.lightImpact();
      if (mounted) {
        SheepNotifications.showSuccess(context, 'Đã dán STK: $stk');
      }
    } else {
      // Dán toàn bộ nếu chỉ có số
      final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.length >= 6) {
        setState(() => _accountNoController.text = clean);
        if (mounted) {
          SheepNotifications.showSuccess(context, 'Đã dán STK: $clean');
        }
      } else {
        if (mounted) {
          SheepNotifications.showError(context, 'Không tìm thấy STK trong clipboard');
        }
      }
    }
  }

  void _showBankPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    final directory = BankDeeplinkService.recipientDirectory();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final brightness = Theme.of(context).brightness;
            final q = searchQuery.trim().toLowerCase();
            final filtered = directory.where((entry) {
              if (q.isEmpty) return true;
              final app = BankDeeplinkService.findByBin(entry.$1);
              return entry.$2.toLowerCase().contains(q) ||
                  entry.$1.contains(q) ||
                  (app?.fullName.toLowerCase().contains(q) ?? false) ||
                  (app?.id.toLowerCase().contains(q) ?? false);
            }).toList();

            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.75,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SheepSpacing.page,
                  SheepSpacing.md,
                  SheepSpacing.page,
                  0,
                ),
                child: Column(
                  children: [
                    const SheepDragHandle(),
                    const SizedBox(height: SheepSpacing.md),
                    Text(
                      'Ngân hàng nhận',
                      style: SheepTextStyles.sheetTitle(context),
                    ),
                    const SizedBox(height: SheepSpacing.md),
                    TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: 'Tìm ngân hàng (VCB, MB, SeABank…)',
                        hintStyle: SheepTextStyles.itemMeta(context),
                        filled: true,
                        fillColor: AppColors.getSubtleSurface(brightness),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) =>
                          setModalState(() => searchQuery = val),
                    ),
                    const SizedBox(height: SheepSpacing.sm),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final (bin, name) = filtered[index];
                          final app = BankDeeplinkService.findByBin(bin);
                          final isSelected = _recipientBin == bin;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _recipientBin = bin);
                              Navigator.pop(context);
                            },
                            leading: _BankBadge(bin: bin, name: name),
                            title: Text(
                              name,
                              style: SheepTextStyles.itemTitle(context),
                            ),
                            subtitle: Text(
                              app?.fullName ?? 'Mã BIN $bin',
                              style: SheepTextStyles.itemMeta(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppColors.getTextPrimary(
                                      brightness,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoryPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    final expenseCategories = _catBox.values
        .where((c) => c.effectiveTypeIndex == 0)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionCategoryPicker(
        categories: expenseCategories,
        selectedCategoryId: _selectedCategory?.id,
        onCategorySelected: (id) {
          final selected = _catBox.values.firstWhere((c) => c.id == id);
          setState(() => _selectedCategory = selected);
          Navigator.pop(context);
        },
      ),
    );
  }

  double _getParsedAmount() {
    final clean = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0;
  }

  /// Bank app to send from: a bank wallet if the user has any, otherwise
  /// any supported bank app (a wallet is optional, not a prerequisite).
  Future<void> _pickSendingApp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final hasBankWallets = WalletService.getWallets().any(
      (w) => w.bankId != null && w.bankId!.trim().isNotEmpty,
    );
    if (hasBankWallets) {
      await InstalledWalletPickerModal.show(
        context: context,
        selectedWalletId: _selectedWallet?.id,
        onWalletSelected: (wallet, bank) {
          setState(() {
            _selectedWallet = wallet;
            _sendingBank = bank;
          });
        },
      );
      return;
    }
    final bank = await BankAppPickerModal.show(
      context: context,
      selectedBank: _sendingBank,
      title: 'Chuyển bằng app nào?',
    );
    if (bank != null && mounted) {
      setState(() {
        _sendingBank = bank;
        _selectedWallet = null;
      });
    }
  }

  Future<void> _handleConfirmTransfer() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final accountNo = _accountNoController.text.replaceAll(RegExp(r'\s'), '');

    // Never guess the recipient bank: a wrong bank + a valid account number
    // can be someone else's account.
    if (_recipientBin == null) {
      SheepNotifications.showError(context, 'Chọn ngân hàng nhận trước nhé');
      _showBankPicker();
      return;
    }
    if (!RegExp(r'^[0-9A-Za-z]{6,19}$').hasMatch(accountNo)) {
      SheepNotifications.showError(context, 'Số tài khoản không hợp lệ');
      return;
    }

    final amount = _getParsedAmount();
    if (amount <= 0) {
      SheepNotifications.showError(context, 'Nhập số tiền cần chuyển');
      return;
    }

    if (_selectedCategory == null) {
      SheepNotifications.showError(context, 'Chọn danh mục cho khoản chi này');
      _showCategoryPicker();
      return;
    }

    if (_sendingBank == null) {
      SheepNotifications.showError(context, 'Chọn app ngân hàng để chuyển');
      await _pickSendingApp();
      return;
    }

    final sendingBank = _sendingBank!;
    final recipientBin = _recipientBin!;
    final note = _noteController.text.trim().isNotEmpty
        ? _noteController.text.trim()
        : 'Chuyen tien';
    final recipientName = _recipientName ?? 'Ngân hàng nhận';

    // Keep the scanned QR untouched while the user pays exactly who it
    // names (it may carry merchant / bill references); otherwise build a
    // fresh one for the record.
    final scanned = widget.initialQrPayload;
    final qrPayload = scanned != null &&
            accountNo == widget.initialAccountNo?.trim() &&
            recipientBin == widget.initialBankBin?.trim()
        ? scanned
        : VietQrParser.generateVietQr(
            bankBin: recipientBin,
            bankAccount: accountNo,
            amount: amount,
            purpose: note,
          );

    // Opening the bank app proves nothing about the transfer (the user can
    // back out, fail OTP, lack funds), so every transfer starts as pending
    // and is confirmed when the user comes back. It is created *before*
    // leaving the app so the "did it go through?" prompt can find it.
    final pending = await PendingTransferService.createPendingTransfer(
      amount: amount,
      note: note,
      categoryId: _selectedCategory!.id,
      walletId: _selectedWallet?.id,
      sendingBankId: sendingBank.id,
      recipientBankBin: recipientBin,
      recipientBankName: recipientName,
      accountNo: accountNo,
      qrPayload: qrPayload,
    );
    final moneyBox = Hive.box<Transaction>(kMoneyBox);

    final launched = await BankDeeplinkService.launchBankApp(
      bank: sendingBank,
      qrPayload: qrPayload,
      accountNo: accountNo,
      recipientBin: recipientBin,
      amount: amount,
      note: note,
    );

    if (!launched) {
      // Nothing happened: leave no trace in the ledger.
      await PendingTransferService.cancelTransfer(pending.id);
      await moneyBox.delete(pending.id);
      if (mounted) {
        SheepNotifications.showError(
          context,
          'Không mở được ${sendingBank.shortName}. Kiểm tra app đã được cài chưa.',
        );
      }
      return;
    }

    if (_savePayee) {
      final nickname = _payeeNameController.text.trim().isNotEmpty
          ? _payeeNameController.text.trim()
          : recipientName;
      final payee = SavedPayee(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nickname: nickname,
        bankBin: recipientBin,
        accountNo: accountNo,
        defaultCategoryId: _selectedCategory?.id,
        defaultNote: note,
        createdAt: DateTime.now(),
      );
      await _payeesBox.put(payee.id, payee.toJson());
    }

    await PaymentPrefsService.rememberTransfer(
      sendingBankId: sendingBank.id,
      recipientBin: recipientBin,
      accountNo: accountNo,
      categoryId: _selectedCategory!.id,
    );
    // In case they never come back on their own.
    await NotificationService.schedulePendingTransferReminder(
      pendingId: pending.id,
      amount: amount,
      recipient: '$accountNo · $recipientName',
    );

    if (mounted) {
      Navigator.pop(context, moneyBox.get(pending.id));
      SheepNotifications.showSuccess(
        context,
        'Đã mở ${sendingBank.shortName}. Chuyển xong thì quay lại để xác nhận nhé.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final settings = _settingsBox.get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    return Scaffold(
      backgroundColor: AppColors.getBackground(brightness),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(brightness),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.getTextPrimary(brightness)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chuyển tiền',
          style: SheepTextStyles.sheetTitle(context),
        ),
        actions: [
          // Nút Voice AI trên AppBar
          IconButton(
            icon: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale =
                    _isListening ? (1.0 + _pulseController.value * 0.2) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    _isListening ? Icons.mic : LineIcons.microphone,
                    color: _isListening ? AppColors.expense : accentColor,
                  ),
                );
              },
            ),
            onPressed: _toggleVoice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SheepSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Voice AI Banner (nếu đang nghe)
            if (_isListening || _isProcessingVoice)
              Container(
                margin: const EdgeInsets.only(bottom: SheepSpacing.md),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SheepRadius.md),
                  border: Border.all(
                    color: AppColors.expense.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.expense),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isListening
                            ? '🎙️ Đang nghe... Hãy nói lệnh chuyển tiền (VD: Chuyển 500k cho mẹ tiền nhà)'
                            : '⚡ AI đang phân tích và điền form...',
                        style: TextStyle(
                          fontSize: SheepTypeScale.meta,
                          fontWeight: FontWeight.w600,
                          color: AppColors.expense,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Danh bạ người nhận thường xuyên (Quick Payees Carousel)
            if (_savedPayees.isNotEmpty) ...[
              SheepSectionTitle(
                title: 'Người nhận thường xuyên',
                padding: const EdgeInsets.only(bottom: 8),
              ),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _savedPayees.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final payee = _savedPayees[index];
                    final bank =
                        BankDeeplinkService.findByBin(payee.bankBin);

                    return GestureDetector(
                      onTap: () => _applyPayee(payee),
                      child: Container(
                        width: 90,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(brightness),
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                          border: Border.all(
                            color: AppColors.getBorder(brightness),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: (bank?.brandColor ?? accentColor)
                                  .withValues(alpha: 0.15),
                              child: Text(
                                payee.nickname.isNotEmpty
                                    ? payee.nickname[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: bank?.brandColor ?? accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              payee.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.getTextPrimary(brightness),
                              ),
                            ),
                            Text(
                              bank?.shortName ?? 'Bank',
                              maxLines: 1,
                              style: SheepTextStyles.itemMeta(context).copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: SheepSpacing.md),
            ],

            // Card Thông tin chuyển khoản
            SheepCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ngân hàng nhận — must be picked; never defaulted.
                  _PickerTile(
                    onTap: _showBankPicker,
                    leading: _recipientBin != null
                        ? _BankBadge(bin: _recipientBin!, name: _recipientName ?? '')
                        : null,
                    label: 'Ngân hàng nhận',
                    value: _recipientName ??
                        (_recipientBin != null
                            ? 'Mã BIN $_recipientBin'
                            : 'Chọn ngân hàng'),
                    isPlaceholder: _recipientBin == null,
                  ),
                  const SizedBox(height: SheepSpacing.md),

                  // Số tài khoản người nhận + Nút Dán
                  TextField(
                    controller: _accountNoController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: SheepTypeScale.item,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.getTextPrimary(brightness),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Số tài khoản nhận',
                      labelStyle: SheepTextStyles.itemMeta(context).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: 'Nhập số tài khoản...',
                      filled: true,
                      fillColor: AppColors.getSubtleSurface(brightness),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SheepRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: TextButton.icon(
                        icon: const Icon(Icons.content_paste, size: 16),
                        label: const Text('Dán'),
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ),
                  const SizedBox(height: SheepSpacing.md),

                  // Số tiền
                  TextField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    keyboardType: TextInputType.number,
                    style: SheepTextStyles.amount(
                      context,
                      size: SheepTypeScale.headline,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Số tiền',
                      labelStyle: SheepTextStyles.itemMeta(context).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: '0',
                      suffixText: '₫',
                      suffixStyle: SheepTextStyles.amount(context),
                      filled: true,
                      fillColor: AppColors.getSubtleSurface(brightness),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SheepRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(locale: 'vi_VN'),
                    ],
                  ),
                  const SizedBox(height: SheepSpacing.md),

                  // Danh mục & Nội dung
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: GestureDetector(
                          onTap: _showCategoryPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.getSubtleSurface(brightness),
                              borderRadius:
                                  BorderRadius.circular(SheepRadius.md),
                            ),
                            child: Row(
                              children: [
                                if (_selectedCategory != null)
                                  SheepCategoryIcon(
                                    icon: _selectedCategory!.iconData,
                                    color: Color(
                                      _selectedCategory!.colorValue ??
                                          accentColor.toARGB32(),
                                    ),
                                    size: 26,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedCategory?.name ?? 'Danh mục',
                                    style: SheepTextStyles.itemTitle(context)
                                        .copyWith(
                                      fontSize: SheepTypeScale.label,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color:
                                      AppColors.getTextSecondary(brightness),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: SheepSpacing.sm),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _noteController,
                          maxLength: 50,
                          style: TextStyle(
                            fontSize: SheepTypeScale.item,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(brightness),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nội dung',
                            labelStyle:
                                SheepTextStyles.itemMeta(context).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: 'VD: Tiền nhà...',
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.getSubtleSurface(brightness),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SheepRadius.md),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_quickCategories.isNotEmpty) ...[
                    const SizedBox(height: SheepSpacing.sm),
                    Wrap(
                      spacing: SheepSpacing.sm,
                      runSpacing: SheepSpacing.sm,
                      children: [
                        for (final cat in _quickCategories)
                          SheepChip(
                            label: cat.name,
                            selected: _selectedCategory?.id == cat.id,
                            leading: Icon(
                              cat.iconData,
                              size: 16,
                              color: _selectedCategory?.id == cat.id
                                  ? AppColors.getOnPrimaryFill(brightness)
                                  : Color(
                                      cat.colorValue ?? accentColor.toARGB32(),
                                    ),
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: SheepSpacing.md),

                  // Tùy chọn lưu vào danh bạ
                  Row(
                    children: [
                      Checkbox(
                        value: _savePayee,
                        activeColor: accentColor,
                        onChanged: (val) {
                          setState(() => _savePayee = val ?? false);
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Lưu vào danh bạ người nhận thường xuyên',
                          style: TextStyle(
                            fontSize: SheepTypeScale.label,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(brightness),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_savePayee) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _payeeNameController,
                        style: TextStyle(
                          fontSize: SheepTypeScale.item,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(brightness),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Tên gợi nhớ (VD: Chủ nhà, Mẹ…)',
                          labelStyle:
                              SheepTextStyles.itemMeta(context).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          filled: true,
                          fillColor: AppColors.getSubtleSurface(brightness),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(SheepRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SheepSpacing.md),

            // App / wallet used to send
            _PickerTile(
              onTap: _pickSendingApp,
              leading: _sendingBank != null
                  ? _BankBadge(
                      bin: _sendingBank!.bin,
                      name: _sendingBank!.shortName,
                    )
                  : null,
              label: 'Chuyển bằng',
              value: _selectedWallet?.name ??
                  _sendingBank?.shortName ??
                  'Chọn app ngân hàng',
              detail: _selectedWallet != null
                  ? 'Số dư ${CurrencyUtil.formatMoney(_selectedWallet!.initialBalance, locale: 'vi_VN')}'
                  : null,
              isPlaceholder: _sendingBank == null,
              card: true,
            ),
            const SizedBox(height: SheepSpacing.xl),

            SheepButton(
              label: 'Mở app ngân hàng để chuyển',
              isFullWidth: true,
              large: true,
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              onPressed: _handleConfirmTransfer,
            ),
            const SizedBox(height: SheepSpacing.sm),
            Text(
              'Giao dịch được ghi “Chờ xác nhận” cho tới khi bạn xác nhận đã chuyển xong.',
              textAlign: TextAlign.center,
              style: SheepTextStyles.itemMeta(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bank logo from VietQR's CDN, falling back to the bank's initials offline.
class _BankBadge extends StatelessWidget {
  final String bin;
  final String name;
  static const double size = 36;

  const _BankBadge({required this.bin, required this.name});

  String get _initials {
    final app = BankDeeplinkService.findByBin(bin);
    if (app != null && app.id.length <= 4) return app.id.toUpperCase();
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length > 1) return words.take(2).map((w) => w[0]).join().toUpperCase();
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final app = BankDeeplinkService.findByBin(bin);
    final color = app?.brandColor ?? AppColors.getTextSecondary(brightness);
    final fallback = Center(
      child: Text(
        _initials,
        style: SheepTextStyles.itemMeta(context).copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SheepRadius.sm),
        border: Border.all(color: AppColors.getBorder(brightness)),
      ),
      child: app?.logoUrl != null
          ? Padding(
              padding: const EdgeInsets.all(3),
              child: Image.network(
                app!.logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
            )
          : fallback,
    );
  }
}

/// "Label / value ▾" row used for the recipient bank and the paying app.
class _PickerTile extends StatelessWidget {
  final VoidCallback onTap;
  final Widget? leading;
  final String label;
  final String value;
  final String? detail;
  final bool isPlaceholder;
  final bool card;

  const _PickerTile({
    required this.onTap,
    required this.label,
    required this.value,
    this.leading,
    this.detail,
    this.isPlaceholder = false,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = BorderRadius.circular(card ? SheepRadius.xl : SheepRadius.md);
    return Material(
      color: card
          ? AppColors.getSurface(brightness)
          : AppColors.getSubtleSurface(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: card
            ? BorderSide(color: AppColors.getBorder(brightness))
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: SheepTextStyles.itemMeta(context)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SheepTextStyles.itemTitle(context).copyWith(
                        color: isPlaceholder
                            ? AppColors.getTextMuted(brightness)
                            : null,
                      ),
                    ),
                    if (detail != null)
                      Text(detail!, style: SheepTextStyles.itemMeta(context)),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.getTextSecondary(brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
