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

    test('showTransactionActionNotification executes with enableNotifications true without error', () async {
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
    });
  });
}
