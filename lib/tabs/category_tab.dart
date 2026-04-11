import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../models/transaction.dart';
import '../constants.dart';
import '../widgets/category_form.dart';

class CategoryTab extends StatelessWidget {
  const CategoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: AnimatedBuilder(
        animation: Listenable.merge([
          Hive.box<CategoryModel>(kCatBox).listenable(),
          Hive.box<Transaction>(kMoneyBox).listenable(),
        ]),
        builder: (context, _) {
          final box = Hive.box<CategoryModel>(kCatBox);
          final parents = box.values.where((c) => c.parentId == null).toList();
          final txBox = Hive.box<Transaction>(kMoneyBox);
          final now = DateTime.now();

          // Tính tổng chi tiêu từng danh mục trong tháng này
          Map<String, double> categorySpent = {};
          for (var tx in txBox.values) {
            if (tx.isExpense &&
                tx.date.month == now.month &&
                tx.date.year == now.year) {
              categorySpent[tx.categoryId] =
                  (categorySpent[tx.categoryId] ?? 0) + tx.amount;
            }
          }

          String formatMoney(double amount) =>
              NumberFormat.currency(locale: 'vi_VN', symbol: 'đ')
                  .format(amount);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
            itemCount: parents.length,
            itemBuilder: (context, index) {
              final parent = parents[index];
              final children = box.values
                  .where((c) => c.parentId == parent.id)
                  .toList();

              // Tính tổng chi của cả nhóm (Cha + tất cả con)
              double totalGroupSpent = 0;
              totalGroupSpent += (categorySpent[parent.id] ?? 0);
              for (var child in children) {
                totalGroupSpent += (categorySpent[child.id] ?? 0);
              }

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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (parent.isExpense &&
                                        parent.budget != null) ...[
                                      Text(
                                        'Còn: ${formatMoney(parent.budget! - totalGroupSpent)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: (parent.budget! -
                                                      totalGroupSpent) <
                                                  0
                                              ? Colors.red
                                              : Colors.blue[700],
                                        ),
                                      ),
                                      Text(
                                        'Tổng NS: ${formatMoney(parent.budget!)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: parent.isExpense
                                              ? Colors.red[300]
                                              : Colors.green[300],
                                        ),
                                      ),
                                    ] else ...[
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
                                  ],
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
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (child.isExpense) ...[
                                if (parent.budget != null) ...[
                                  // Nếu cha có ngân sách -> Hiện phần chi tiêu của con trong NS đó
                                  Text(
                                    '- ${formatMoney(categorySpent[child.id] ?? 0)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ] else if (child.budget != null) ...[
                                  // Nếu cha không có nhưng con có -> Hiện theo con
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Còn: ${formatMoney(child.budget! - (categorySpent[child.id] ?? 0))}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: (child.budget! -
                                                      (categorySpent[child.id] ??
                                                          0)) <
                                                  0
                                              ? Colors.red
                                              : Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'NS riêng: ${formatMoney(child.budget!)}',
                                        style: const TextStyle(
                                            fontSize: 9, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(width: 8),
                              ],
                              const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
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
