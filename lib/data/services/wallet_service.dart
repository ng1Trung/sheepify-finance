import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/constants/constants.dart';
import '../models/wallet_model.dart';

class WalletService {
  static Box<String> get _box => Hive.box<String>(kWalletsBox);

  static void ensureOnlyCashDefaultSeeded() {
    if (_box.isEmpty) {
      _seedDefaultWallets();
      return;
    }
    if (_box.get('seeded_v2_cash_only') != 'true') {
      final wallets = <WalletModel>[];
      for (final raw in _box.values) {
        try {
          wallets.add(WalletModel.fromJson(raw));
        } catch (_) {}
      }
      final hasOnlyDefaults = wallets.length <= 3 &&
          wallets.every((w) => w.initialBalance == 0) &&
          wallets.any((w) => w.id == 'wallet_tcb' || w.id == 'wallet_cash');

      if (hasOnlyDefaults) {
        _box.clear();
        _seedDefaultWallets();
      }
      _box.put('seeded_v2_cash_only', 'true');
    }
  }

  /// Lấy toàn bộ danh sách ví, nếu rỗng thì tạo danh sách mặc định (chỉ có Tiền mặt)
  static List<WalletModel> getWallets() {
    ensureOnlyCashDefaultSeeded();

    final list = <WalletModel>[];
    for (final raw in _box.values) {
      try {
        list.add(WalletModel.fromJson(raw));
      } catch (_) {}
    }

    list.sort((a, b) {
      if (a.isDefault) return -1;
      if (b.isDefault) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });

    return list;
  }

  /// Lấy ví mặc định (dùng khi quét QR thanh toán hoặc chuyển tiền)
  static WalletModel? getDefaultWallet() {
    final wallets = getWallets();
    try {
      return wallets.firstWhere((w) => w.isDefault);
    } catch (_) {
      return wallets.isNotEmpty ? wallets.first : null;
    }
  }

  /// Lấy thông tin 1 ví theo ID
  static WalletModel? getWallet(String walletId) {
    final raw = _box.get(walletId);
    if (raw == null) return null;
    try {
      return WalletModel.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Đặt 1 ví làm mặc định và hủy mặc định ở các ví khác
  static Future<void> setDefaultWallet(String walletId) async {
    final wallets = getWallets();
    for (final w in wallets) {
      final updated = w.copyWith(isDefault: (w.id == walletId));
      await _box.put(updated.id, updated.toJson());
    }
  }

  /// Lưu hoặc cập nhật một ví
  static Future<void> saveWallet(WalletModel wallet) async {
    // Nếu ví này được đánh dấu mặc định, bỏ mặc định ở các ví khác
    if (wallet.isDefault) {
      final wallets = getWallets();
      for (final w in wallets) {
        if (w.id != wallet.id && w.isDefault) {
          final updated = w.copyWith(isDefault: false);
          await _box.put(updated.id, updated.toJson());
        }
      }
    }
    await _box.put(wallet.id, wallet.toJson());
  }

  /// Xóa một ví (chỉ xóa nếu còn nhiều hơn 1 ví)
  static Future<bool> deleteWallet(String walletId) async {
    final wallets = getWallets();
    if (wallets.length <= 1) return false;

    await _box.delete(walletId);

    // Nếu vừa xóa ví mặc định, chọn ví đầu tiên làm mặc định mới
    final remaining = getWallets();
    if (remaining.isNotEmpty && !remaining.any((w) => w.isDefault)) {
      await setDefaultWallet(remaining.first.id);
    }
    return true;
  }

  /// Điều chỉnh số dư ví thủ công (Reconcile)
  static Future<void> adjustBalance(String walletId, double newBalance) async {
    final raw = _box.get(walletId);
    if (raw == null) return;

    final wallet = WalletModel.fromJson(raw);
    final updated = wallet.copyWith(initialBalance: newBalance);
    await _box.put(walletId, updated.toJson());
  }

  /// Tính tổng số dư của tất cả các ví
  static double getTotalBalance() {
    final wallets = getWallets();
    double total = 0;
    for (final w in wallets) {
      total += w.initialBalance;
    }
    return total;
  }

  /// Khởi tạo mặc định: Chỉ có duy nhất ví Tiền mặt (được đặt làm mặc định)
  static void _seedDefaultWallets() {
    final now = DateTime.now();

    final cashWallet = WalletModel(
      id: 'wallet_cash',
      name: 'Tiền mặt',
      bankId: null,
      bankBin: null,
      initialBalance: 0,
      isDefault: true,
      colorValue: const Color(0xFF20C997).toARGB32(),
      createdAt: now,
    );

    _box.put(cashWallet.id, cashWallet.toJson());
  }
}
