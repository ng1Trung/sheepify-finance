import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/constants/constants.dart';
import '../../data/models/transaction.dart';
import '../../data/models/category_model.dart';

class TransactionForm extends StatefulWidget {
  // Nếu có tx -> Chế độ Edit. Nếu null -> Chế độ Add
  final Transaction? transaction;

  // Ngày mặc định (dùng cho trường hợp Add từ DiaryTab đang chọn ngày nào đó)
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
    // --- LOGIC ĐIỀN DỮ LIỆU (FILL DATA) ---
    if (widget.transaction != null) {
      // Chế độ EDIT: Lấy dữ liệu cũ đắp vào
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _noteController.text = tx.note;
      _selectedDate = tx.date;
      _isExpense = tx.isExpense;
      _selectedChildId = tx.categoryId;
      _imagePath = tx.imagePath;

      // Tìm ParentId từ ChildId cũ
      try {
        final child = _catBox.values.firstWhere(
          (c) => c.id == _selectedChildId,
        );
        _selectedParentId = child.parentId;
      } catch (_) {
        // Nếu danh mục cũ bị xóa rồi thì thôi, để user chọn lại
      }
    } else {
      // Chế độ ADD: Mặc định
      _selectedDate = widget.initialDate ?? DateTime.now();
      _isExpense = true;
      _imagePath = null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Chọn nguồn ảnh',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.blue),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.purple),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        // Move to permanent storage
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(pickedFile.path)}';
        final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
        setState(() => _imagePath = savedImage.path);
      }
    }
  }

  void _submit() {
    if (_amountController.text.isEmpty || _selectedChildId == null) {
      // Thông báo thất bại nếu thiếu dữ liệu
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền và chọn danh mục!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final enteredAmount = double.tryParse(_amountController.text) ?? 0;
    if (enteredAmount <= 0) return;

    try {
      if (widget.transaction != null) {
        // UPDATE
        final tx = widget.transaction!;
        tx.amount = enteredAmount;
        tx.note = _noteController.text;
        tx.date = _selectedDate;
        tx.isExpense = _isExpense;
        tx.categoryId = _selectedChildId!;
        tx.imagePath = _imagePath;
        tx.save();
      } else {
        // CREATE
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

      // Đóng form và TRẢ VỀ NGÀY VỪA CHỌN
      Navigator.of(context).pop(_selectedDate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy danh sách danh mục
    final parentCats = _catBox.values
        .where((c) => c.parentId == null && c.isExpense == _isExpense)
        .toList();

    // Auto select Parent nếu chưa chọn
    if (_selectedParentId == null && parentCats.isNotEmpty) {
      _selectedParentId = parentCats.first.id;
    } else if (_selectedParentId != null &&
        parentCats.every((p) => p.id != _selectedParentId)) {
      // Trường hợp đổi từ Thu sang Chi, ID cũ không còn hợp lệ
      if (parentCats.isNotEmpty) _selectedParentId = parentCats.first.id;
    }

    final childCats = _catBox.values
        .where((c) => c.parentId == _selectedParentId)
        .toList();

    // Auto select Child nếu chưa chọn hoặc không hợp lệ
    if (childCats.isNotEmpty) {
      if (_selectedChildId == null ||
          !childCats.any((c) => c.id == _selectedChildId)) {
        _selectedChildId = childCats.first.id;
      }
    } else {
      _selectedChildId = null;
    }

    return Container(
      padding: EdgeInsets.only(
        top: 15,
        left: 15,
        right: 15,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              widget.transaction == null ? 'Thêm Giao Dịch' : 'Sửa Giao Dịch',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 15),

          // Switch Thu/Chi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Thu Nhập',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _isExpense,
                activeColor: Colors.red,
                inactiveThumbColor: Colors.green,
                onChanged: (val) {
                  setState(() {
                    _isExpense = val;
                    _selectedParentId =
                        null; // Reset để logic auto select chạy lại
                    _selectedChildId = null;
                  });
                },
              ),
              const Text(
                'Chi Tiêu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Chọn Danh Mục Cha
          const Text(
            '1. Chọn Danh Mục:',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: parentCats.map((pCat) {
                final isSelected = _selectedParentId == pCat.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(pCat.name),
                    avatar: Icon(
                      IconData(pCat.iconCode, fontFamily: 'MaterialIcons'),
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : (_isExpense ? Colors.red : Colors.green),
                    ),
                    selected: isSelected,
                    selectedColor: _isExpense
                        ? Colors.red[100]
                        : Colors.green[100],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.black87,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedParentId = pCat.id);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 15),

          // Chọn Danh Mục Con
          Text(
            _isExpense ? '2. Loại Chi tiêu:' : '2. Loại Thu nhập:',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (childCats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'Chưa có danh mục con',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: childCats.map((cCat) {
                  final isSelected = _selectedChildId == cCat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cCat.name),
                      avatar: Icon(
                        IconData(cCat.iconCode, fontFamily: 'MaterialIcons'),
                        size: 18,
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                      selected: isSelected,
                      selectedColor: _isExpense ? Colors.red : Colors.green,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedChildId = cCat.id);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 15),

          // Chọn Ngày
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Chọn ngày'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null)
                    setState(
                      () => _selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        DateTime.now().hour,
                        DateTime.now().minute,
                      ),
                    );
                },
              ),
            ],
          ),

          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số tiền',
              border: OutlineInputBorder(),
              prefixText: 'đ ',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 20),

          // Phần đính kèm ảnh
          const Text(
            'Đính kèm ảnh:',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade50,
              ),
              child: _imagePath != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_imagePath!),
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: InkWell(
                            onTap: () => setState(() => _imagePath = null),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black.withOpacity(0.5),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_a_photo_outlined,
                            size: 30, color: Colors.grey),
                        SizedBox(height: 5),
                        Text(
                          'Thêm ảnh hóa đơn/giao dịch',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isExpense ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                widget.transaction == null ? 'LƯU GIAO DỊCH' : 'LƯU THAY ĐỔI',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
