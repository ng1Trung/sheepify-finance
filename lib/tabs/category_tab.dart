import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/category_model.dart';
import '../constants.dart';
import '../widgets/category_form.dart';

class CategoryTab extends StatelessWidget {
  const CategoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ValueListenableBuilder(
        valueListenable: Hive.box<CategoryModel>(kCatBox).listenable(),
        builder: (context, box, _) {
          final parents = box.values.where((c) => c.parentId == null).toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
            itemCount: parents.length,
            itemBuilder: (context, index) {
              final parent = parents[index];
              final children = box.values
                  .where((c) => c.parentId == parent.id)
                  .toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // --- 1. HEADER CHA ---
                    Dismissible(
                      key: ValueKey(parent.id),
                      direction: DismissDirection.endToStart,
                      background: _buildDeleteBackground(),

                      // LOGIC MỚI: Kiểm tra xem có con không trước khi cho phép xóa
                      confirmDismiss: (_) => _confirmDeleteParent(
                        context,
                        parent,
                        children.length,
                      ),

                      onDismissed: (_) {
                        // Vì đã chặn ở confirmDismiss nên xuống đây chắc chắn là không có con -> Xóa an toàn
                        parent.delete();
                      },

                      child: InkWell(
                        onTap: () => _showCategoryForm(context, parent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: parent.isExpense
                                ? Colors.red[50]
                                : Colors.green[50],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                IconData(
                                  parent.iconCode,
                                  fontFamily: 'MaterialIcons',
                                ),
                                color: parent.isExpense
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  parent.name.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: parent.isExpense
                                        ? Colors.red[700]
                                        : Colors.green[700],
                                  ),
                                ),
                              ),
                              Text(
                                '${children.length} mục',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: parent.isExpense
                                      ? Colors.red[300]
                                      : Colors.green[300],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // --- 2. LIST CON ---
                    if (children.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(15.0),
                        child: Text(
                          'Chưa có danh mục con',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    ...children.map(
                      (child) => Dismissible(
                        key: ValueKey(child.id),
                        direction: DismissDirection.endToStart,
                        background: _buildDeleteBackground(),
                        confirmDismiss: (_) =>
                            _confirmDeleteChild(context, child),
                        onDismissed: (_) => child.delete(),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            IconData(
                              child.iconCode,
                              fontFamily: 'MaterialIcons',
                            ),
                            size: 20,
                            color: Colors.grey[700],
                          ),
                          title: Text(
                            child.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () => _showCategoryForm(context, child),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryForm(context, null),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.create_new_folder, color: Colors.white),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      color: Colors.red[100],
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.red),
    );
  }

  void _showCategoryForm(BuildContext context, CategoryModel? category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CategoryForm(category: category),
    );
  }

  // --- HÀM XỬ LÝ LOGIC XÓA MỚI ---

  // 1. Xóa Con: Chỉ cần confirm
  Future<bool?> _confirmDeleteChild(BuildContext context, CategoryModel item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa danh mục?'),
        content: Text('Bạn muốn xóa danh mục "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 2. Xóa Cha: Chặn nếu có con
  Future<bool?> _confirmDeleteParent(
    BuildContext context,
    CategoryModel parent,
    int childCount,
  ) async {
    if (childCount > 0) {
      // NẾU CÒN CON -> HIỆN THÔNG BÁO CHẶN
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Không thể xóa!'),
          content: Text(
            'Nhóm "${parent.name}" đang chứa $childCount danh mục con.\n\nVui lòng xóa hoặc di chuyển các danh mục con sang nhóm khác trước khi xóa nhóm này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // Chỉ có nút đóng
              child: const Text(
                'ĐÃ HIỂU',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      return false; // Trả về false để Dismissible trượt ngược lại (không xóa)
    } else {
      // NẾU TRỐNG -> CHO PHÉP XÓA
      return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xóa nhóm?'),
          content: Text('Xóa nhóm rỗng "${parent.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }
}
