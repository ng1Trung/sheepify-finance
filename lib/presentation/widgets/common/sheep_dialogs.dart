import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n.dart';

class SheepConfirmDialog extends StatelessWidget {
  final String title;
  final String? content;
  final Widget? richContent;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final Color? confirmColor;
  final IconData? icon;

  const SheepConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.richContent,
    required this.onConfirm,
    this.confirmLabel = 'Xác nhận',
    this.cancelLabel = 'Huỷ',
    this.confirmColor,
    this.icon,
  }) : assert(content != null || richContent != null);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getSurface(brightness),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppColors.getSoftShadow(brightness),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (confirmColor ?? AppColors.expense).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? LineIcons.trash,
                color: confirmColor ?? AppColors.expense,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(brightness),
              ),
            ),
            const SizedBox(height: 12),

            // Content
            richContent ??
                Text(
                  content ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(brightness),
                    height: 1.5,
                  ),
                ),
            const SizedBox(height: 32),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: TextStyle(
                        color: AppColors.getTextSecondary(brightness),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor ?? AppColors.expense,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SheepGoalDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final Color color;
  final bool isSuccess;

  const SheepGoalDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel = 'Tuyệt vời!',
    required this.color,
    this.isSuccess = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getSurface(brightness),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppColors.getSoftShadow(brightness),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSuccess
                ? Lottie.asset(
                    'assets/confetti.json',
                    width: 200,
                    height: 200,
                    repeat: true,
                  )
                : Lottie.asset(
                    'assets/sad_wallet.json',
                    width: 200,
                    height: 200,
                    repeat: true,
                  ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(brightness),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextSecondary(brightness),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
