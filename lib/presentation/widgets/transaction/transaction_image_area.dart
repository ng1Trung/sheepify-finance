import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';
import 'package:intl/intl.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final hasCategory = selectedCategory != null;
    final imageFile = TransactionImageStore.resolve(imagePath);
    final hasReadableImage = imageFile?.existsSync() ?? false;
    final l10n = L10n.of(context);

    return AspectRatio(
      aspectRatio: 1,
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
            hasReadableImage
                ? Image.file(
                    imageFile!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholder(hasCategory),
                  )
                : _buildPlaceholder(hasCategory),
            if (isActive) ...[
              Positioned.fill(
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
              Positioned(
                bottom: SheepSpacing.xl,
                left: SheepSpacing.xl,
                right: SheepSpacing.xl,
                child: _buildActionBlock(context, l10n),
              ),
              if (hasReadableImage)
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

  Widget _buildPlaceholder(bool hasCategory) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: !hasCategory
              ? [const Color(0xFFBDBDBD), const Color(0xFF757575)]
              : (categoryColor != null
                    ? [categoryColor!, categoryColor!.withValues(alpha: 0.72)]
                    : (selectedIndex == 0
                          ? [const Color(0xFFC62828), const Color(0xFF8E24AA)]
                          : (selectedIndex == 1
                                ? [
                                    const Color(0xFF2E7D32),
                                    const Color(0xFF00ACC1),
                                  ]
                                : [
                                    const Color(0xFF1976D2),
                                    const Color(0xFF00BCD4),
                                  ]))),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 58),
          child: hasCategory
              ? SheepCategoryIcon(
                  icon: selectedCategory!.iconData,
                  color: Colors.white,
                  size: 64,
                  imagePath: selectedCategory!.imagePath,
                )
              : const Icon(LineIcons.image, size: 46, color: Colors.white),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(SheepRadius.sheet),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (date != null) ...[
            const SizedBox(height: 6),
            Text(
              DateFormat('HH:mm').format(date!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Padding(
            padding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasCategory) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      typeVisuals.icon,
                      color: contentColor,
                      size: 30,
                    ),
                  ),
                ],
                Center(
                  child: IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: TextField(
                        controller: amountController,
                        autofocus: false,
                        showCursor: false,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: contentColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: '0',
                          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white38,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        inputFormatters: [CurrencyInputFormatter()],
                      ),
                    ),
                  ),
                ),
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
