import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/transaction_image_store.dart';
import '../../../data/models/category_model.dart';
import '../common/sheep_widgets.dart';

class TransactionImageArea extends StatelessWidget {
  final String? imagePath;
  final bool isExpense;
  final int selectedIndex; // NEW
  final CategoryModel? selectedCategory;
  final Color? categoryColor;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onShowCategoryPicker;

  const TransactionImageArea({
    super.key,
    required this.imagePath,
    required this.isExpense,
    required this.selectedIndex,
    required this.selectedCategory,
    this.categoryColor,
    required this.amountController,
    required this.noteController,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onShowCategoryPicker,
  });

  @override
  Widget build(BuildContext context) {
    final hasCategory = selectedCategory != null;
    final imageFile = TransactionImageStore.resolve(imagePath);
    final hasReadableImage = imageFile?.existsSync() ?? false;
    final l10n = L10n.of(context);

    return AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.getBackground(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // BACKGROUND (IMAGE OR GRADIENT)
            GestureDetector(
              onTap: onPickImage,
              child: hasReadableImage
                  ? Image.file(
                      imageFile!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(hasCategory),
                    )
                  : _buildPlaceholder(hasCategory),
            ),

            // Header UI
            Positioned(
              top: SheepSpacing.xl,
              left: SheepSpacing.xl,
              right: SheepSpacing.xl,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildCategoryPicker(l10n),
              ),
            ),

            // Action Block (Amount input and Note field)
            Positioned(
              bottom: SheepSpacing.xl,
              left: SheepSpacing.xl,
              right: SheepSpacing.xl,
              child: _buildActionBlock(l10n),
            ),

            // Delete Image Button
            if (hasReadableImage)
              Positioned(
                top: SheepSpacing.xl,
                right: SheepSpacing.xl,
                child: GestureDetector(
                  onTap: onRemoveImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
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
                    ? [categoryColor!, categoryColor!.withOpacity(0.7)]
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
          padding: const EdgeInsets.only(bottom: 64),
          child: hasCategory
              ? SheepCategoryIcon(
                  icon: selectedCategory!.iconData,
                  color: Colors.white,
                  size: 64,
                )
              : const Icon(LineIcons.image, size: 46, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildActionBlock(L10n l10n) {
    final bool isZeroValue = amountController.text.isEmpty;
    final bool hasCategory = selectedCategory != null;
    final typeVisuals = SheepTransactionTypeVisuals.fromTypeIndex(
      selectedIndex,
    );

    // Keep the amount state neutral until a category is selected.
    Color contentColor;
    if (!hasCategory) {
      contentColor = isZeroValue ? Colors.white24 : Colors.white;
    } else {
      final typeColor = typeVisuals.color;
      contentColor = isZeroValue ? typeColor.withOpacity(0.45) : typeColor;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(SheepRadius.sheet),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AMOUNT INPUT SECTION
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasCategory) ...[
                  Icon(typeVisuals.icon, color: contentColor, size: 30),
                  const SizedBox(width: 16),
                ],
                IntrinsicWidth(
                  child: TextField(
                    controller: amountController,
                    autofocus: false,
                    showCursor: false,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                      hintStyle: const TextStyle(color: Colors.white24),
                    ),
                    inputFormatters: [CurrencyInputFormatter()],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'đ',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: l10n.get('add_note'),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.32)),
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
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(L10n l10n) {
    bool hasCat = selectedCategory != null;
    return GestureDetector(
      onTap: onShowCategoryPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              (categoryColor ??
                      (hasCat ? AppColors.primary : Colors.grey[400]!))
                  .withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasCat
                  ? selectedCategory!.name
                  : l10n.get('category_placeholder'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
