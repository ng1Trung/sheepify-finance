import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/services/bank_deeplink_service.dart';
import '../common/sheep_notifications.dart';
import '../common/sheep_widgets.dart';

/// Sheet trợ lý chuyển khoản dành cho các giao dịch ngân hàng ở trạng thái Chờ xác nhận (Pending).
/// Số dư ví CHƯA bị trừ. Người dùng quay lại đây sau khi thao tác trong app ngân hàng
/// để bấm "Đã chuyển thành công" (lúc này mới trừ tiền ví) hoặc "Chưa chuyển / Hủy".
class PaymentTransferAssistantSheet extends StatefulWidget {
  final BankAppModel sendingBank;
  final String recipientBankName;
  final String accountNo;
  final double amount;
  final String note;
  final String qrPayload;
  final String? pendingId;
  final VoidCallback onConfirmed;
  final VoidCallback onCancelled;
  final VoidCallback onReopenApp;

  const PaymentTransferAssistantSheet({
    super.key,
    required this.sendingBank,
    required this.recipientBankName,
    required this.accountNo,
    required this.amount,
    required this.note,
    required this.qrPayload,
    this.pendingId,
    required this.onConfirmed,
    required this.onCancelled,
    required this.onReopenApp,
  });

  @override
  State<PaymentTransferAssistantSheet> createState() =>
      _PaymentTransferAssistantSheetState();
}

class _PaymentTransferAssistantSheetState
    extends State<PaymentTransferAssistantSheet> {
  String? _recentlyCopiedKey;

  void _copyToClipboard(String key, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    setState(() => _recentlyCopiedKey = key);
    SheepNotifications.showSuccess(context, 'Đã sao chép $label: $text');

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _recentlyCopiedKey == key) {
        setState(() => _recentlyCopiedKey = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final settings = Hive.box<AppSettings>(kSettingsBox).get('current') ??
        AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final brandColor = widget.sendingBank.brandColor;

    final formattedAmount =
        '${CurrencyUtil.formatMoney(widget.amount, locale: 'vi_VN')}₫';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: SheepSpacing.sm,
        left: SheepSpacing.page,
        right: SheepSpacing.page,
        bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: SheepSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.getBorder(brightness),
                    borderRadius: BorderRadius.circular(SheepRadius.pill),
                  ),
                ),
              ),

              // Header với logo & trạng thái Chờ xác nhận
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: brandColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: widget.sendingBank.logoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              widget.sendingBank.logoUrl!,
                              width: 32,
                              height: 32,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.account_balance,
                                color: brandColor,
                                size: 22,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.account_balance,
                            color: brandColor,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: SheepSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã mở ${widget.sendingBank.shortName}',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Chờ xác nhận • Số dư ví chưa bị trừ',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SheepSpacing.md),

              // Banner Hướng Dẫn: giải thích rõ ràng và nhắc nhở
              Container(
                padding: const EdgeInsets.all(SheepSpacing.md),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(SheepRadius.md),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFBFDBFE),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: SheepSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hướng dẫn thao tác:',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1. STK đã được tự động copy, bạn chỉ cần chọn "Dán" trong ${widget.sendingBank.shortName}.\n'
                            '2. Sau khi chuyển tiền xong xuôi, hãy bấm "Đã chuyển thành công" bên dưới để trừ số dư ví và lưu sổ chi tiêu.',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 12.5,
                              height: 1.4,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SheepSpacing.md),

              // Danh thiếp thông tin chuyển tiền kèm các nút copy 1-chạm
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242424)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(SheepRadius.md),
                  border: Border.all(
                    color: AppColors.getBorder(brightness),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      context: context,
                      brightness: brightness,
                      title: 'Số tài khoản nhận',
                      value: widget.accountNo,
                      subtitle: widget.recipientBankName,
                      copyKey: 'stk',
                      copyValue: widget.accountNo,
                      copyLabel: 'Số tài khoản',
                      brandColor: brandColor,
                      showDivider: true,
                    ),
                    _buildInfoRow(
                      context: context,
                      brightness: brightness,
                      title: 'Số tiền',
                      value: formattedAmount,
                      copyKey: 'amount',
                      copyValue: widget.amount.toInt().toString(),
                      copyLabel: 'Số tiền',
                      brandColor: brandColor,
                      valueColor: palette.primary,
                      showDivider: true,
                    ),
                    _buildInfoRow(
                      context: context,
                      brightness: brightness,
                      title: 'Nội dung chuyển tiền',
                      value: widget.note,
                      copyKey: 'note',
                      copyValue: widget.note,
                      copyLabel: 'Nội dung',
                      brandColor: brandColor,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SheepSpacing.lg),

              // Nút hành động chính: Xác nhận thành công
              ElevatedButton.icon(
                onPressed: widget.onConfirmed,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'Tôi đã chuyển tiền thành công',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A86B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: SheepSpacing.sm),

              // Hai nút phụ: Mở lại app & Hủy giao dịch
              Row(
                children: [
                  // Nút mở lại App ngân hàng
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onReopenApp,
                      icon: Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: brandColor,
                      ),
                      label: Text(
                        'Mở lại app',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: brandColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: brandColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SheepSpacing.sm),

                  // Nút Hủy / Chưa chuyển
                  Expanded(
                    child: TextButton.icon(
                      onPressed: widget.onCancelled,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      label: const Text(
                        'Chưa chuyển / Hủy',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required Brightness brightness,
    required String title,
    required String value,
    String? subtitle,
    required String copyKey,
    required String copyValue,
    required String copyLabel,
    required Color brandColor,
    Color? valueColor,
    required bool showDivider,
  }) {
    final isCopied = _recentlyCopiedKey == copyKey;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(SheepSpacing.sm + 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextSecondary(brightness),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: valueColor ??
                                  AppColors.getTextPrimary(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.getSurface(brightness),
                              borderRadius: BorderRadius.circular(SheepRadius.sm),
                              border: Border.all(
                                color: AppColors.getBorder(brightness),
                              ),
                            ),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextSecondary(brightness),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SheepSpacing.sm),
              Material(
                color: isCopied
                    ? const Color(0xFF00A86B).withValues(alpha: 0.12)
                    : AppColors.getSurface(brightness),
                borderRadius: BorderRadius.circular(SheepRadius.sm),
                child: InkWell(
                  onTap: () => _copyToClipboard(copyKey, copyValue, copyLabel),
                  borderRadius: BorderRadius.circular(SheepRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SheepRadius.sm),
                      border: Border.all(
                        color: isCopied
                            ? const Color(0xFF00A86B)
                            : AppColors.getBorder(brightness),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCopied ? Icons.check : Icons.copy_rounded,
                          size: 14,
                          color: isCopied
                              ? const Color(0xFF00A86B)
                              : AppColors.getTextSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCopied ? 'Đã chép' : 'Sao chép',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCopied
                                ? const Color(0xFF00A86B)
                                : AppColors.getTextSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.getBorder(brightness),
          ),
      ],
    );
  }
}
