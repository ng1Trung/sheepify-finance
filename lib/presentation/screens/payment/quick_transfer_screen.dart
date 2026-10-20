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
import '../../../data/services/bank_deeplink_service.dart';
import '../../../data/services/pending_transfer_service.dart';
import '../../../data/services/sheepify_scan_ai_service.dart';
import '../../../data/services/wallet_service.dart';
import '../../widgets/common/sheep_notifications.dart';
import '../../widgets/common/sheep_widgets.dart';
import '../../widgets/payment/bank_app_picker_modal.dart';
import '../../widgets/transaction/transaction_category_picker.dart';

class QuickTransferScreen extends StatefulWidget {
  final String? initialAccountNo;
  final String? initialBankBin;
  final double? initialAmount;
  final String? initialNote;

  const QuickTransferScreen({
    super.key,
    this.initialAccountNo,
    this.initialBankBin,
    this.initialAmount,
    this.initialNote,
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

  BankAppModel? _recipientBank;
  BankAppModel? _sendingBank;
  CategoryModel? _selectedCategory;
  bool _savePayee = false;

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
    _payeeNameController = TextEditingController();

    // Khởi tạo ngân hàng nhận
    if (widget.initialBankBin != null) {
      _recipientBank = BankDeeplinkService.findByBin(widget.initialBankBin);
    }
    _recipientBank ??= BankDeeplinkService.supportedBanks.first;

    // Ngân hàng gửi mặc định lấy từ Ví mặc định
    final defaultWallet = WalletService.getDefaultWallet();
    if (defaultWallet != null && defaultWallet.bankId != null) {
      _sendingBank = BankDeeplinkService.findById(defaultWallet.bankId);
    }
    _sendingBank ??= BankDeeplinkService.supportedBanks.first;

    // Khởi tạo danh mục
    final expenseCategories = _catBox.values
        .where((c) => c.effectiveTypeIndex == 0)
        .toList();
    if (expenseCategories.isNotEmpty) {
      _selectedCategory = expenseCategories.first;
    }

    // Load danh bạ người nhận
    _loadSavedPayees();

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

  void _applyPayee(SavedPayee payee) {
    HapticFeedback.selectionClick();
    setState(() {
      _accountNoController.text = payee.accountNo;
      _recipientBank = BankDeeplinkService.findByBin(payee.bankBin) ??
          _recipientBank;
      if (payee.defaultNote != null && payee.defaultNote!.isNotEmpty) {
        _noteController.text = payee.defaultNote!;
      }
      if (payee.defaultCategoryId != null) {
        try {
          _selectedCategory = _catBox.values.firstWhere(
            (c) => c.id == payee.defaultCategoryId,
          );
        } catch (_) {}
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
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = BankDeeplinkService.supportedBanks.where((b) {
              final q = searchQuery.toLowerCase();
              return b.shortName.toLowerCase().contains(q) ||
                  b.fullName.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: AppColors.getSurface(brightness),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SheepRadius.sheet),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: SheepSpacing.page,
                vertical: SheepSpacing.md,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getTextSecondary(brightness)
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: SheepSpacing.md),
                  Text(
                    'Chọn Ngân Hàng Thụ Hưởng',
                    style: SheepTextStyles.itemTitle(context).copyWith(
                      fontSize: SheepTypeScale.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SheepSpacing.md),
                  // Ô tìm kiếm ngân hàng
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Tìm ngân hàng (VCB, Techcombank, MB...)',
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
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: SheepSpacing.md),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final bank = filtered[index];
                        final isSelected = _recipientBank?.id == bank.id;

                        return ListTile(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _recipientBank = bank);
                            Navigator.pop(context);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SheepRadius.md),
                            side: BorderSide(
                              color: isSelected
                                  ? bank.brandColor
                                  : AppColors.getBorder(brightness),
                            ),
                          ),
                          tileColor: isSelected
                              ? bank.brandColor.withValues(alpha: 0.1)
                              : AppColors.getSurface(brightness),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: bank.brandColor.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(SheepRadius.sm),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              bank.shortName.substring(0, 3).toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: bank.brandColor,
                              ),
                            ),
                          ),
                          title: Text(
                            bank.shortName,
                            style: SheepTextStyles.itemTitle(context),
                          ),
                          subtitle: Text(
                            bank.fullName,
                            style: SheepTextStyles.itemMeta(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: bank.brandColor)
                              : null,
                        );
                      },
                    ),
                  ),
                ],
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

  Future<void> _handleConfirmTransfer() async {
    final accountNo = _accountNoController.text.trim();
    if (accountNo.length < 6) {
      SheepNotifications.showError(context, 'Số tài khoản không hợp lệ!');
      return;
    }

    final amount = _getParsedAmount();
    if (amount <= 0) {
      SheepNotifications.showError(context, 'Vui lòng nhập số tiền hợp lệ!');
      return;
    }

    if (_selectedCategory == null) {
      SheepNotifications.showError(context, 'Vui lòng chọn danh mục!');
      return;
    }

    final note = _noteController.text.trim().isNotEmpty
        ? _noteController.text.trim()
        : 'Chuyen tien';

    // 1. Lưu vào danh bạ nếu user chọn
    if (_savePayee && _recipientBank != null) {
      final nickname = _payeeNameController.text.trim().isNotEmpty
          ? _payeeNameController.text.trim()
          : (_recipientBank!.shortName);
      final payee = SavedPayee(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nickname: nickname,
        bankBin: _recipientBank!.bin,
        accountNo: accountNo,
        defaultCategoryId: _selectedCategory?.id,
        defaultNote: note,
        createdAt: DateTime.now(),
      );
      await _payeesBox.put(payee.id, payee.toJson());
    }

    // 2. Tạo chuỗi VietQR
    final qrPayload = VietQrParser.generateVietQr(
      bankBin: _recipientBank?.bin ?? '',
      bankAccount: accountNo,
      amount: amount,
      purpose: note,
    );

    final recipientName = _recipientBank?.shortName ?? 'Ngân hàng nhận';

    final isAutofill =
        _sendingBank != null && _sendingBank!.canAutofillPayment;

    // 1. Tạo bản ghi giao dịch Chờ xác nhận (Pending)
    await PendingTransferService.createPendingTransfer(
      amount: amount,
      note: note,
      categoryId: _selectedCategory!.id,
      sendingBankId: _sendingBank?.id,
      recipientBankBin: _recipientBank?.bin,
      recipientBankName: recipientName,
      accountNo: accountNo,
      qrPayload: qrPayload,
    );

    // 2. Lưu vào danh bạ nếu user chọn
    if (_savePayee && _recipientBank != null) {
      final nickname = _payeeNameController.text.trim().isNotEmpty
          ? _payeeNameController.text.trim()
          : (_recipientBank!.shortName);
      final payee = SavedPayee(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nickname: nickname,
        bankBin: _recipientBank!.bin,
        accountNo: accountNo,
        defaultCategoryId: _selectedCategory?.id,
        defaultNote: note,
        createdAt: DateTime.now(),
      );
      await _payeesBox.put(payee.id, payee.toJson());
    }

    // 3. Mở App ngân hàng qua Deeplink
    if (_sendingBank != null) {
      if (!isAutofill && accountNo.isNotEmpty) {
        try {
          await Clipboard.setData(ClipboardData(text: accountNo));
        } catch (_) {}
      }

      final launched = await BankDeeplinkService.launchBankApp(
        bank: _sendingBank!,
        qrPayload: qrPayload,
        accountNo: accountNo,
        recipientBin: _recipientBank?.bin,
        amount: amount,
        note: note,
      );

      if (!launched && mounted) {
        SheepNotifications.showError(
          context,
          'Không thể mở ứng dụng ${_sendingBank!.shortName}. Vui lòng kiểm tra app đã cài đặt trên máy chưa!',
        );
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      SheepNotifications.showSuccess(
        context,
        'Đã tạo giao dịch chờ xác nhận và mở ${_sendingBank?.shortName ?? 'ngân hàng'}.',
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
          'Chuyển tiền & Ghi sổ',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w700,
            fontSize: SheepTypeScale.title,
            color: AppColors.getTextPrimary(brightness),
          ),
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
                          fontFamily: 'Quicksand',
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
                title: 'NGƯỜI NHẬN THƯỜNG XUYÊN',
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
                                  fontFamily: 'Quicksand',
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
                                fontFamily: 'Quicksand',
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
                  // Chọn ngân hàng nhận
                  GestureDetector(
                    onTap: _showBankPicker,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getSubtleSurface(brightness),
                        borderRadius: BorderRadius.circular(SheepRadius.md),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: (_recipientBank?.brandColor ?? accentColor)
                                  .withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(SheepRadius.sm),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _recipientBank?.shortName
                                      .substring(0, 3)
                                      .toUpperCase() ??
                                  'BNK',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _recipientBank?.brandColor ?? accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NGÂN HÀNG THỤ HƯỞNG',
                                  style:
                                      SheepTextStyles.itemMeta(context).copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _recipientBank?.shortName ?? 'Chọn ngân hàng',
                                  style: SheepTextStyles.itemTitle(context),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.getTextSecondary(brightness),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: SheepSpacing.md),

                  // Số tài khoản người nhận + Nút Dán
                  TextField(
                    controller: _accountNoController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: SheepTypeScale.item,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.getTextPrimary(brightness),
                    ),
                    decoration: InputDecoration(
                      labelText: 'SỐ TÀI KHOẢN NHẬN',
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
                            fontFamily: 'Quicksand',
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
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: SheepTypeScale.headline,
                      fontWeight: FontWeight.w800,
                      color: AppColors.expense,
                    ),
                    decoration: InputDecoration(
                      labelText: 'SỐ TIỀN CHUYỂN',
                      labelStyle: SheepTextStyles.itemMeta(context).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: '0',
                      suffixText: '₫',
                      suffixStyle: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: SheepTypeScale.bodyLarge,
                        fontWeight: FontWeight.w800,
                        color: AppColors.expense,
                      ),
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
                            fontFamily: 'Quicksand',
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
                          fontFamily: 'Quicksand',
                          fontSize: SheepTypeScale.item,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(brightness),
                        ),
                        decoration: InputDecoration(
                          labelText: 'TÊN GỢI NHỚ (VD: Chủ nhà, Mẹ, Quỹ lớp...)',
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

            // Chọn ứng dụng thanh toán để chuyển (Bank Selector dạng dropdown / bottom sheet)
            BankAppSelectorTile(
              bank: _sendingBank,
              label: 'CHỌN APP NGÂN HÀNG ĐỂ CHUYỂN TIỀN',
              onTap: () {
                BankAppPickerModal.show(
                  context: context,
                  selectedBank: _sendingBank,
                  onBankSelected: (bank) {
                    setState(() => _sendingBank = bank);
                  },
                );
              },
            ),
            const SizedBox(height: SheepSpacing.xl),

            // Nút Chuyển tiền & Ghi sổ
            SheepButton(
              label: 'Chuyển tiền & Ghi sổ',
              isFullWidth: true,
              backgroundColor: accentColor,
              icon: const Icon(LineIcons.paperPlane, size: 20),
              onPressed: _handleConfirmTransfer,
            ),
          ],
        ),
      ),
    );
  }
}
