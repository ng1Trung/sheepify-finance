import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';
import '../../core/theme/app_colors.dart';
import 'common/sheep_widgets.dart';
import 'transaction/transaction_image_area.dart';
import 'transaction/transaction_category_picker.dart';

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

  String? _selectedCategoryId;
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
      _selectedCategoryId = tx.categoryId;
      _imagePath = tx.imagePath;
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _isExpense = true;
      _imagePath = null;
    }

    _amountController.addListener(() => setState(() {}));
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
          _buildDragHandle(),
          _buildPickerTitle(context),
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
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(pickedFile.path)}';
        final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
        setState(() => _imagePath = savedImage.path);
      }
    }
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildPickerTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        'TẢI LÊN ẢNH',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
      ),
    );
  }

  void _submit() {
    if (_amountController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng nhập số tiền và chọn danh mục!'),
        backgroundColor: AppColors.expense,
      ));
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
        tx.categoryId = _selectedCategoryId!;
        tx.imagePath = _imagePath;
        tx.save();
      } else {
        final newTx = Transaction(
          note: _noteController.text,
          amount: enteredAmount,
          date: _selectedDate,
          isExpense: _isExpense,
          categoryId: _selectedCategoryId!,
          imagePath: _imagePath,
        );
        _box.add(newTx);
      }
      Navigator.of(context).pop(_selectedDate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.expense));
    }
  }

  void _showCategoryPicker() {
    final cats = _catBox.values.where((c) => c.isExpense == _isExpense).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => TransactionCategoryPicker(
        categories: cats,
        selectedCategoryId: _selectedCategoryId,
        onCategorySelected: (id) {
          setState(() => _selectedCategoryId = id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    CategoryModel? selectedCategory;
    if (_selectedCategoryId != null) {
      try {
        selectedCategory = _catBox.values.firstWhere((c) => c.id == _selectedCategoryId);
      } catch (_) {}
    }

    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            const SizedBox(height: 25),
            _buildDatePill(),
            const SizedBox(height: 30),
            TransactionImageArea(
              imagePath: _imagePath,
              isExpense: _isExpense,
              selectedCategory: selectedCategory,
              amountController: _amountController,
              onPickImage: _pickImage,
              onRemoveImage: () => setState(() => _imagePath = null),
              onToggleType: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isExpense = !_isExpense;
                  _selectedCategoryId = null;
                });
              },
              onShowCategoryPicker: _showCategoryPicker,
            ),
            const SizedBox(height: 30),
            _buildNoteInput(),
            const SizedBox(height: 30),
            _buildSaveButton(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
      child: Text(
        DateFormat('dd MMMM, yyyy - HH:mm', 'vi').format(_selectedDate),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Nhìn vào là biết tiền đi đâu :v',
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.2), fontSize: 14),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: SheepButton(
        label: widget.transaction == null ? 'LƯU' : 'CẬP NHẬT',
        onPressed: _submit,
      ),
    );
  }
}
