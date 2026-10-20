import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/constants.dart';
import '../models/pending_transfer.dart';
import '../models/transaction.dart';
import 'wallet_service.dart';

class PendingTransferService {
  static Box<String> get _box => Hive.box<String>(kPendingTransfersBox);

  /// Tạo một giao dịch chuyển khoản ở trạng thái Chờ xác nhận (Pending).
  /// Transaction được ghi nhận vào sổ với status: 'pending'.
  /// Tiền trong ví CHƯA bị trừ cho tới khi người dùng bấm xác nhận thành công.
  static Future<PendingTransfer> createPendingTransfer({
    required double amount,
    required String note,
    required String categoryId,
    String? walletId,
    String? sendingBankId,
    String? recipientBankBin,
    String? recipientBankName,
    required String accountNo,
    String? qrPayload,
  }) async {
    final timestamp = DateTime.now();
    final id = Transaction.createId();

    // Xác định walletId nếu chưa truyền vào
    String? resolvedWalletId = walletId;
    if (resolvedWalletId == null && sendingBankId != null) {
      try {
        final wallets = WalletService.getWallets();
        final match = wallets.firstWhere((w) => w.bankId == sendingBankId);
        resolvedWalletId = match.id;
      } catch (_) {}
    }

    final pending = PendingTransfer(
      id: id,
      amount: amount,
      note: note,
      categoryId: categoryId,
      walletId: resolvedWalletId,
      sendingBankId: sendingBankId,
      recipientBankBin: recipientBankBin,
      recipientBankName: recipientBankName,
      accountNo: accountNo,
      qrPayload: qrPayload,
      createdAt: timestamp,
      status: 'pending',
    );

    // Lưu vào box chờ xác nhận
    await _box.put(pending.id, pending.toJson());

    // Tạo Transaction với trạng thái Pending trong sổ giao dịch kMoneyBox
    final moneyBox = Hive.box<Transaction>(kMoneyBox);
    final transaction = Transaction(
      id: id,
      amount: amount,
      note: note,
      date: timestamp,
      isExpense: true,
      categoryId: categoryId,
      status: TransactionStatus.pending,
      walletId: resolvedWalletId,
    );
    await moneyBox.put(transaction.id, transaction);

    return pending;
  }

  /// Lấy danh sách các giao dịch đang chờ xác nhận
  static List<PendingTransfer> getPendingTransfers() {
    final list = <PendingTransfer>[];
    for (final raw in _box.values) {
      try {
        final p = PendingTransfer.fromJson(raw);
        if (p.isPending) list.add(p);
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Lấy giao dịch chờ xác nhận theo ID
  static PendingTransfer? getPendingTransfer(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    try {
      return PendingTransfer.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Lấy giao dịch chờ xác nhận gần đây nhất (nếu có)
  static PendingTransfer? getLatestPendingTransfer() {
    final list = getPendingTransfers();
    return list.isNotEmpty ? list.first : null;
  }

  /// XÁC NHẬN ĐÃ CHUYỂN TIỀN THÀNH CÔNG:
  /// 1. Cập nhật Transaction sang status = 'completed' trong kMoneyBox
  /// 2. Khấu trừ số dư ví ngân hàng tương ứng
  /// 3. Xóa giao dịch khỏi danh sách Pending
  /// 4. Trả về Transaction vừa cập nhật
  static Future<Transaction?> confirmTransfer(String pendingId) async {
    final pending = getPendingTransfer(pendingId);
    final moneyBox = Hive.box<Transaction>(kMoneyBox);

    Transaction? transaction = moneyBox.get(pendingId);
    if (transaction == null) {
      try {
        transaction = moneyBox.values.firstWhere((t) => t.id == pendingId);
      } catch (_) {}
    }

    if (transaction != null) {
      transaction.status = TransactionStatus.completed;
      transaction.date = DateTime.now();
      await transaction.save();
    } else if (pending != null) {
      // Trường hợp dự phòng nếu chưa có trong moneyBox
      transaction = Transaction(
        id: pending.id,
        amount: pending.amount,
        note: pending.note,
        date: DateTime.now(),
        isExpense: true,
        categoryId: pending.categoryId,
        status: TransactionStatus.completed,
        walletId: pending.walletId,
      );
      await moneyBox.put(transaction.id, transaction);
    }

    // 2. Cập nhật trừ số dư ví tương ứng
    final wallets = WalletService.getWallets();
    try {
      final amount = transaction?.amount ?? pending?.amount ?? 0.0;
      final targetWalletId = transaction?.walletId ?? pending?.walletId;
      final targetBankId = pending?.sendingBankId;

      final matchingWallet = wallets.firstWhere(
        (w) =>
            w.id == targetWalletId ||
            (targetBankId != null && w.bankId == targetBankId),
      );
      final newBal =
          (matchingWallet.initialBalance - amount).clamp(0.0, double.infinity);
      await WalletService.adjustBalance(matchingWallet.id, newBal);
    } catch (_) {}

    // 3. Xóa khỏi danh sách Pending
    await _box.delete(pendingId);

    return transaction;
  }

  /// HỦY GIAO DỊCH CHỜ (Người dùng không chuyển hoặc giao dịch thất bại):
  /// Cập nhật Transaction sang status = 'cancelled'.
  /// Xóa khỏi danh sách Pending. Số dư ví hoàn toàn không bị trừ.
  static Future<void> cancelTransfer(String pendingId) async {
    final moneyBox = Hive.box<Transaction>(kMoneyBox);
    Transaction? transaction = moneyBox.get(pendingId);
    if (transaction == null) {
      try {
        transaction = moneyBox.values.firstWhere((t) => t.id == pendingId);
      } catch (_) {}
    }

    if (transaction != null) {
      transaction.status = TransactionStatus.cancelled;
      await transaction.save();
    }

    await _box.delete(pendingId);
  }

  /// ValueListenable để UI lắng nghe thay đổi các giao dịch Pending theo thời gian thực
  static ValueListenable<Box<String>> listenable() => _box.listenable();
}
