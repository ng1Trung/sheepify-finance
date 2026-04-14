import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../core/theme/app_colors.dart';
import 'common/sheep_widgets.dart';

class TransactionForm extends StatefulWidget {
  final Transaction? transaction;
  final DateTime? initialDate;

  const TransactionForm({super.key, this.transaction, this.initialDate});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

  late DateTime _selectedDate;
  late bool _isExpense;

  String? _selectedParentId;
  String? _selectedChildId;
  String? _imagePath;

  final _box = Hive.box<Transaction>(kMoneyBox);
  final _catBox = Hive.box<CategoryModel>(kCatBox);

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _noteController.text = tx.note;
      _selectedDate = tx.date;
      _isExpense = tx.isExpense;
      _selectedChildId = tx.categoryId;
      _imagePath = tx.imagePath;

      try {
        final child = _catBox.values.firstWhere(
          (c) => c.id == _selectedChildId,
        );
        _selectedParentId = child.parentId;
      } catch (_) {}
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _isExpense = true;
      _imagePath = null;
    }

    _amountController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'TẢI LÊN ẢNH',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
            ),
          ),
          ListTile(
            leading: const Icon(LineIcons.camera, color: AppColors.primary),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(LineIcons.image, color: AppColors.primary),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(pickedFile.path)}';
        final savedImage = await File(
          pickedFile.path,
        ).copy('${appDir.path}/$fileName');
        setState(() => _imagePath = savedImage.path);
      }
    }
  }

  void _submit() {
    if (_amountController.text.isEmpty || _selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền và chọn danh mục!'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final enteredAmount = double.tryParse(_amountController.text) ?? 0;
    if (enteredAmount <= 0) return;

    HapticFeedback.mediumImpact();

    try {
      if (widget.transaction != null) {
        final tx = widget.transaction!;
        tx.amount = enteredAmount;
        tx.note = _noteController.text;
        tx.date = _selectedDate;
        tx.isExpense = _isExpense;
        tx.categoryId = _selectedChildId!;
        tx.imagePath = _imagePath;
        tx.save();
      } else {
        final newTx = Transaction(
          note: _noteController.text,
          amount: enteredAmount,
          date: _selectedDate,
          isExpense: _isExpense,
          categoryId: _selectedChildId!,
          imagePath: _imagePath,
        );
        _box.add(newTx);
      }
      Navigator.of(context).pop(_selectedDate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.expense),
      );
    }
  }

  void _showParentPicker() {
    // Show both income and expense parents
    final parentCats = _catBox.values.where((c) => c.parentId == null).toList();

    // Group by type for clarity
    final expenseParents = parentCats.where((c) => c.isExpense).toList();
    final incomeParents = parentCats.where((c) => !c.isExpense).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'CHỌN NHÓM CHÍNH',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            const SizedBox(height: 20),
            if (expenseParents.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'Chi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: expenseParents
                    .map((p) => _categoryChip(p, ctx))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (incomeParents.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'Thu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: incomeParents
                    .map((p) => _categoryChip(p, ctx))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(CategoryModel p, BuildContext ctx) {
    final isSelected = _selectedParentId == p.id;
    return ChoiceChip(
      label: Text(p.name),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _selectedParentId = p.id;
            _isExpense = p.isExpense; // Sync type with selection
            _selectedChildId = null;
          });
          Navigator.pop(ctx);
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontSize: 13,
      ),
    );
  }

  void _showChildPicker() {
    final childCats = _catBox.values
        .where((c) => c.parentId == _selectedParentId)
        .toList();
    if (childCats.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CHỌN DANH MỤC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              itemCount: childCats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (ctx, i) {
                final c = childCats[i];
                final isSelected = _selectedChildId == c.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedChildId = c.id);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only auto-sync child if parent is selected and child is null
    CategoryModel? currentChild;
    if (_selectedChildId != null) {
      try {
        currentChild = _catBox.values.firstWhere(
          (c) => c.id == _selectedChildId,
        );
      } catch (_) {}
    }

    final currentParent = _selectedParentId != null
        ? _catBox.values.firstWhere((c) => c.id == _selectedParentId)
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface, // BACK TO LIGHT MODE
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(
          context,
        ).viewInsets.bottom, // PADDING BOTTOM 0 AS REQUESTED
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- HEADER: DATE PILL ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat(
                      'dd MMMM, yyyy - HH:mm',
                      'vi',
                    ).format(_selectedDate),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SQUARE CAPTURE AREA (1:1 Aspect Ratio) ---
            AspectRatio(
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
                    // Background Image or Placeholder
                    GestureDetector(
                      onTap: _pickImage,
                      child: _imagePath != null
                          ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey[50],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LineIcons.image,
                                    size: 50,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Chạm để thêm ảnh',
                                    style: TextStyle(
                                      color: Colors.black26,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    // TOP OVERLAY ROW: PARENT & TYPE
                    Positioned(
                      top: 20,
                      left: 30,
                      right: 30,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Parent Category Pill
                          GestureDetector(
                            onTap: _showParentPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (currentParent != null
                                            ? AppColors.primary
                                            : Colors.grey[400]!)
                                        .withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    currentParent != null
                                        ? IconData(
                                            currentParent.iconCode,
                                            fontFamily: 'MaterialIcons',
                                          )
                                        : LineIcons.tag,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentParent?.name ?? 'Danh mục cha',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Type Toggle Pill (Thu/Chi)
                          if (currentParent != null)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _isExpense = !_isExpense;
                                  _selectedParentId = null;
                                  _selectedChildId = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_isExpense
                                              ? AppColors.expense
                                              : AppColors.primary)
                                          .withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _isExpense ? 'Chi' : 'Thu',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --- BOTTOM OVERLAY: AMOUNT & CHILD CAT ---
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white10,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _amountController,
                                  autofocus: true,
                                  showCursor: false,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isExpense
                                        ? const Color(0xFFFF6B6B)
                                        : const Color(0xFF20C997),
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: '0',
                                    hintStyle: const TextStyle(
                                      color: Colors.white24,
                                    ),
                                    prefixText: _isExpense ? '- ' : '+ ',
                                    prefixStyle: TextStyle(
                                      color: _isExpense
                                          ? const Color(0xFFFF6B6B)
                                          : const Color(0xFF20C997),
                                    ),
                                    suffixText: 'đ',
                                    suffixStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                              if (currentParent != null) ...[
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: _showChildPicker,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      currentChild?.name ?? 'Chọn danh mục',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_imagePath != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagePath = null),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- NOTE SECTION: CENTERED ---
            TextField(
              controller: _noteController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Nhìn vào là biết tiền đi đâu :v',
                hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.2),
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
            ),

            const SizedBox(height: 30),

            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: SheepButton(
                label: widget.transaction == null ? 'LƯU' : 'CẬP NHẬT',
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
