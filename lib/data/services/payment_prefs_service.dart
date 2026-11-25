import 'package:hive/hive.dart';

import '../../core/constants/constants.dart';
import '../models/transaction.dart';

/// Small memory of how the user pays, so a repeat transfer needs only one
/// tap: the bank app they always use, and the category they gave each
/// recipient last time.
class PaymentPrefsService {
  static const String _lastSendingBankKey = 'last_sending_bank';

  static Box<String>? get _box =>
      Hive.isBoxOpen(kPaymentPrefsBox) ? Hive.box<String>(kPaymentPrefsBox) : null;

  static String _recipientKey(String bin, String accountNo) =>
      'cat:${bin.trim()}:${accountNo.trim()}';

  static String? get lastSendingBankId => _box?.get(_lastSendingBankKey);

  /// Category used the last time this exact account was paid.
  static String? categoryFor(String? bin, String? accountNo) {
    if (bin == null || accountNo == null) return null;
    if (bin.trim().isEmpty || accountNo.trim().isEmpty) return null;
    return _box?.get(_recipientKey(bin, accountNo));
  }

  static Future<void> rememberTransfer({
    required String sendingBankId,
    required String recipientBin,
    required String accountNo,
    required String categoryId,
  }) async {
    final box = _box;
    if (box == null) return;
    await box.put(_lastSendingBankKey, sendingBankId);
    await box.put(_recipientKey(recipientBin, accountNo), categoryId);
  }

  /// Expense categories the user picks most (last 60 days), most used first.
  static List<String> frequentExpenseCategoryIds({int limit = 4}) =>
      frequentCategoryIds(isExpense: true, limit: limit);

  /// Most used categories of one kind (last 60 days), most used first.
  static List<String> frequentCategoryIds({
    required bool isExpense,
    int limit = 4,
  }) {
    if (!Hive.isBoxOpen(kMoneyBox)) return const [];
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    final counts = <String, int>{};
    for (final tx in Hive.box<Transaction>(kMoneyBox).values) {
      if (tx.isExpense != isExpense || tx.isCancelled || tx.date.isBefore(cutoff)) continue;
      counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
    }
    final ids = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return ids.take(limit).toList();
  }
}
