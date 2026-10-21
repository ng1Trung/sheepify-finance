import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sheepify/core/constants/constants.dart';
import 'package:sheepify/data/models/settings_model.dart';
import 'package:sheepify/data/services/notification_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sheepify_notification_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(AppSettingsAdapter());
    await Hive.openBox<AppSettings>(kSettingsBox);
    await Hive.openBox('notifications');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('NotificationService Tests', () {
    test('TransactionActionType enum has expected values', () {
      expect(TransactionActionType.values.length, 5);
      expect(TransactionActionType.values, contains(TransactionActionType.created));
      expect(TransactionActionType.values, contains(TransactionActionType.updated));
      expect(TransactionActionType.values, contains(TransactionActionType.confirmed));
      expect(TransactionActionType.values, contains(TransactionActionType.cancelled));
      expect(TransactionActionType.values, contains(TransactionActionType.deleted));
    });

    test('showTransactionActionNotification respects enableNotifications false and logs to in-app box', () async {
      final notifBox = Hive.box('notifications');
      await notifBox.clear();

      final settings = AppSettings(enableNotifications: false);
      await Hive.box<AppSettings>(kSettingsBox).put('current', settings);

      for (final action in TransactionActionType.values) {
        await NotificationService.showTransactionActionNotification(
          action: action,
          note: 'Test $action',
          amount: 100000,
          categoryName: 'Ăn uống',
        );
      }

      expect(notifBox.length, 5);
      final types = notifBox.values.map((item) => (item as Map)['type']).toList();
      expect(types, [
        'transaction_created',
        'transaction_updated',
        'transaction_confirmed',
        'transaction_cancelled',
        'transaction_deleted',
      ]);
      final confirmedItem = notifBox.values.firstWhere((item) => (item as Map)['type'] == 'transaction_confirmed') as Map;
      expect(confirmedItem['isRead'], false);
      expect(confirmedItem['content'], contains('Đã xác nhận giao dịch'));
    });

    test('showTransactionActionNotification executes with enableNotifications true without error', () async {
      final notifBox = Hive.box('notifications');
      await notifBox.clear();

      final settings = AppSettings(enableNotifications: true);
      await Hive.box<AppSettings>(kSettingsBox).put('current', settings);

      for (final action in TransactionActionType.values) {
        await NotificationService.showTransactionActionNotification(
          action: action,
          note: 'Test $action',
          amount: 150000,
          categoryName: 'Ăn uống',
        );
      }
      expect(notifBox.length, 5);
    });
  });
}
