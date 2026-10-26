import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sheepify/core/constants/constants.dart';
import 'package:sheepify/data/models/wallet_model.dart';
import 'package:sheepify/data/services/wallet_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sheepify_wallet_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(kWalletsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('WalletModel Tests', () {
    test('WalletModel serialization round-trip', () {
      final now = DateTime.now();
      final wallet = WalletModel(
        id: 'wallet_001',
        name: 'Techcombank Cá Nhân',
        bankId: 'techcombank',
        bankBin: '970407',
        initialBalance: 5000000,
        isDefault: true,
        createdAt: now,
      );

      final jsonStr = wallet.toJson();
      final restored = WalletModel.fromJson(jsonStr);

      expect(restored.id, wallet.id);
      expect(restored.name, wallet.name);
      expect(restored.bankId, wallet.bankId);
      expect(restored.bankBin, wallet.bankBin);
      expect(restored.initialBalance, 5000000);
      expect(restored.isDefault, isTrue);
    });
  });

  group('WalletService CRUD & Balance Tests', () {
    test('Default seeding generates only Cash wallet as default', () {
      final wallets = WalletService.getWallets();
      expect(wallets.length, 1);
      expect(wallets.first.id, 'wallet_cash');
      expect(wallets.first.name, 'Tiền mặt');
      expect(wallets.first.isDefault, isTrue);
      expect(WalletService.getDefaultWallet()?.id, 'wallet_cash');
    });

    test('Add new wallet and set default', () async {
      final newWallet = WalletModel(
        id: 'wallet_vcb_test',
        name: 'Vietcombank Tiết Kiệm',
        bankId: 'vcb',
        bankBin: '970436',
        initialBalance: 12000000,
        isDefault: true,
        createdAt: DateTime.now(),
      );

      await WalletService.saveWallet(newWallet);
      await WalletService.setDefaultWallet(newWallet.id);

      final defaultWallet = WalletService.getDefaultWallet();
      expect(defaultWallet?.id, 'wallet_vcb_test');
      expect(defaultWallet?.name, 'Vietcombank Tiết Kiệm');
    });

    test('Adjust balance updates initialBalance', () async {
      await WalletService.adjustBalance('wallet_vcb_test', 15000000);
      final wallets = WalletService.getWallets();
      final updated = wallets.firstWhere((w) => w.id == 'wallet_vcb_test');
      expect(updated.initialBalance, 15000000);
    });

    test('Total balance calculation', () {
      final total = WalletService.getTotalBalance();
      expect(total >= 15000000, isTrue);
    });

    test('Adding wallet with 0 balance is preserved permanently and never cleared', () async {
      final zeroBalWallet = WalletModel(
        id: 'wallet_zero_bal_mb',
        name: 'MB Bank Chi Tiêu',
        bankId: 'mb',
        bankBin: '970422',
        initialBalance: 0,
        isDefault: false,
        createdAt: DateTime.now(),
      );

      await WalletService.saveWallet(zeroBalWallet);
      final wallets = WalletService.getWallets();
      expect(wallets.any((w) => w.id == 'wallet_zero_bal_mb'), isTrue);
    });
  });
}
