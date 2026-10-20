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
      expect(TransactionActionType.values.length, 4);
      expect(TransactionActionType.values, contains(TransactionActionType.created));
      expect(TransactionActionType.values, contains(TransactionActionType.updated));
      expect(TransactionActionType.values, contains(TransactionActionType.cancelled));
      expect(TransactionActionType.values, contains(TransactionActionType.deleted));
    });

    test('showTransferInitiatedNotification respects enableNotifications false', () async {
      final settings = AppSettings(enableNotifications: false);
      await Hive.box<AppSettings>(kSettingsBox).put('current', settings);

      // Should complete without error and return early when notifications are disabled
      await NotificationService.showTransferInitiatedNotification(
        sendingBankName: 'Techcombank',
        recipientBankName: 'TPBank',
        accountNo: '1234567890',
        amount: 50000,
        note: 'Ca phe',
        categoryName: 'Ăn uống',
      );
    });

    test('showTransactionActionNotification respects enableNotifications false', () async {
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
    });
  });
}
