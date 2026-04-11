import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 2)
class CategoryModel extends HiveObject {
  @HiveField(0)
  late String id; // ID riêng biệt (VD: 'cat_001')

  @HiveField(1)
  late String name; // Tên hiển thị

  @HiveField(2)
  late int iconCode;

  @HiveField(3)
  late bool isExpense; // Thu hay Chi

  @HiveField(4)
  String? parentId; // Nếu null => Là danh mục Cha. Nếu có giá trị => Là con.

  @HiveField(5)
  double? budget; // Ngân sách thiết lập

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.isExpense,
    this.parentId, // Có thể null
    this.budget,
  });

  IconData get iconData => IconData(iconCode, fontFamily: 'MaterialIcons');
}
