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
import '../../../data/models/pending_transfer.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/transaction.dart';
import '../../../data/services/bank_deeplink_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/pending_transfer_service.dart';
import '../../../data/services/sheepify_scan_ai_service.dart';
import '../../../data/services/wallet_service.dart';
import '../common/sheep_notifications.dart';
import '../common/sheep_widgets.dart';
import '../transaction/transaction_category_picker.dart';
import 'bank_app_picker_modal.dart';
import 'payment_transfer_assistant_sheet.dart';

class PaymentConfirmationBottomSheet extends StatefulWidget {
  final VietQrModel qrData;
  final String? initialPayeeName;

  const PaymentConfirmationBottomSheet({
    super.key,
    required this.qrData,
    this.initialPayeeName,
  });

  @override
  State<PaymentConfirmationBottomSheet> createState() =>
      _PaymentConfirmationBottomSheetState();
}

class _PaymentConfirmationBottomSheetState
    extends State<PaymentConfirmationBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  
  BankAppModel? _selectedBank;
  CategoryModel? _selectedCategory;
  late final Box<CategoryModel> _catBox;
  late final Box<AppSettings> _settingsBox;

  // Trạng thái hiển thị Trợ lý Chuyển khoản (cho các app ngân hàng)
  bool _showAssistantStep = false;
  PendingTransfer? _pendingTransfer;
  String? _savedPayload;

  // Voice AI State
  late final stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isProcessingVoiceAi = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _catBox = Hive.box<CategoryModel>(kCatBox);
    _settingsBox = Hive.box<AppSettings>(kSettingsBox);

    // Điền số tiền từ mã QR nếu có
    final double initialAmount = widget.qrData.amount ?? 0;
    _amountController = TextEditingController(
      text: initialAmount > 0
          ? NumberFormat('#,###', 'vi_VN').format(initialAmount.toInt())
          : '',
    );

    // Điền nội dung từ mã QR nếu có
    _noteController = TextEditingController(
      text: widget.qrData.purpose ?? '',
    );

    // Chọn ngân hàng thanh toán mặc định từ Cài đặt Ví
    final defaultWallet = WalletService.getDefaultWallet();
    if (defaultWallet != null && defaultWallet.bankId != null) {
      _selectedBank = BankDeeplinkService.findById(defaultWallet.bankId);
    }
    _selectedBank ??= BankDeeplinkService.supportedBanks.first;

    // Chọn danh mục mặc định (ưu tiên Ăn uống hoặc danh mục đầu tiên)
    final expenseCategories = _catBox.values
        .where((c) => c.effectiveTypeIndex == 0)
        .toList();
    if (expenseCategories.isNotEmpty) {
      try {
        _selectedCategory = expenseCategories.firstWhere(
          (c) => c.name.toLowerCase().contains('ăn') ||
              c.name.toLowerCase().contains('uống'),
        );
      } catch (_) {
        _selectedCategory = expenseCategories.first;
      }
    }

    // Khởi tạo Voice AI
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initSpeech();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _isListening = (status == 'listening');
            });
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isSpeechAvailable = available;
        });
      }
    } catch (_) {}
  }

  void _toggleVoiceInput() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_isSpeechAvailable) {
      SheepNotifications.showError(
        context,
        'Không thể kích hoạt microphone trên thiết bị này',
      );
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
        listenOptions: stt.SpeechListenOptions(
          localeId: 'vi_VN',
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _processVoiceText(String speechText) async {
    setState(() {
      _isListening = false;
      _isProcessingVoiceAi = true;
    });

    try {
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
          // Tìm danh mục khớp với tên AI gợi ý
          if (parsed.category.isNotEmpty) {
            try {
              final matchedCat = _catBox.values.firstWhere(
                (c) =>
                    c.name.toLowerCase() == parsed.category.toLowerCase() &&
                    c.effectiveTypeIndex == 0,
              );
              _selectedCategory = matchedCat;
            } catch (_) {}
          }
        });

        HapticFeedback.lightImpact();
        if (mounted) {
          SheepNotifications.showSuccess(
            context,
            'AI đã điền: ${CurrencyUtil.formatMoney(parsed.amount.toDouble(), locale: 'vi_VN')}₫ (${parsed.category})',
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isProcessingVoiceAi = false);
      }
    }
  }

  double _getParsedAmount() {
    final clean = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0;
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
          setState(() {
            _selectedCategory = selected;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _handleConfirmPayment() async {
    final amount = _getParsedAmount();
    if (amount <= 0) {
      HapticFeedback.heavyImpact();
      SheepNotifications.showError(
        context,
        'Vui lòng nhập số tiền thanh toán hợp lệ!',
      );
      return;
    }

    if (_selectedCategory == null) {
      SheepNotifications.showError(
        context,
        'Vui lòng chọn danh mục cho khoản chi tiêu này!',
      );
      return;
    }

    final note = _noteController.text.trim().isNotEmpty
        ? _noteController.text.trim()
        : 'Thanh toan VietQR';

    // 1. Tạo / Cập nhật chuỗi VietQR với số tiền và nội dung đã nhập
    String finalPayload = widget.qrData.rawPayload;
    if (widget.qrData.bankBin != null && widget.qrData.bankAccount != null) {
      finalPayload = VietQrParser.generateVietQr(
        bankBin: widget.qrData.bankBin!,
        bankAccount: widget.qrData.bankAccount!,
        amount: amount,
        purpose: note,
      );
    }

    final beneficiaryBank =
        BankDeeplinkService.findByBin(widget.qrData.bankBin);

    final isAutofill =
        _selectedBank == null || _selectedBank!.canAutofillPayment;

    if (isAutofill) {
      // 1. Kích hoạt Deeplink mở App ngân hàng (autofill STK, số tiền, nội dung)
      if (_selectedBank != null) {
        final launched = await BankDeeplinkService.launchBankApp(
          bank: _selectedBank!,
          qrPayload: finalPayload,
          accountNo: widget.qrData.bankAccount,
          recipientBin: widget.qrData.bankBin,
          amount: amount,
          note: note,
        );

        if (!launched && mounted) {
          SheepNotifications.showError(
            context,
            'Không thể mở ứng dụng ${_selectedBank!.shortName}. Vui lòng kiểm tra app đã cài đặt trên máy chưa!',
          );
          return;
        }
      }

      // 2. Tìm ví thanh toán liên kết
      String? resolvedWalletId;
      if (_selectedBank != null) {
        try {
          final wallets = WalletService.getWallets();
          final match =
              wallets.firstWhere((w) => w.bankId == _selectedBank!.id);
          resolvedWalletId = match.id;
        } catch (_) {}
      }

      // 3. Tự động ghi chép giao dịch hoàn tất vào sổ chi tiêu
      final moneyBox = Hive.box<Transaction>(kMoneyBox);
      final transaction = Transaction(
        id: Transaction.createId(),
        amount: amount,
        note: note,
        date: DateTime.now(),
        isExpense: true,
        categoryId: _selectedCategory!.id,
        status: TransactionStatus.completed,
        walletId: resolvedWalletId,
      );
      await moneyBox.put(transaction.id, transaction);

      // 4. Tự động khấu trừ số dư ví thanh toán nếu có
      if (resolvedWalletId != null) {
        final wallets = WalletService.getWallets();
        try {
          final w = wallets.firstWhere((w) => w.id == resolvedWalletId);
          final newBal =
              (w.initialBalance - amount).clamp(0.0, double.infinity);
          await WalletService.adjustBalance(w.id, newBal);
        } catch (_) {}
      }

      // 5. Kiểm tra ngân sách / mục tiêu tiết kiệm
      try {
        await NotificationService.checkAndTriggerNotifications(
          context,
          _selectedCategory!.id,
          DateTime.now(),
        );
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context, transaction);
        SheepNotifications.showSuccess(
          context,
          'Thanh toán thành công! Đã tự động trừ số dư ví & ghi sổ.',
        );
      }
    } else {
      // LOẠI 2 (Các ngân hàng/ví không hỗ trợ autofill thanh toán: MoMo, ZaloPay, Viettel Money...):
      // 1. Tạo bản ghi giao dịch Chờ xác nhận (Pending).
      // Số dư ví CHƯA bị trừ và Transaction CHƯA được tính vào ngân sách.
      final pending = await PendingTransferService.createPendingTransfer(
        amount: amount,
        note: note,
        categoryId: _selectedCategory!.id,
        sendingBankId: _selectedBank?.id,
        recipientBankBin: widget.qrData.bankBin,
        recipientBankName:
            beneficiaryBank?.shortName ?? widget.initialPayeeName,
        accountNo: widget.qrData.bankAccount ?? '',
        qrPayload: finalPayload,
      );

      // 2. Mở App Ngân Hàng qua Deeplink
      if (_selectedBank != null) {
        final launched = await BankDeeplinkService.launchBankApp(
          bank: _selectedBank!,
          qrPayload: finalPayload,
          accountNo: widget.qrData.bankAccount,
          recipientBin: widget.qrData.bankBin,
          amount: amount,
          note: note,
        );

        if (!launched && mounted) {
          SheepNotifications.showError(
            context,
            'Không thể mở ứng dụng ${_selectedBank!.shortName}. Vui lòng kiểm tra app đã cài đặt trên máy chưa!',
          );
          return;
        }

        // Hiển thị Trợ lý Chuyển khoản trong chính sheet này để người dùng xác nhận sau khi chuyển
        if (mounted) {
          setState(() {
            _pendingTransfer = pending;
            _savedPayload = finalPayload;
            _showAssistantStep = true;
          });
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu đang ở màn hình Trợ lý Chuyển khoản
    if (_showAssistantStep &&
        _pendingTransfer != null &&
        _selectedBank != null) {
      final beneficiaryBank =
          BankDeeplinkService.findByBin(widget.qrData.bankBin);
      return PaymentTransferAssistantSheet(
        sendingBank: _selectedBank!,
        recipientBankName:
            beneficiaryBank?.shortName ?? widget.initialPayeeName ?? 'Ngân hàng nhận',
        accountNo: widget.qrData.bankAccount ?? '',
        amount: _pendingTransfer!.amount,
        note: _pendingTransfer!.note,
        qrPayload: _savedPayload ?? widget.qrData.rawPayload,
        pendingId: _pendingTransfer!.id,
        onConfirmed: () async {
          final tx = await PendingTransferService.confirmTransfer(_pendingTransfer!.id);
          if (mounted && context.mounted) {
            Navigator.pop(context, tx);
            SheepNotifications.showSuccess(
              context,
              'Giao dịch thành công! Đã trừ số dư ví & cập nhật sổ chi tiêu.',
            );
          }
        },
        onCancelled: () async {
          await PendingTransferService.cancelTransfer(_pendingTransfer!.id);
          if (mounted && context.mounted) {
            Navigator.pop(context, null);
            SheepNotifications.showInfo(
              context,
              'Đã hủy giao dịch. Số dư ví giữ nguyên.',
            );
          }
        },
        onReopenApp: () {
          BankDeeplinkService.launchBankApp(
            bank: _selectedBank!,
            qrPayload: _savedPayload ?? widget.qrData.rawPayload,
            accountNo: widget.qrData.bankAccount,
            recipientBin: widget.qrData.bankBin,
            amount: _pendingTransfer!.amount,
            note: _pendingTransfer!.note,
          );
        },
      );
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final settings =
        _settingsBox.get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    final beneficiaryBank =
        BankDeeplinkService.findByBin(widget.qrData.bankBin);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        top: SheepSpacing.sm,
        left: SheepSpacing.page,
        right: SheepSpacing.page,
        bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: SheepSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(brightness)
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                  ),
                  child: Icon(
                    LineIcons.qrcode,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: SheepSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xác nhận thanh toán',
                        style: SheepTextStyles.itemTitle(context).copyWith(
                          fontSize: SheepTypeScale.bodyLarge,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Tự động ghi sổ & chuyển khoản qua App',
                        style: SheepTextStyles.itemMeta(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SheepSpacing.md),

            // Thông tin người nhận (Beneficiary Card)
            SheepCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildBankAvatar(beneficiaryBank),
                  const SizedBox(width: SheepSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beneficiaryBank?.shortName ?? 'Ngân hàng nhận',
                          style: SheepTextStyles.itemTitle(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'STK: ${widget.qrData.bankAccount ?? '---'}',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: SheepTypeScale.item,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.getTextPrimary(brightness),
                          ),
                        ),
                        if (widget.initialPayeeName != null &&
                            widget.initialPayeeName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.initialPayeeName!.toUpperCase(),
                            style: SheepTextStyles.itemMeta(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SheepSpacing.md),

            // Ô nhập số tiền + Nút Voice AI
            SheepCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SỐ TIỀN CHI TIÊU',
                          style: SheepTextStyles.itemMeta(context).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: SheepTypeScale.micro,
                          ),
                        ),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: SheepTypeScale.headline,
                            fontWeight: FontWeight.w800,
                            color: AppColors.expense,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: AppColors.getTextSecondary(brightness)
                                  .withValues(alpha: 0.4),
                            ),
                            suffixText: '₫',
                            suffixStyle: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: SheepTypeScale.bodyLarge,
                              fontWeight: FontWeight.w700,
                              color: AppColors.expense,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _CurrencyTextInputFormatter(),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Nút Microphone Voice AI
                  GestureDetector(
                    onTap: _toggleVoiceInput,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse = _isListening
                            ? (1.0 + _pulseController.value * 0.15)
                            : 1.0;
                        return Transform.scale(
                          scale: pulse,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isListening
                                  ? AppColors.expense
                                  : accentColor.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              boxShadow: _isListening
                                  ? [
                                      BoxShadow(
                                        color: AppColors.expense
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: _isProcessingVoiceAi
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isListening
                                        ? Icons.mic
                                        : LineIcons.microphone,
                                    color: _isListening
                                        ? Colors.white
                                        : accentColor,
                                    size: 22,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '🎙️ Đang nghe... Hãy nói số tiền & nội dung (VD: 45k ăn bún chả)',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: SheepTypeScale.meta,
                    fontWeight: FontWeight.w600,
                    color: AppColors.expense,
                  ),
                ),
              ),
            const SizedBox(height: SheepSpacing.md),

            // Chọn danh mục & Nội dung
            Row(
              children: [
                // Chọn danh mục
                Expanded(
                  flex: 5,
                  child: GestureDetector(
                    onTap: _showCategoryPicker,
                    child: SheepCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
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
                              size: 28,
                              imagePath: _selectedCategory!.imagePath,
                            )
                          else
                            Icon(
                              LineIcons.tag,
                              size: 24,
                              color: accentColor,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DANH MỤC',
                                  style: SheepTextStyles.itemMeta(context)
                                      .copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _selectedCategory?.name ?? 'Chọn',
                                  style: SheepTextStyles.itemTitle(context)
                                      .copyWith(
                                    fontSize: SheepTypeScale.label,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppColors.getTextSecondary(brightness),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SheepSpacing.sm),

                // Ghi chú
                Expanded(
                  flex: 6,
                  child: SheepCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: TextField(
                      controller: _noteController,
                      maxLength: 50,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: SheepTypeScale.item,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(brightness),
                      ),
                      decoration: InputDecoration(
                        labelText: 'NỘI DUNG',
                        labelStyle:
                            SheepTextStyles.itemMeta(context).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        hintText: 'VD: Cà phê...',
                        counterText: '',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SheepSpacing.md),

            // Chọn ứng dụng thanh toán (Bank Selector dạng dropdown / bottom sheet)
            BankAppSelectorTile(
              bank: _selectedBank,
              onTap: () {
                BankAppPickerModal.show(
                  context: context,
                  selectedBank: _selectedBank,
                  onBankSelected: (bank) {
                    setState(() => _selectedBank = bank);
                  },
                );
              },
            ),
            const SizedBox(height: SheepSpacing.lg),

            // Nút bấm Xác nhận: Thanh toán & Ghi sổ
            SheepButton(
              label: 'Thanh toán & Ghi sổ',
              isFullWidth: true,
              backgroundColor: accentColor,
              icon: const Icon(LineIcons.paperPlane, size: 20),
              onPressed: _handleConfirmPayment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAvatar(BankAppModel? bank) {
    if (bank == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(LineIcons.university, size: 24),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bank.brandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SheepRadius.md),
        border: Border.all(
          color: bank.brandColor.withValues(alpha: 0.25),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        bank.shortName.substring(0, bank.shortName.length.clamp(1, 3)),
        style: TextStyle(
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w800,
          fontSize: SheepTypeScale.label,
          color: bank.brandColor,
        ),
      ),
    );
  }
}

/// Formatter số tiền kiểu VND (10,000,000)
class _CurrencyTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final number = int.tryParse(digits) ?? 0;
    final formatted = NumberFormat('#,###', 'vi_VN').format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
