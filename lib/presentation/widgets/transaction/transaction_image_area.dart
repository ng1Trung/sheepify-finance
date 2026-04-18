import 'dart:io';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/category_model.dart';

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
  final Function(int) onToggleType; // CHANGED to accept index
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
    required this.onToggleType,
    required this.onShowCategoryPicker,
  });

  @override
  Widget build(BuildContext context) {
    bool hasCategory = selectedCategory != null;

    return AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.getBackground(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(35),
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
              child: imagePath != null
                  ? Image.file(File(imagePath!), fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: !hasCategory
                                ? [const Color(0xFFBDBDBD), const Color(0xFF757575)]
                              : (categoryColor != null
                                  ? [
                                      categoryColor!,
                                      categoryColor!.withOpacity(0.7),
                                    ]
                                  : (selectedIndex == 0
                                      ? [const Color(0xFFC62828), const Color(0xFF8E24AA)]
                                      : (selectedIndex == 1 
                                          ? [const Color(0xFF2E7D32), const Color(0xFF00ACC1)]
                                          : [const Color(0xFF1976D2), const Color(0xFF00BCD4)]))),
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selectedCategory?.iconData ?? LineIcons.image,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            // Header UI (Category and Type toggle)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategoryPicker(),
                  if (hasCategory) _buildTypeToggle(),
                ],
              ),
            ),

            // Action Block (Amount input and Note field)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildActionBlock(),
            ),

            // Delete Image Button
            if (imagePath != null)
              Positioned(
                top: 15,
                right: 15,
                child: GestureDetector(
                  onTap: onRemoveImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBlock() {
    final bool isZeroValue = amountController.text.isEmpty;
    final bool hasCategory = selectedCategory != null;
    
    // COLOR LOGIC: Strictly white until a category is selected to avoid misleading red/green colors
    Color contentColor;
    if (!hasCategory) {
      contentColor = isZeroValue ? Colors.white24 : Colors.white;
    } else {
      contentColor = isZeroValue
          ? Colors.white24
          : (selectedIndex == 0 
              ? const Color(0xFFFF8A80) 
              : (selectedIndex == 1 ? const Color(0xFFB9F6CA) : const Color(0xFFBBDEFB)));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AMOUNT INPUT SECTION
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  selectedIndex == 0 ? '-' : (selectedIndex == 1 ? '+' : '±'),
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                IntrinsicWidth(
                  child: TextField(
                    controller: amountController,
                    autofocus: true,
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

          // NOTE INPUT SECTION
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Icon(
                  LineIcons.edit,
                  size: 16,
                  color: Colors.white.withOpacity(0.4),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Add details...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(width: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    String label;
    Color color;
    switch (selectedIndex) {
      case 0: label = 'Chi tiêu'; color = AppColors.expense; break;
      case 1: label = 'Thu nhập'; color = AppColors.income; break;
      default: label = 'Mục tiêu'; color = AppColors.savings; break;
    }

    return GestureDetector(
      onTap: () => onToggleType((selectedIndex + 1) % 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    bool hasCat = selectedCategory != null;
    return GestureDetector(
      onTap: onShowCategoryPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (categoryColor ?? (hasCat ? AppColors.primary : Colors.grey[400]!))
              .withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasCat ? selectedCategory!.name : 'Category',
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
