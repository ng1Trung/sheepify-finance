import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/constants.dart';
import '../../core/utils/category_util.dart';
import '../../core/utils/financial_cycle_util.dart';
import '../../core/utils/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../models/category_model.dart';
import '../models/settings_model.dart';
import '../models/transaction.dart';
import '../../presentation/widgets/common/sheep_dialogs.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'sheepify_daily_reminder';
  static const String channelName = 'Sheepify Daily Reminder';
  static const String channelDescription = 'Daily reminders to log your financial transactions';
  static const int reminderNotificationId = 999;

  // Initialize the notification service
  static Future<void> initialize() async {
    // 1. Initialize Timezones
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (_) {}

    // 2. Initialize Flutter Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle when notification is clicked
      },
    );

    // Request permissions for Android 13+ and iOS
    await requestPermissions();

    // 3. Schedule the reminder
    await checkDailyReminderReschedule();
  }

  // Request notification permissions
  static Future<void> requestPermissions() async {
    try {
      // Android Permission request
      final androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      // iOS Permission request
      final iosImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {}
  }

  // Check if a specific notification threshold has already been triggered in a cycle
  static bool _hasBeenTriggered({
    required String categoryId,
    required String type,
    required double threshold,
    required DateTime cycleStart,
  }) {
    final box = Hive.box('notifications');
    for (final item in box.values) {
      if (item is Map) {
        final itemCatId = item['categoryId'] as String?;
        final itemType = item['type'] as String?;
        final itemThreshold = (item['threshold'] as num?)?.toDouble();
        final itemCycleStartStr = item['cycleStart'] as String?;

        if (itemCatId == categoryId &&
            itemType == type &&
            itemThreshold == threshold &&
            itemCycleStartStr != null) {
          final itemCycleStart = DateTime.parse(itemCycleStartStr);
          if (itemCycleStart.year == cycleStart.year &&
              itemCycleStart.month == cycleStart.month &&
              itemCycleStart.day == cycleStart.day) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // Create and log a new notification
  static Future<void> _createInAppNotification({
    required String title,
    required String content,
    required String type,
    String? categoryId,
    double? threshold,
    required DateTime cycleStart,
  }) async {
    final box = Hive.box('notifications');
    final newNotification = {
      'id': 'notif_${DateTime.now().microsecondsSinceEpoch}',
      'title': title,
      'content': content,
      'dateTime': DateTime.now().toIso8601String(),
      'isRead': false,
      'type': type,
      'categoryId': categoryId,
      'threshold': threshold,
      'cycleStart': cycleStart.toIso8601String(),
    };
    await box.add(newNotification);
  }

  // Trigger checking for budget and savings goal progress
  static Future<void> checkAndTriggerNotifications(
    BuildContext context,
    String categoryId,
    DateTime txDate,
  ) async {
    final l10n = L10n.of(context);
    final catBox = Hive.box<CategoryModel>(kCatBox);
    
    CategoryModel cat;
    try {
      cat = catBox.values.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return;
    }

    final double spent = CategoryUtil.calculateCategorySpent(cat, now: txDate);
    final int typeIndex = cat.effectiveTypeIndex;

    // Check rescheduling of Daily Reminder since a transaction was added/modified
    await checkDailyReminderReschedule();

    if (typeIndex == 0) {
      // EXPENSE BUDGETING CHECKS
      final double? budget = cat.budget;
      if (budget == null || budget <= 0) return;

      final double spentPercent = spent / budget;
      final settings = Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
      final cycleRange = FinancialCycleUtil.cycleRangeFor(txDate, settings.financialCycleStartDay);
      final cycleStart = cycleRange.start;

      // 1. Exceeded (> 100%)
      if (spentPercent > 1.0) {
        final threshold = 1.0;
        if (!_hasBeenTriggered(
          categoryId: cat.id,
          type: 'budget_exceeded',
          threshold: threshold,
          cycleStart: cycleStart,
        )) {
          final title = l10n.get('budget_exceeded_title');
          final content = l10n.get('budget_exceeded_body', params: {'name': cat.name});

          await _createInAppNotification(
            title: title,
            content: content,
            type: 'budget_exceeded',
            categoryId: cat.id,
            threshold: threshold,
            cycleStart: cycleStart,
          );



          // Show dialog with sad wallet Lottie
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (_) => SheepGoalDialog(
                title: title,
                message: content,
                color: AppColors.expense,
                isSuccess: false,
                buttonLabel: l10n.get('understood'),
              ),
            );
          }
        }
        return;
      }

      // 2. Thresholds (100%, 90%, 80%, 50%)
      final List<double> thresholds = [1.0, 0.9, 0.8, 0.5];
      for (final threshold in thresholds) {
        if (spentPercent >= threshold) {
          if (!_hasBeenTriggered(
            categoryId: cat.id,
            type: 'budget_threshold',
            threshold: threshold,
            cycleStart: cycleStart,
          )) {
            final int percentText = (threshold * 100).round();
            final title = l10n.get('budget_threshold_title', params: {'name': cat.name});
            final content = l10n.get(
              'budget_threshold_body',
              params: {
                'percent': percentText.toString(),
                'name': cat.name,
              },
            );

            await _createInAppNotification(
              title: title,
              content: content,
              type: 'budget_threshold',
              categoryId: cat.id,
              threshold: threshold,
              cycleStart: cycleStart,
            );


          }
          break; // Notify only the highest reached threshold
        }
      }
    } else if (typeIndex == 2) {
      // SAVINGS GOALS CHECKS
      final double? targetAmount = cat.targetAmount;
      if (targetAmount == null || targetAmount <= 0) return;

      final double progressPercent = spent / targetAmount;
      // For goals, if periodic (goalType == 1) we track cycle. If long-term (goalType == 2) we track forever (start = epoch)
      final DateTime cycleStart;
      if (cat.effectiveGoalTypeIndex == 1) {
        final settings = Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
        final cycleRange = FinancialCycleUtil.cycleRangeFor(txDate, settings.financialCycleStartDay);
        cycleStart = cycleRange.start;
      } else {
        cycleStart = DateTime.fromMillisecondsSinceEpoch(0); // Epoch start for long-term goal
      }

      // 1. Completed (100%) - Only triggered once
      if (progressPercent >= 1.0) {
        final threshold = 1.0;
        if (!_hasBeenTriggered(
          categoryId: cat.id,
          type: 'savings_completed',
          threshold: threshold,
          cycleStart: cycleStart,
        )) {
          final title = l10n.get('savings_completed_title');
          final content = l10n.get('savings_completed_body', params: {'name': cat.name});

          await _createInAppNotification(
            title: title,
            content: content,
            type: 'savings_completed',
            categoryId: cat.id,
            threshold: threshold,
            cycleStart: cycleStart,
          );



          // Show congrats dialog with fireworks Lottie
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (_) => SheepGoalDialog(
                title: title,
                message: content,
                color: AppColors.savings,
                isSuccess: true,
                buttonLabel: l10n.get('awesome'),
              ),
            );
          }
        }
        return;
      }

      // 2. Milestones (90%, 80%, 50%)
      final List<double> milestones = [0.9, 0.8, 0.5];
      for (final threshold in milestones) {
        if (progressPercent >= threshold) {
          if (!_hasBeenTriggered(
            categoryId: cat.id,
            type: 'savings_halfway',
            threshold: threshold,
            cycleStart: cycleStart,
          )) {
            final int percentText = (threshold * 100).round();
            final title = l10n.get('savings_halfway_title');
            final content = l10n.get(
              'savings_halfway_body',
              params: {
                'percent': percentText.toString(),
                'name': cat.name,
              },
            );

            await _createInAppNotification(
              title: title,
              content: content,
              type: 'savings_halfway',
              categoryId: cat.id,
              threshold: threshold,
              cycleStart: cycleStart,
            );


          }
          break; // Notify only the highest reached milestone
        }
      }
    }
  }

  // Check if there are any transactions logged today, and schedule/cancel 21:00 reminder
  static Future<void> checkDailyReminderReschedule() async {
    final txBox = Hive.box<Transaction>(kMoneyBox);
    final now = DateTime.now();

    // Check if any transaction has been logged today (same year, month, day)
    final bool hasTransactionToday = txBox.values.any((tx) =>
        tx.date.year == now.year &&
        tx.date.month == now.month &&
        tx.date.day == now.day);

    if (hasTransactionToday) {
      // User has logged transaction today. Cancel today's 21:00 alarm.
      // But schedule for tomorrow 21:00 to keep the discipline.
      await _scheduleDailyNotification(tomorrow: true);
    } else {
      // User hasn't logged anything today. Check if it's already past 21:00.
      if (now.hour >= 21) {
        // Already past 21:00 today, schedule for tomorrow 21:00
        await _scheduleDailyNotification(tomorrow: true);
      } else {
        // Schedule for today 21:00
        await _scheduleDailyNotification(tomorrow: false);
      }
    }
  }

  // Schedule/reschedule the daily notification at 21:00
  static Future<void> _scheduleDailyNotification({required bool tomorrow}) async {
    // Cancel existing reminder first
    await _localNotificationsPlugin.cancel(reminderNotificationId);

    // Get 21:00 target time
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, 21, 0, 0);
    if (tomorrow) {
      target = target.add(const Duration(days: 1));
    }

    final scheduledTime = tz.TZDateTime.from(target, tz.local);

    // Android details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    // iOS/Darwin details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Vietnamese localized title & body since the daily reminder is static
    // We hardcode these to match the daily reminder requirement precisely
    const String title = '🐑 Cuối ngày rồi, Sheepify chút không?';
    const String body = 'Dành 5 giây để ghi lại các khoản chi tiêu hôm nay để giữ thói quen kỷ luật nào!';

    await _localNotificationsPlugin.zonedSchedule(
      reminderNotificationId,
      title,
      body,
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
    );
  }
}
