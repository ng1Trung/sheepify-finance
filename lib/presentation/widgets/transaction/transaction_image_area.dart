import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/transaction_image_store.dart';
import '../../../data/models/category_model.dart';
import '../common/sheep_widgets.dart';

class TransactionImageArea extends StatelessWidget {
  final String? imagePath;
  final int selectedIndex;
  final CategoryModel? selectedCategory;
  final Color? categoryColor;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final VoidCallback onRemoveImage;
  final Animation<double> noteShakeAnimation;
  final int noteMaxLength;
  final VoidCallback onNoteLimitExceeded;
  final DateTime? date;
  final bool isActive;
  final FocusNode? amountFocusNode;
  final bool autofocusAmount;

  /// Use a shorter, wider card when no photo is attached so the amount
  /// field isn't pushed down by an empty placeholder.
  final bool compact;

  const TransactionImageArea({
    super.key,
    required this.imagePath,
    required this.selectedIndex,
    required this.selectedCategory,
    this.categoryColor,
    required this.amountController,
    required this.noteController,
    required this.onRemoveImage,
    required this.noteShakeAnimation,
    required this.noteMaxLength,
    required this.onNoteLimitExceeded,
    this.date,
    this.isActive = true,
    this.amountFocusNode,
    this.autofocusAmount = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasCategory = selectedCategory != null;
    final imageFile = TransactionImageStore.resolve(imagePath);
    final validImageFile = (imageFile != null && imageFile.existsSync()) ? imageFile : null;
    final l10n = L10n.of(context);

    final useCompact = compact && validImageFile == null;

    return AspectRatio(
      aspectRatio: useCompact ? 1.45 : 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.getBackground(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            validImageFile != null
                ? GestureDetector(
                    onTap: () => _showFullScreenImage(context, validImageFile),
                    child: Image.file(
                      validImageFile,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(hasCategory, useCompact),
                    ),
                  )
                : _buildPlaceholder(hasCategory, useCompact),
            if (isActive) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.03),
                          Colors.black.withValues(alpha: 0.34),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: _buildActionBlock(context, l10n),
              ),
              if (validImageFile != null)
                Positioned(
                  top: SheepSpacing.lg,
                  right: SheepSpacing.lg,
                  child: GestureDetector(
                    onTap: onRemoveImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.expense,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool hasCategory, bool useCompact) {
    return Container(
      decoration: BoxDecoration(
        // Flat colour: the selected category's colour, or neutral grey
        // until a category is picked.
        color: !hasCategory
            ? const Color(0xFF6B6B6B)
            : (categoryColor ??
                  SheepTransactionTypeVisuals.fromTypeIndex(selectedIndex).color),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: useCompact ? 104 : 58),
          child: hasCategory
              ? SheepCategoryIcon(
                  icon: selectedCategory!.iconData,
                  color: Colors.white,
                  size: useCompact ? 44 : 64,
                  imagePath: selectedCategory!.imagePath,
                )
              : Icon(
                  LineIcons.image,
                  size: useCompact ? 36 : 46,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  Widget _buildActionBlock(BuildContext context, L10n l10n) {
    final isZeroValue = amountController.text.isEmpty;
    final hasCategory = selectedCategory != null;
    final typeVisuals = SheepTransactionTypeVisuals.fromTypeIndex(
      selectedIndex,
    );

    Color contentColor;
    if (!hasCategory) {
      contentColor = isZeroValue ? Colors.white38 : Colors.white;
    } else {
      final typeColor = typeVisuals.color;
      contentColor = isZeroValue ? typeColor.withValues(alpha: 0.5) : typeColor;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(SheepRadius.sheet),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(SheepRadius.sheet),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasCategory) ...[
                  Icon(
                    typeVisuals.icon,
                    color: contentColor,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: TextField(
                    controller: amountController,
                    focusNode: amountFocusNode,
                    autofocus: autofocusAmount,
                    showCursor: true,
                    cursorColor: Colors.white,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: contentColor,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: '0',
                      hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white38,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    inputFormatters: [CurrencyInputFormatter()],
                  ),
                ),
                if (hasCategory) ...[
                  const SizedBox(width: 28),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          AnimatedBuilder(
            animation: noteShakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(noteShakeAnimation.value, 0),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SheepRadius.xl),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: TextField(
                controller: noteController,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                minLines: 1,
                maxLines: 2,
                inputFormatters: [
                  _NoteLimitFormatter(
                    maxLength: noteMaxLength,
                    onExceeded: onNoteLimitExceeded,
                  ),
                ],
                decoration: InputDecoration(
                  hintText: l10n.get('add_note'),
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  void _showFullScreenImage(BuildContext context, File file) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(file),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteLimitFormatter extends TextInputFormatter {
  final int maxLength;
  final VoidCallback onExceeded;

  const _NoteLimitFormatter({
    required this.maxLength,
    required this.onExceeded,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.characters.length <= maxLength) {
      return newValue;
    }
    onExceeded();
    return oldValue;
  }
}
