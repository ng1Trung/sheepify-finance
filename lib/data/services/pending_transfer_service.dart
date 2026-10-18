import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/constants.dart';
import '../models/pending_transfer.dart';
import '../models/transaction.dart';
import 'wallet_service.dart';

class PendingTransferService {
  static Box<String> get _box => Hive.box<String>(kPendingTransfersBox);

  /// Tạo một giao dịch chuyển khoản ở trạng thái Chờ xác nhận (Pending).
  /// Tiền trong ví CHƯA bị trừ và Transaction CHƯA được ghi nhận vào sổ chi tiêu.
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
    final id = 'pending_${timestamp.microsecondsSinceEpoch}';

    final pending = PendingTransfer(
      id: id,
      amount: amount,
      note: note,
      categoryId: categoryId,
      walletId: walletId,
      sendingBankId: sendingBankId,
      recipientBankBin: recipientBankBin,
      recipientBankName: recipientBankName,
      accountNo: accountNo,
      qrPayload: qrPayload,
      createdAt: timestamp,
      status: 'pending',
    );

    await _box.put(pending.id, pending.toJson());
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
  /// 1. Tạo Transaction chính thức và ghi vào kMoneyBox
  /// 2. Khấu trừ số dư ví ngân hàng tương ứng
  /// 3. Xóa giao dịch khỏi danh sách Pending
  /// 4. Trả về Transaction vừa tạo
  static Future<Transaction?> confirmTransfer(String pendingId) async {
    final pending = getPendingTransfer(pendingId);
    if (pending == null) return null;

    // 1. Tạo Transaction chính thức
    final transaction = Transaction(
      id: Transaction.createId(),
      amount: pending.amount,
      note: pending.note,
      date: DateTime.now(),
      isExpense: true,
      categoryId: pending.categoryId,
    );

    final moneyBox = Hive.box<Transaction>(kMoneyBox);
    await moneyBox.put(transaction.id, transaction);

    // 2. Cập nhật trừ số dư ví tương ứng
    final wallets = WalletService.getWallets();
    try {
      final matchingWallet = wallets.firstWhere(
        (w) =>
            w.id == pending.walletId ||
            (pending.sendingBankId != null && w.bankId == pending.sendingBankId),
      );
      final newBal =
          (matchingWallet.initialBalance - pending.amount).clamp(0.0, double.infinity);
      await WalletService.adjustBalance(matchingWallet.id, newBal);
    } catch (_) {}

    // 3. Xóa khỏi danh sách Pending
    await _box.delete(pendingId);

    return transaction;
  }

  /// HỦY GIAO DỊCH CHỜ (Người dùng không chuyển hoặc giao dịch thất bại):
  /// Xóa khỏi danh sách Pending. Số dư ví và sổ chi tiêu hoàn toàn không bị ảnh hưởng.
  static Future<void> cancelTransfer(String pendingId) async {
    await _box.delete(pendingId);
  }

  /// ValueListenable để UI lắng nghe thay đổi các giao dịch Pending theo thời gian thực
  static ValueListenable<Box<String>> listenable() => _box.listenable();
}
