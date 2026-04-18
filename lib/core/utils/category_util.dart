import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction.dart';
import '../constants/constants.dart';

class CategoryUtil {
  static double calculateCategorySpent(CategoryModel cat) {
    final txBox = Hive.box<Transaction>(kMoneyBox);
    final allTransactions = txBox.values.toList();
    final now = DateTime.now();
    double spent = 0;
    
    final goalType = cat.effectiveGoalTypeIndex;
    if (goalType == 1) {
      // Monthly goal: only current month
      spent = allTransactions
          .where((tx) => 
              tx.categoryId == cat.id && 
              tx.date.month == now.month && 
              tx.date.year == now.year)
          .fold(0.0, (sum, tx) => sum + tx.amount);
    } else if (goalType == 2) {
      // Long-term goal: all history
      spent = allTransactions
          .where((tx) => tx.categoryId == cat.id)
          .fold(0.0, (sum, tx) => sum + tx.amount);
    } else {
      // Standard Income/Expense: usually current month
      spent = allTransactions
          .where((tx) => 
              tx.categoryId == cat.id && 
              tx.date.month == now.month && 
              tx.date.year == now.year)
          .fold(0.0, (sum, tx) => sum + tx.amount);
    }
    
    return spent;
  }
}
