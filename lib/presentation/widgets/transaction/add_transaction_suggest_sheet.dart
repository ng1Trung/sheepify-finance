import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/transaction_image_store.dart';
import '../../../../data/models/settings_model.dart';
import '../../../../core/constants/constants.dart';
import '../../../../data/services/sheepify_scan_ai_service.dart';
import '../common/sheep_widgets.dart';
import '../common/sheep_notifications.dart';
import '../transaction_form.dart';
import 'voice_input_dialog.dart';

class AddTransactionSuggestSheet extends StatefulWidget {
  final DateTime? initialDate;

  const AddTransactionSuggestSheet({
    super.key,
    this.initialDate,
  });

  @override
  State<AddTransactionSuggestSheet> createState() => _AddTransactionSuggestSheetState();
}

class _AddTransactionSuggestSheetState extends State<AddTransactionSuggestSheet> {
  bool _isProcessingOCR = false;
  String _loadingMessage = 'Đang quét ảnh...';

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _isProcessingOCR = true;
        _loadingMessage = 'Đang nhận diện chữ và phân tích hóa đơn bằng AI...';
      });

      // 1. Chạy OCR và phân tích bằng Gemini
      final scannedResult = await SheepifyScanAIService.processInvoiceScan(pickedFile);

      if (!mounted) return;

      setState(() {
        _isProcessingOCR = false;
      });

      if (scannedResult == null) {
        SheepNotifications.showError(context, 'Không thể nhận diện hóa đơn. Hãy thử lại hoặc chụp ảnh rõ nét hơn!');
        return;
      }

      // 2. Lưu ảnh cục bộ vào bộ nhớ
      final storedImageRef = await TransactionImageStore.saveFromSourcePath(
        pickedFile.path,
      );

      // 3. Đóng bảng gợi ý này và mở TransactionForm với dữ liệu pre-fill
      if (mounted) {
        Navigator.pop(context); // Đóng Suggest Sheet
        
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
          // Trả kết quả ngày về MainScreen để cập nhật UI
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
    final settings = Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(theme.brightness),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(SheepRadius.sheet)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SheepSpacing.page,
          vertical: SheepSpacing.xl,
        ),
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
                child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
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
    // Đóng bàn phím nếu đang mở
    FocusScope.of(context).unfocus();

    // Mở VoiceInputDialog
    final result = await showModalBottomSheet<ScannedTransactionModel>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceInputDialog(),
    );

    if (result != null && mounted) {
      // Đóng Suggest Sheet
      Navigator.pop(context);

      // Mở Form với dữ liệu pre-fill
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
    Navigator.pop(context); // Đóng Suggest Sheet

    // Mở Form trống
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
    
    // Lấy tông màu chủ đạo
    final settings = Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
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
            vertical: SheepSpacing.xl,
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
              const SizedBox(height: 16),

              // ==========================================
              // VÙNG 1: PHƯƠNG THỨC THÔNG MINH (ƯU TIÊN)
              // ==========================================
              Row(
                children: [
                  // Nút 1: Quét hóa đơn
                  Expanded(
                    child: _buildSmartCard(
                      title: 'Scan tự động',
                      icon: Icons.qr_code_scanner_rounded,
                      color: accentColor,
                      description: 'AI tự phân tích từ ảnh quét',
                      onTap: _showScanSourceOptions,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nút 2: Nhập bằng giọng nói
                  Expanded(
                    child: _buildSmartCard(
                      title: 'Nhập bằng Giọng nói',
                      icon: Icons.mic_rounded,
                      color: accentColor,
                      description: 'Nói để AI ghi nhận',
                      onTap: _openVoiceInput,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 28),
              
              // ==========================================
              // VÙNG 2: PHƯƠNG THỨC THỦ CÔNG (PHỤ)
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextSecondary(theme.brightness),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // Loading Overlay
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
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

  Widget _buildSmartCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 172,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
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
