import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction.dart';
import '../constants/constants.dart';
import 'financial_cycle_util.dart';

class CategoryUtil {
  static double calculateCategorySpent(CategoryModel cat, {DateTime? now}) {
    final txBox = Hive.box<Transaction>(kMoneyBox);
    final allTransactions = txBox.values.toList();
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final cycleRange = FinancialCycleUtil.cycleRangeFor(
      now ?? DateTime.now(),
      settings.financialCycleStartDay,
    );
    double spent = 0;

    final goalType = cat.effectiveGoalTypeIndex;
    if (goalType == 1) {
      // Periodic goal: only current financial cycle
      spent = allTransactions
          .where(
            (tx) =>
                tx.categoryId == cat.id &&
                FinancialCycleUtil.isInRange(tx.date, cycleRange),
          )
          .fold(0.0, (sum, tx) => sum + tx.amount);
    } else if (goalType == 2) {
      // Goal: all history
      spent = allTransactions
          .where((tx) => tx.categoryId == cat.id)
          .fold(0.0, (sum, tx) => sum + tx.amount);
    } else {
      // Standard income/expense: current financial cycle
      spent = allTransactions
          .where(
            (tx) =>
                tx.categoryId == cat.id &&
                FinancialCycleUtil.isInRange(tx.date, cycleRange),
          )
          .fold(0.0, (sum, tx) => sum + tx.amount);
    }

    return spent;
  }
}
