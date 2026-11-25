import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n.dart';
import 'sheep_widgets.dart';

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
    this.confirmLabel = '',
    this.cancelLabel = '',
    this.confirmColor,
    this.icon,
  }) : assert(content != null || richContent != null);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l10n = L10n.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SheepRadius.sheet),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(SheepSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.getSurface(brightness),
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
          boxShadow: AppColors.getSoftShadow(brightness),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Header
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.tint(confirmColor ?? AppColors.expense, brightness),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? LineIcons.trash,
                color: confirmColor ?? AppColors.expense,
                size: 26,
              ),
            ),
            const SizedBox(height: SheepSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SheepTextStyles.sheetTitle(context),
            ),
            const SizedBox(height: SheepSpacing.sm),
            richContent ??
                Text(
                  content ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SheepTypeScale.body,
                    color: AppColors.getTextSecondary(brightness),
                    height: 1.5,
                  ),
                ),
            const SizedBox(height: SheepSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: SheepButton(
                    label: cancelLabel.isEmpty ? l10n.cancel : cancelLabel,
                    variant: SheepButtonVariant.secondary,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: SheepSpacing.md),
                Expanded(
                  child: SheepButton(
                    label: confirmLabel.isEmpty ? l10n.confirm : confirmLabel,
                    backgroundColor: confirmColor ?? AppColors.expense,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      Navigator.pop(context, true);
                      onConfirm();
                    },
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
    this.buttonLabel = '',
    required this.color,
    this.isSuccess = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final l10n = L10n.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SheepRadius.sheet),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(SheepSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.getSurface(brightness),
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
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
              style: SheepTextStyles.sheetTitle(context),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: _parseHtmlToSpans(
                  message,
                  TextStyle(
                    fontSize: SheepTypeScale.item,
                    color: AppColors.getTextSecondary(brightness),
                    height: 1.5,
                  ),
                  TextStyle(
                    fontSize: SheepTypeScale.item,
                    color: AppColors.getTextPrimary(brightness),
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SheepSpacing.xl),
            SheepButton(
              label: buttonLabel.isEmpty ? l10n.get('awesome') : buttonLabel,
              isFullWidth: true,
              large: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _parseHtmlToSpans(
    String text,
    TextStyle normalStyle,
    TextStyle boldStyle,
  ) {
    final List<InlineSpan> spans = [];
    final RegExp regExp = RegExp(r'<b>(.*?)</b>');
    int lastIndex = 0;

    for (final RegExpMatch match in regExp.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: normalStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: boldStyle,
      ));
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: normalStyle,
      ));
    }
    if (spans.isEmpty && text.isNotEmpty) {
      spans.add(TextSpan(text: text, style: normalStyle));
    }
    return spans;
  }
}
