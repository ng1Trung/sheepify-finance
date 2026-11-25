import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/bank_alert_parser.dart';
import '../models/transaction.dart';
import 'pending_transfer_service.dart';

/// A bank alert waiting for the user to log (or dismiss) it.
class BankInboxItem {
  final String id;
  final String appName;
  final DateTime time;
  final double amount;
  final bool isExpense;
  final String note;

  const BankInboxItem({
    required this.id,
    required this.appName,
    required this.time,
    required this.amount,
    required this.isExpense,
    required this.note,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'appName': appName,
    'time': time.toIso8601String(),
    'amount': amount,
    'isExpense': isExpense,
    'note': note,
  };

  factory BankInboxItem.fromMap(Map<String, dynamic> m) => BankInboxItem(
    id: m['id'] as String,
    appName: m['appName'] as String? ?? '',
    time: DateTime.tryParse(m['time'] as String? ?? '') ?? DateTime.now(),
    amount: (m['amount'] as num).toDouble(),
    isExpense: m['isExpense'] as bool? ?? true,
    note: m['note'] as String? ?? '',
  );
}

class BankInboxSyncResult {
  /// Sheepify transfers confirmed because the bank reported them.
  final List<Transaction> autoConfirmed;

  /// Alerts added to the inbox by this sync.
  final int added;

  const BankInboxSyncResult(this.autoConfirmed, this.added);
}

/// Bridge to the Android side: bank notifications seen by the listener
/// service, and images shared to Sheepify. Android only; elsewhere every
/// call is a harmless no-op.
class BankInboxService {
  static const MethodChannel _channel = MethodChannel('sheepify/inbox');

  /// Fires when the native side has something new (alert or shared image).
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static bool _handlerSet = false;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Box<String>? get _box =>
      Hive.isBoxOpen(kBankInboxBox) ? Hive.box<String>(kBankInboxBox) : null;

  static void ensureListening() {
    if (_handlerSet || !isSupported) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'inboxChanged') changes.value++;
    });
  }

  static Future<T?> _invoke<T>(String method) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } catch (e) {
      debugPrint('BankInboxService.$method failed: $e');
      return null;
    }
  }

  static Future<bool> isListenerEnabled() async =>
      await _invoke<bool>('isListenerEnabled') ?? false;

  static Future<void> openListenerSettings() =>
      _invoke<void>('openListenerSettings');

  static Future<String?> takeSharedImage() => _invoke<String>('takeSharedImage');

  static Future<bool> takeOpenInboxRequest() async =>
      await _invoke<bool>('takeOpenInboxRequest') ?? false;

  static List<BankInboxItem> items() {
    final box = _box;
    if (box == null) return const [];
    final list = <BankInboxItem>[];
    for (final raw in box.values) {
      try {
        list.add(BankInboxItem.fromMap(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  /// Pulls new alerts from Android. A bank debit that matches a transfer
  /// started from Sheepify confirms that transfer instead of adding a second
  /// entry; everything else waits in the inbox for one-tap logging.
  static Future<BankInboxSyncResult> sync() async {
    final raw = await _invoke<String>('drainBankAlerts');
    final box = _box;
    if (raw == null || box == null) return const BankInboxSyncResult([], 0);

    List<dynamic> alerts;
    try {
      alerts = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return const BankInboxSyncResult([], 0);
    }

    final confirmed = <Transaction>[];
    var added = 0;
    for (final a in alerts.whereType<Map<String, dynamic>>()) {
      final parsed = BankAlertParser.parse(a['text'] as String? ?? '');
      if (parsed == null) continue;
      final time = DateTime.fromMillisecondsSinceEpoch(
        (a['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );

      if (parsed.isExpense) {
        final match = _matchingPendingTransfer(parsed.amount, time);
        if (match != null) {
          final tx = await PendingTransferService.confirmTransfer(match);
          if (tx != null) confirmed.add(tx);
          continue;
        }
      }

      final id = a['id'] as String? ?? '${time.millisecondsSinceEpoch}';
      if (box.containsKey(id)) continue;
      final item = BankInboxItem(
        id: id,
        appName: a['app'] as String? ?? '',
        time: time,
        amount: parsed.amount,
        isExpense: parsed.isExpense,
        note: parsed.note,
      );
      await box.put(id, jsonEncode(item.toMap()));
      added++;
    }
    return BankInboxSyncResult(confirmed, added);
  }

  /// A pending Sheepify transfer for the same amount, started up to 3 hours
  /// before the bank reported the debit.
  static String? _matchingPendingTransfer(double amount, DateTime alertTime) {
    final candidates = PendingTransferService.getPendingTransfers().where((p) {
      final gap = alertTime.difference(p.createdAt);
      return (p.amount - amount).abs() < 1 &&
          gap > const Duration(minutes: -5) &&
          gap < const Duration(hours: 3);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return candidates.isEmpty ? null : candidates.first.id;
  }

  static Future<Transaction> record(
    BankInboxItem item, {
    required String categoryId,
    String? note,
  }) async {
    final tx = Transaction(
      id: Transaction.createId(),
      note: (note ?? item.note).trim(),
      amount: item.amount,
      date: item.time,
      isExpense: item.isExpense,
      categoryId: categoryId,
    );
    await Hive.box<Transaction>(kMoneyBox).put(tx.id, tx);
    await _box?.delete(item.id);
    return tx;
  }

  static Future<void> dismiss(BankInboxItem item) async {
    await _box?.delete(item.id);
  }
}
