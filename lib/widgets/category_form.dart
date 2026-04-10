import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/category_model.dart';
import '../constants.dart';

class CategoryForm extends StatefulWidget {
  final CategoryModel? category; // Nếu có -> Sửa
  const CategoryForm({super.key, this.category});

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final _nameController = TextEditingController();
  final _catBox = Hive.box<CategoryModel>(kCatBox);

  late bool _isExpense;
  String? _selectedParentId;
  late int _selectedIcon;

  // List icon để chọn
  final List<IconData> _iconList = [
    Icons.fastfood,
    Icons.restaurant,
    Icons.local_cafe,
    Icons.local_bar,
    Icons.cake,
    Icons.kitchen,
    Icons.directions_car,
    Icons.motorcycle,
    Icons.directions_bus,
    Icons.flight,
    Icons.local_gas_station,
    Icons.shopping_cart,
    Icons.shopping_bag,
    Icons.checkroom,
    Icons.local_mall,
    Icons.card_giftcard,
    Icons.home,
    Icons.build,
    Icons.wifi,
    Icons.electrical_services,
    Icons.local_laundry_service,
    Icons.medical_services,
    Icons.fitness_center,
    Icons.spa,
    Icons.local_pharmacy,
    Icons.movie,
    Icons.sports_esports,
    Icons.school,
    Icons.book,
    Icons.music_note,
    Icons.attach_money,
    Icons.savings,
    Icons.work,
    Icons.pets,
    Icons.child_friendly,
    Icons.category,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      // --- CHẾ ĐỘ SỬA ---
      final cat = widget.category!;
      _nameController.text = cat.name;
      _isExpense = cat.isExpense;
      _selectedIcon = cat.iconCode;
      _selectedParentId = cat.parentId;
    } else {
      // --- CHẾ ĐỘ TẠO MỚI ---
      _nameController.text = '';
      _isExpense = true;
      _selectedIcon = _iconList[0].codePoint;
      _selectedParentId = null;

      // Mặc định chọn cha đầu tiên nếu có
      final parents = _catBox.values
          .where((c) => c.parentId == null && c.isExpense == _isExpense)
          .toList();
      if (parents.isNotEmpty) _selectedParentId = parents.first.id;
    }
  }

  void _submit() {
    if (_nameController.text.isEmpty) return;

    if (widget.category != null) {
      // UPDATE
      final cat = widget.category!;
      cat.name = _nameController.text;
      cat.iconCode = _selectedIcon;
      // Lưu ý: Không cho sửa ParentId hay Thu/Chi để tránh lỗi dữ liệu phức tạp
      cat.save();
    } else {
      // CREATE NEW
      // Nếu có chọn cha -> Tạo con. Nếu không chọn cha (hoặc chọn mục "Tạo nhóm mới") -> Tạo cha
      final newCat = CategoryModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        iconCode: _selectedIcon,
        isExpense: _isExpense,
        parentId: _selectedParentId == 'new_group' ? null : _selectedParentId,
      );
      _catBox.add(newCat);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Lấy danh sách Cha để hiển thị trong Dropdown
    final parents = _catBox.values
        .where((c) => c.parentId == null && c.isExpense == _isExpense)
        .toList();

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              widget.category == null ? 'Tạo Danh Mục' : 'Sửa Danh Mục',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),

          // 1. Chỉ cho chọn Thu/Chi khi Tạo mới (Sửa thì khóa lại)
          if (widget.category == null)
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
                      _selectedParentId = null; // Reset cha
                      final newParents = _catBox.values
                          .where(
                            (c) =>
                                c.parentId == null && c.isExpense == _isExpense,
                          )
                          .toList();
                      if (newParents.isNotEmpty)
                        _selectedParentId = newParents.first.id;
                    });
                  },
                ),
                const Text(
                  'Chi Tiêu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

          const SizedBox(height: 10),
          const Text('Tên danh mục:', style: TextStyle(color: Colors.grey)),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),

          const SizedBox(height: 15),

          // 2. Dropdown chọn Nhóm (Cha)
          // Chỉ hiện khi Tạo mới, hoặc khi đang Sửa danh mục con
          if (widget.category == null || widget.category!.parentId != null) ...[
            const Text('Thuộc nhóm:', style: TextStyle(color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedParentId,
                  items: [
                    if (widget.category == null)
                      const DropdownMenuItem(
                        value: 'new_group',
                        child: Text(
                          '+ Tạo nhóm mới',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ...parents.map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ),
                  ],
                  // SỬA Ở ĐÂY: Cho phép chọn lại cha ngay cả khi đang Edit
                  onChanged: (val) => setState(() => _selectedParentId = val),
                  hint: const Text('Chọn nhóm cha'),
                ),
              ),
            ),
            const SizedBox(height: 15),
          ],

          const Text('Biểu tượng:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _iconList.length,
              itemBuilder: (context, index) {
                final icon = _iconList[index];
                final isSelected = _selectedIcon == icon.codePoint;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon.codePoint),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : Colors.grey[700],
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text(
                widget.category == null ? 'TẠO MỚI' : 'LƯU THAY ĐỔI',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
