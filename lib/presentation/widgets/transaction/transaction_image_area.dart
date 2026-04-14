import 'dart:io';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';

class TransactionImageArea extends StatelessWidget {
  final String? imagePath;
  final bool isExpense;
  final CategoryModel? selectedCategory;
  final TextEditingController amountController;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onToggleType;
  final VoidCallback onShowCategoryPicker;

  const TransactionImageArea({
    super.key,
    required this.imagePath,
    required this.isExpense,
    required this.selectedCategory,
    required this.amountController,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onToggleType,
    required this.onShowCategoryPicker,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: imagePath != null
                  ? Image.file(File(imagePath!), fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[50],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LineIcons.image, size: 50, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          const Text(
                            'Chạm để thêm ảnh',
                            style: TextStyle(color: Colors.black26, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
            ),

            // Top row: Type and Category
            Positioned(
              top: 20,
              left: 30,
              right: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTypeToggle(),
                  _buildCategoryPicker(),
                ],
              ),
            ),

            // Bottom: Amount
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: _buildAmountInput(),
              ),
            ),

            if (imagePath != null)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onRemoveImage,
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return GestureDetector(
      onTap: onToggleType,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (isExpense ? AppColors.expense : AppColors.primary).withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isExpense ? 'Chi' : 'Thu',
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
    return GestureDetector(
      onTap: onShowCategoryPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (selectedCategory != null ? AppColors.primary : Colors.grey[400]!)
              .withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              selectedCategory != null ? selectedCategory!.iconData : LineIcons.tag,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              selectedCategory?.name ?? 'Danh mục',
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

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: IntrinsicWidth(
        child: TextField(
          controller: amountController,
          autofocus: true,
          showCursor: false,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isExpense ? const Color(0xFFFF6B6B) : const Color(0xFF20C997),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: '0',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixText: isExpense ? '- ' : '+ ',
            prefixStyle: TextStyle(
              color: isExpense ? const Color(0xFFFF6B6B) : const Color(0xFF20C997),
            ),
            suffixText: 'đ',
            suffixStyle: const TextStyle(fontSize: 16, color: Colors.white38),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ),
    );
  }
}
