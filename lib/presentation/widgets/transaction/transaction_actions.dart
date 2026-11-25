import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/l10n.dart';
import '../../../data/models/transaction.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/pending_transfer_service.dart';
import '../../../data/services/wallet_service.dart';
import '../common/sheep_notifications.dart';

class TransactionActions {
  /// Deletes [tx] right away and shows a toast with an "Undo" button that
  /// restores an identical copy. The attached image file is kept on disk so
  /// undo can bring it back.
  static Future<void> deleteWithUndo(
    BuildContext context,
    Transaction tx,
  ) async {
    final l10n = L10n.of(context);
    if (tx.isPending) {
      // Drops the pending-transfer record and marks the tx cancelled, so an
      // undo brings it back as cancelled rather than half-pending.
      await PendingTransferService.cancelTransfer(tx.id);
    }
    final snapshot = Transaction(
      id: tx.id,
      note: tx.note,
      amount: tx.amount,
      date: tx.date,
      isExpense: tx.isExpense,
      categoryId: tx.categoryId,
      imagePath: tx.imagePath,
      status: tx.status,
      walletId: tx.walletId,
    );

    // A completed transfer paid from a wallet already reduced that wallet;
    // deleting the record gives the money back (and undo takes it again).
    final walletId = snapshot.isCompleted ? snapshot.walletId : null;
    await _adjustWallet(walletId, snapshot.amount);

    await tx.delete();
    unawaited(NotificationService.checkDailyReminderReschedule());
    unawaited(
      NotificationService.showTransactionActionNotification(
        action: TransactionActionType.deleted,
        note: snapshot.note,
        amount: snapshot.amount,
      ),
    );
    if (!context.mounted) return;

    SheepNotifications.showWithAction(
      context,
      l10n.get('delete_success'),
      actionLabel: l10n.get('undo'),
      onAction: () {
        final box = Hive.box<Transaction>(kMoneyBox);
        // Payment transactions are keyed by id; older manual ones by index.
        if (snapshot.id.isNotEmpty) {
          box.put(snapshot.id, snapshot);
        } else {
          box.add(snapshot);
        }
        unawaited(_adjustWallet(walletId, -snapshot.amount));
        unawaited(NotificationService.checkDailyReminderReschedule());
      },
    );
  }

  static Future<void> _adjustWallet(String? walletId, double delta) async {
    if (walletId == null) return;
    try {
      final wallet = WalletService.getWallet(walletId);
      if (wallet != null) {
        await WalletService.adjustBalance(
          wallet.id,
          wallet.initialBalance + delta,
        );
      }
    } catch (_) {}
  }
}
