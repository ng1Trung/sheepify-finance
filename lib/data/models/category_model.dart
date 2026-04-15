import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 2)
class CategoryModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late int iconCode;

  @HiveField(3)
  late bool isExpense;

  @HiveField(4)
  double? budget;

  @HiveField(5)
  int? colorValue;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.isExpense,
    this.budget,
    this.colorValue,
  });

  IconData get iconData => IconData(iconCode, fontFamily: 'MaterialIcons');
}
