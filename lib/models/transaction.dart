import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  late String note;

  @HiveField(1)
  late double amount;

  @HiveField(2)
  late DateTime date;

  @HiveField(3)
  late bool isExpense;

  @HiveField(4)
  late String categoryId; // LƯU Ý: Giờ ta lưu ID thay vì Tên

  @HiveField(5)
  String? imagePath;

  Transaction({
    required this.note,
    required this.amount,
    required this.date,
    required this.isExpense,
    required this.categoryId,
    this.imagePath,
  });
}
