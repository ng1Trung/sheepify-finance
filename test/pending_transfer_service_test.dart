import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sheepify/core/constants/constants.dart';
import 'package:sheepify/data/models/pending_transfer.dart';
import 'package:sheepify/data/models/transaction.dart';
import 'package:sheepify/data/models/wallet_model.dart';
import 'package:sheepify/data/services/pending_transfer_service.dart';
import 'package:sheepify/data/services/wallet_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sheepify_pending_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TransactionAdapter());
    await Hive.openBox<String>(kWalletsBox);
    await Hive.openBox<String>(kPendingTransfersBox);
    await Hive.openBox<Transaction>(kMoneyBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box<String>(kPendingTransfersBox).clear();
    await Hive.box<Transaction>(kMoneyBox).clear();
    await Hive.box<String>(kWalletsBox).clear();

    // Khởi tạo 1 ví Techcombank có số dư 5.000.000đ
    final testWallet = WalletModel(
      id: 'wallet_tcb_test',
      name: 'Techcombank',
      bankId: 'techcombank',
      bankBin: '970407',
      initialBalance: 5000000,
      isDefault: true,
      createdAt: DateTime.now(),
    );
    await WalletService.saveWallet(testWallet);
  });

  group('PendingTransfer Model Tests', () {
    test('PendingTransfer serialization round-trip', () {
      final now = DateTime.now();
      final pending = PendingTransfer(
        id: 'pending_001',
        amount: 250000,
        note: 'Tien an trua',
        categoryId: 'cat_food',
        walletId: 'wallet_tcb_test',
        sendingBankId: 'techcombank',
        recipientBankBin: '970436',
        recipientBankName: 'Vietcombank',
        accountNo: '0011001234567',
        qrPayload: '000201010212...',
        createdAt: now,
        status: 'pending',
      );

      final jsonStr = pending.toJson();
      final restored = PendingTransfer.fromJson(jsonStr);

      expect(restored.id, pending.id);
      expect(restored.amount, pending.amount);
      expect(restored.note, pending.note);
      expect(restored.categoryId, pending.categoryId);
      expect(restored.walletId, pending.walletId);
      expect(restored.sendingBankId, pending.sendingBankId);
      expect(restored.recipientBankBin, pending.recipientBankBin);
      expect(restored.recipientBankName, pending.recipientBankName);
      expect(restored.accountNo, pending.accountNo);
      expect(restored.qrPayload, pending.qrPayload);
      expect(restored.status, 'pending');
      expect(restored.isPending, isTrue);
    });
  });

  group('PendingTransferService Workflow Tests', () {
    test('createPendingTransfer records pending transaction without deducting wallet balance', () async {
      final initialBalance = WalletService.getWallet('wallet_tcb_test')!.initialBalance;
      expect(initialBalance, 5000000);

      final pending = await PendingTransferService.createPendingTransfer(
        amount: 500000,
        note: 'Mua sam',
        categoryId: 'cat_shopping',
        walletId: 'wallet_tcb_test',
        sendingBankId: 'techcombank',
        recipientBankBin: '970422',
        recipientBankName: 'MBBank',
        accountNo: '0987654321',
      );

      expect(pending.id.isNotEmpty, isTrue);
      expect(pending.isPending, isTrue);

      // 1. Số dư ví hoàn toàn không bị trừ khi ở trạng thái pending
      final balanceAfterPending = WalletService.getWallet('wallet_tcb_test')!.initialBalance;
      expect(balanceAfterPending, 5000000);

      // 2. Sổ chi tiêu moneyBox đã có giao dịch với trạng thái pending
      final moneyBox = Hive.box<Transaction>(kMoneyBox);
      expect(moneyBox.containsKey(pending.id), isTrue);
      final tx = moneyBox.get(pending.id)!;
      expect(tx.isPending, isTrue);
      expect(tx.status, TransactionStatus.pending);
      expect(tx.walletId, 'wallet_tcb_test');
      expect(tx.amount, 500000);

      // 3. Có trong danh sách getPendingTransfers
      final pendingList = PendingTransferService.getPendingTransfers();
      expect(pendingList.length, 1);
      expect(pendingList.first.id, pending.id);
    });

    test('confirmTransfer marks transaction completed, deducts wallet, and clears pending', () async {
      final pending = await PendingTransferService.createPendingTransfer(
        amount: 1000000,
        note: 'Tra tien phong',
        categoryId: 'cat_rent',
        walletId: 'wallet_tcb_test',
        sendingBankId: 'techcombank',
        recipientBankBin: '970405',
        recipientBankName: 'Agribank',
        accountNo: '1234567890',
      );

      // Trước khi xác nhận: status là pending, ví chưa trừ
      final moneyBox = Hive.box<Transaction>(kMoneyBox);
      expect(moneyBox.get(pending.id)!.isPending, isTrue);
      expect(WalletService.getWallet('wallet_tcb_test')!.initialBalance, 5000000);

      // Xác nhận đã chuyển tiền thành công
      final tx = await PendingTransferService.confirmTransfer(pending.id);
      expect(tx, isNotNull);
      expect(tx!.amount, 1000000);
      expect(tx.note, 'Tra tien phong');
      expect(tx.isExpense, isTrue);
      expect(tx.isCompleted, isTrue);
      expect(tx.status, TransactionStatus.completed);

      // 1. Transaction trong moneyBox được cập nhật completed
      final updatedTx = moneyBox.get(pending.id)!;
      expect(updatedTx.isCompleted, isTrue);

      // 2. Số dư ví bị trừ chính xác 1.000.000đ (5.000.000 -> 4.000.000)
      final balanceAfterConfirm = WalletService.getWallet('wallet_tcb_test')!.initialBalance;
      expect(balanceAfterConfirm, 4000000);

      // 3. Giao dịch pending bị xóa khỏi danh sách chờ
      final pendingList = PendingTransferService.getPendingTransfers();
      expect(pendingList.isEmpty, isTrue);
      expect(PendingTransferService.getPendingTransfer(pending.id), isNull);
    });

    test('cancelTransfer marks transaction cancelled without deducting wallet', () async {
      final pending = await PendingTransferService.createPendingTransfer(
        amount: 2000000,
        note: 'Giao dich bi huy',
        categoryId: 'cat_other',
        walletId: 'wallet_tcb_test',
        sendingBankId: 'techcombank',
        accountNo: '999999999',
      );

      expect(PendingTransferService.getPendingTransfers().length, 1);

      // Hủy giao dịch (người dùng chưa chuyển hoặc bấm hủy)
      await PendingTransferService.cancelTransfer(pending.id);

      // 1. Danh sách pending rỗng
      expect(PendingTransferService.getPendingTransfers().isEmpty, isTrue);

      // 2. Số dư ví giữ nguyên vẹn 5.000.000đ
      final currentBalance = WalletService.getWallet('wallet_tcb_test')!.initialBalance;
      expect(currentBalance, 5000000);

      // 3. Transaction trong moneyBox được đánh dấu cancelled
      final moneyBox = Hive.box<Transaction>(kMoneyBox);
      final tx = moneyBox.get(pending.id)!;
      expect(tx.isCancelled, isTrue);
      expect(tx.status, TransactionStatus.cancelled);
    });
  });
}
