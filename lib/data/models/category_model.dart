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

  @HiveField(6)
  int? typeIndex; // 0: expense, 1: income, 2: savings

  @HiveField(7)
  double? targetAmount;

  @HiveField(8)
  DateTime? targetDate;

  @HiveField(10)
  int? goalTypeIndex; // 0: none, 1: periodic (monthly), 2: goal (short/long-term)

  @HiveField(11)
  int? reminderDay; // Day of month (1-31)

  @HiveField(12)
  int? targetYear; // For goals

  @HiveField(13)
  int? targetMonth; // For short-term goals

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    this.isExpense = true,
    this.budget,
    this.colorValue,
    this.typeIndex = 0,
    this.targetAmount,
    this.targetDate,
    this.goalTypeIndex = 0,
    this.reminderDay,
    this.targetYear,
    this.targetMonth,
  });

  int get effectiveTypeIndex => typeIndex ?? (isExpense ? 0 : 1);
  int get effectiveGoalTypeIndex => goalTypeIndex ?? 0;
  bool get isMonthlyGoal => effectiveGoalTypeIndex == 1;

  IconData get iconData => IconData(iconCode, fontFamily: 'MaterialIcons');
}
