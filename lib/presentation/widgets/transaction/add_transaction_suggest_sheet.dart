import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:line_icons/line_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/transaction_image_store.dart';
import '../../../../data/models/settings_model.dart';
import '../../../../core/constants/constants.dart';
import '../../../../data/models/transaction.dart';
import '../../../../data/services/sheepify_scan_ai_service.dart';
import '../../screens/payment/quick_transfer_screen.dart';
import '../../screens/scanner/smart_qr_scanner_screen.dart';
import '../common/sheep_widgets.dart';
import '../common/sheep_notifications.dart';
import '../transaction_form.dart';
import 'voice_input_dialog.dart';

class AddTransactionSuggestSheet extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<Transaction>? onTransactionCreated;

  const AddTransactionSuggestSheet({
    super.key,
    this.initialDate,
    this.onTransactionCreated,
  });

  @override
  State<AddTransactionSuggestSheet> createState() =>
      _AddTransactionSuggestSheetState();
}

class _AddTransactionSuggestSheetState
    extends State<AddTransactionSuggestSheet> {
  bool _isProcessingOCR = false;
  String _loadingMessage = 'Đang quét ảnh...';

  Future<void> _openVietQrScanner() async {
    Navigator.pop(context); // Đóng Suggest Sheet
    final transaction = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(builder: (_) => const SmartQrScannerScreen()),
    );
    if (transaction != null && mounted) {
      widget.onTransactionCreated?.call(transaction);
    }
  }

  Future<void> _openQuickTransfer() async {
    Navigator.pop(context); // Đóng Suggest Sheet
    final transaction = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(builder: (_) => const QuickTransferScreen()),
    );
    if (transaction != null && mounted) {
      widget.onTransactionCreated?.call(transaction);
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _isProcessingOCR = true;
        _loadingMessage =
            'Đang nhận diện chữ và phân tích hóa đơn bằng AI...';
      });

      // 1. Chạy OCR và phân tích bằng Gemini
      final scannedResult =
          await SheepifyScanAIService.processInvoiceScan(pickedFile);

      if (!mounted) return;

      setState(() {
        _isProcessingOCR = false;
      });

      if (scannedResult == null) {
        SheepNotifications.showError(
          context,
          'Không thể nhận diện hóa đơn. Hãy thử lại hoặc chụp ảnh rõ nét hơn!',
        );
        return;
      }

      // 2. Lưu ảnh cục bộ vào bộ nhớ
      final storedImageRef =
          await TransactionImageStore.saveFromSourcePath(
        pickedFile.path,
      );

      // 3. Đóng bảng gợi ý này và mở TransactionForm với dữ liệu pre-fill
      if (mounted) {
        Navigator.pop(context);

        // Mở Form
        final resultDate = await showModalBottomSheet<DateTime>(
          context: context,
          isScrollControlled: true,
          isDismissible: true,
          enableDrag: true,
          builder: (_) => TransactionForm(
            initialDate: widget.initialDate ?? DateTime.now(),
            scannedData: scannedResult,
            scannedImagePath: storedImageRef,
          ),
        );

        if (resultDate != null && mounted) {
          Navigator.pop(context, resultDate);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingOCR = false;
        });
        SheepNotifications.showError(context, 'Lỗi xử lý ảnh: $e');
      }
    }
  }

  Future<void> _showScanSourceOptions() async {
    final theme = Theme.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(theme.brightness),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SheepRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(SheepRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chọn nguồn ảnh quét hóa đơn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SheepTypeScale.title,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(theme.brightness),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_rounded, color: accentColor),
              ),
              title: Text(
                'Mở camera chụp ảnh',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(theme.brightness),
                ),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.purple,
                ),
              ),
              title: Text(
                'Chọn từ thư viện ảnh',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(theme.brightness),
                ),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source != null) {
      _pickAndProcessImage(source);
    }
  }

  Future<void> _openVoiceInput() async {
    FocusScope.of(context).unfocus();

    final result = await showModalBottomSheet<ScannedTransactionModel>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceInputDialog(),
    );

    if (result != null && mounted) {
      Navigator.pop(context);

      final resultDate = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        builder: (_) => TransactionForm(
          initialDate: widget.initialDate ?? DateTime.now(),
          scannedData: result,
        ),
      );

      if (resultDate != null && mounted) {
        Navigator.pop(context, resultDate);
      }
    }
  }

  void _openManualForm() {
    Navigator.pop(context);

    showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => TransactionForm(
        initialDate: widget.initialDate ?? DateTime.now(),
      ),
    ).then((resultDate) {
      if (resultDate != null && mounted) {
        Navigator.pop(context, resultDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(theme.brightness),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SheepRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SheepSpacing.page,
            vertical: SheepSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(SheepRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: SheepSpacing.md),

              // ==========================================
              // VÙNG 1: THANH TOÁN & GHI SỔ TỰ ĐỘNG
              // ==========================================
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'THANH TOÁN & GHI SỔ TỰ ĐỘNG',
                    style: SheepTextStyles.itemMeta(context).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: SheepTypeScale.micro,
                      letterSpacing: 0.5,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Nút 1: Quét VietQR
                  Expanded(
                    child: _buildActionCard(
                      title: 'Quét VietQR',
                      icon: LineIcons.qrcode,
                      color: accentColor,
                      description: 'Mở app ngân hàng FaceID thanh toán & tự ghi sổ',
                      badge: 'Siêu tốc',
                      onTap: _openVietQrScanner,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Nút 2: Chuyển khoản
                  Expanded(
                    child: _buildActionCard(
                      title: 'Chuyển tiền',
                      icon: LineIcons.paperPlane,
                      color: const Color(0xFF4EA8DE),
                      description: 'Chuyển theo STK hoặc Danh bạ đã lưu',
                      onTap: _openQuickTransfer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SheepSpacing.lg),

              // ==========================================
              // VÙNG 2: GHI CHÉP THÔNG MINH
              // ==========================================
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.getTextSecondary(theme.brightness),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'GHI CHÉP THÔNG MINH KHÔNG THANH TOÁN',
                    style: SheepTextStyles.itemMeta(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: SheepTypeScale.micro,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Nút 3: Scan hóa đơn
                  Expanded(
                    child: _buildSecondaryCard(
                      title: 'Scan hóa đơn',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFFFF9E7D),
                      onTap: _showScanSourceOptions,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Nút 4: Giọng nói
                  Expanded(
                    child: _buildSecondaryCard(
                      title: 'Nói ghi chép',
                      icon: Icons.mic_rounded,
                      color: const Color(0xFFB79CED),
                      onTap: _openVoiceInput,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SheepSpacing.md),

              // ==========================================
              // VÙNG 3: PHƯƠNG THỨC THỦ CÔNG
              // ==========================================
              Center(
                child: TextButton.icon(
                  onPressed: _openManualForm,
                  icon: Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.getTextSecondary(theme.brightness),
                    size: 20,
                  ),
                  label: Text(
                    'Hoặc nhập thủ công bằng tay ✏️',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextSecondary(theme.brightness),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading Overlay khi chạy OCR
        if (_isProcessingOCR)
          Positioned.fill(
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
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: SheepTypeScale.body,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(theme.brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 145,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(SheepRadius.lg),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SheepRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius:
                              BorderRadius.circular(SheepRadius.pill),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SheepRadius.md),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SheepRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
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
}
