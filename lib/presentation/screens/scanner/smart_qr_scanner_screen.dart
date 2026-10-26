import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:line_icons/line_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/vietqr_parser.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/transaction.dart';
import '../../widgets/common/sheep_notifications.dart';
import '../../widgets/common/sheep_widgets.dart';
import '../payment/quick_transfer_screen.dart';

class SmartQrScannerScreen extends StatefulWidget {
  const SmartQrScannerScreen({super.key});

  @override
  State<SmartQrScannerScreen> createState() => _SmartQrScannerScreenState();
}

class _SmartQrScannerScreenState extends State<SmartQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _cameraController;
  late final AnimationController _scanLineController;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(String rawValue) async {
    if (_isProcessing || !mounted) return;
    setState(() => _isProcessing = true);

    final parsed = VietQrParser.parse(rawValue);

    if (!parsed.isValid) {
      HapticFeedback.lightImpact();
      SheepNotifications.showError(
        context,
        'Mã QR không phải chuẩn thanh toán VietQR ngân hàng!',
      );
      // Đợi 2 giây trước khi cho quét lại
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    HapticFeedback.mediumImpact();
    await _cameraController.stop();

    if (!mounted) return;

    // Mở màn hình Chuyển tiền & Ghi sổ (dùng lại giao diện chuẩn QuickTransferScreen)
    final result = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(
        builder: (_) => QuickTransferScreen(
          initialBankBin: parsed.bankBin,
          initialAccountNo: parsed.bankAccount,
          initialAmount: parsed.amount,
          initialNote: parsed.purpose,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      // Người dùng đã hoàn thành chuyển tiền & ghi sổ -> Trả về kết quả cho màn hình trước
      Navigator.pop(context, result);
    } else {
      // Người dùng bấm back từ QuickTransferScreen mà chưa chuyển tiền -> Tiếp tục quét
      await _cameraController.start();
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final barcodeCapture =
          await _cameraController.analyzeImage(pickedFile.path);
      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        final rawValue = barcodeCapture.barcodes.first.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          await _handleBarcodeDetected(rawValue);
          return;
        }
      }

      if (mounted) {
        SheepNotifications.showError(
          context,
          'Không tìm thấy mã VietQR trong ảnh đã chọn!',
        );
      }
    } catch (e) {
      if (mounted) {
        SheepNotifications.showError(context, 'Lỗi đọc ảnh: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _toggleTorch() async {
    await _cameraController.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box<AppSettings>(kSettingsBox);
    final settings = settingsBox.get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    final screenSize = MediaQuery.of(context).size;
    final scanSize = screenSize.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _handleBarcodeDetected(raw);
                  break;
                }
              }
            },
          ),

          // Custom Darkened Overlay with Viewfinder
          Positioned.fill(
            child: _ViewfinderOverlay(
              scanSize: scanSize,
              borderColor: accentColor,
            ),
          ),

          // Animated Scan Line
          Center(
            child: SizedBox(
              width: scanSize - 20,
              height: scanSize - 20,
              child: AnimatedBuilder(
                animation: _scanLineController,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(
                      0,
                      (_scanLineController.value * 2) - 1.0,
                    ),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.1),
                            accentColor,
                            accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Top Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SheepSpacing.page,
                vertical: SheepSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nút Đóng
                  _CircularIconButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Tiêu đề
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(SheepRadius.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LineIcons.qrcode, color: accentColor, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Quét VietQR',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: SheepTypeScale.item,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nút bật đèn Flash
                  _CircularIconButton(
                    icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    iconColor: _isTorchOn ? Colors.yellow : Colors.white,
                    onPressed: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Instruction & Gallery Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Hướng camera vào mã VietQR để tự động ghi sổ & thanh toán',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: SheepTypeScale.label,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: SheepSpacing.lg),

                  // Nút Chọn ảnh từ Thư viện
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(SheepRadius.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LineIcons.image,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Chọn ảnh QR từ Thư viện',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: SheepTypeScale.label,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;

  const _CircularIconButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  final double scanSize;
  final Color borderColor;

  const _ViewfinderOverlay({
    required this.scanSize,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ViewfinderPainter(
        scanSize: scanSize,
        borderColor: borderColor,
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final double scanSize;
  final Color borderColor;

  _ViewfinderPainter({
    required this.scanSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55);

    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);
    final scanRRect =
        RRect.fromRectAndRadius(scanRect, const Radius.circular(SheepRadius.xl));

    // Vẽ nền mờ trừ ô quét
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Vẽ 4 góc bo của khung ngắm
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    const radius = SheepRadius.xl;

    // Góc trên bên trái
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + radius)
        ..arcToPoint(
          Offset(left + radius, top),
          radius: const Radius.circular(radius),
        )
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );

    // Góc trên bên phải
    final right = left + scanSize;
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, top)
        ..lineTo(right - radius, top)
        ..arcToPoint(
          Offset(right, top + radius),
          radius: const Radius.circular(radius),
        )
        ..lineTo(right, top + cornerLength),
      cornerPaint,
    );

    // Góc dưới bên trái
    final bottom = top + scanSize;
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cornerLength)
        ..lineTo(left, bottom - radius)
        ..arcToPoint(
          Offset(left + radius, bottom),
          radius: const Radius.circular(radius),
        )
        ..lineTo(left + cornerLength, bottom),
      cornerPaint,
    );

    // Góc dưới bên phải
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLength, bottom)
        ..lineTo(right - radius, bottom)
        ..arcToPoint(
          Offset(right, bottom - radius),
          radius: const Radius.circular(radius),
        )
        ..lineTo(right, bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.scanSize != scanSize;
}
