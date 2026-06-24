import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/category_util.dart';
import '../../core/utils/financial_cycle_util.dart';
import '../../core/utils/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../models/category_model.dart';
import '../models/settings_model.dart';
import '../models/transaction.dart';
import '../../presentation/widgets/common/sheep_dialogs.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final ValueNotifier<String?> selectNotificationStream =
      ValueNotifier<String?>(null);

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'sheepify_daily_reminder';
  static const String channelName = 'Sheepify Daily Reminder';
  static const String channelDescription =
      'Daily reminders to log your financial transactions';
  static const int reminderNotificationId = 999;
  static const int weeklyStatsNotificationId = 998;

  // Initialize the notification service
  static Future<void> initialize() async {
    // 1. Initialize Timezones
    tz.initializeTimeZones();
    try {
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      } catch (_) {}
    }

    // 2. Initialize Flutter Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null) {
          selectNotificationStream.value = details.payload;
        }
      },
    );

    // Check if the app was launched by clicking a notification
    final NotificationAppLaunchDetails? launchDetails =
        await _localNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) {
        selectNotificationStream.value = payload;
      }
    }

    // Request permissions for Android 13+ and iOS only if explicitly enabled
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    if (settings.enableNotifications == true) {
      await requestPermissions();
    }

    // 3. Schedule the reminder
    await checkDailyReminderReschedule();
  }

  // Request notification permissions
  static Future<void> requestPermissions() async {
    try {
      // Android Permission request
      final androidImplementation = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      // iOS Permission request
      final iosImplementation = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
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

  // Show an instant local notification
  static Future<void> _showInstantNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'sheepify_alerts',
          'Sheepify Alerts',
          channelDescription: 'Alerts for budgets and savings goals',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
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

    // Trigger local system notification on device ONLY if enabled
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    if (settings.enableNotifications == true) {
      final cleanTitle = title.replaceAll('<b>', '').replaceAll('</b>', '');
      final cleanBody = content.replaceAll('<b>', '').replaceAll('</b>', '');
      await _showInstantNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: cleanTitle,
        body: cleanBody,
        payload: type,
      );
    }
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
      final settings =
          Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
      final cycleRange = FinancialCycleUtil.cycleRangeFor(
        txDate,
        settings.financialCycleStartDay,
      );
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
          final content = l10n.get(
            'budget_exceeded_body',
            params: {'name': cat.name},
          );

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
            final title = l10n.get(
              'budget_threshold_title',
              params: {'name': cat.name},
            );
            final content = l10n.get(
              'budget_threshold_body',
              params: {'percent': percentText.toString(), 'name': cat.name},
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
        final settings =
            Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
        final cycleRange = FinancialCycleUtil.cycleRangeFor(
          txDate,
          settings.financialCycleStartDay,
        );
        cycleStart = cycleRange.start;
      } else {
        cycleStart = DateTime.fromMillisecondsSinceEpoch(
          0,
        ); // Epoch start for long-term goal
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
          final content = l10n.get(
            'savings_completed_body',
            params: {'name': cat.name},
          );

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
              params: {'percent': percentText.toString(), 'name': cat.name},
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

  // Calculate current transaction logging streak
  static int _calculateTransactionStreak() {
    final completedDayKeys = <String>{
      ...Hive.box<Transaction>(kMoneyBox).values.map((tx) {
        final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
        return DateFormat('yyyy-MM-dd').format(day);
      }),
      if (Hive.isBoxOpen(kStreakBox))
        ...Hive.box(kStreakBox).keys
            .whereType<String>()
            .where((key) => key.startsWith('completed:'))
            .where((key) => Hive.box(kStreakBox).get(key) == true)
            .map((key) => key.substring('completed:'.length)),
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    var cursor = completedDayKeys.contains(todayKey) ? today : yesterday;
    var streak = 0;

    while (true) {
      final cursorKey = DateFormat('yyyy-MM-dd').format(cursor);
      if (completedDayKeys.contains(cursorKey)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // Cancel all scheduled notifications
  static Future<void> cancelAll() async {
    await _localNotificationsPlugin.cancelAll();
  }

  // Check if there are any transactions logged today, and schedule/cancel 21:00 reminder
  static Future<void> checkDailyReminderReschedule() async {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    if (settings.enableNotifications == false) {
      await cancelAll();
      return;
    }

    final now = DateTime.now();

    // We always schedule for 21:00.
    // If it's already past 21:00 today, schedule for tomorrow 21:00 (since we don't know tomorrow's transactions yet, we pass hasTransactions: false).
    if (now.hour >= 21) {
      await _scheduleDailyNotification(tomorrow: true, hasTransactions: false);
    } else {
      // It's before 21:00. Schedule for today 21:00.
      final txBox = Hive.box<Transaction>(kMoneyBox);
      final todayTransactions = txBox.values
          .where(
            (tx) =>
                tx.date.year == now.year &&
                tx.date.month == now.month &&
                tx.date.day == now.day,
          )
          .toList();

      await _scheduleDailyNotification(
        tomorrow: false,
        hasTransactions: todayTransactions.isNotEmpty,
        transactionsCount: todayTransactions.length,
        todayTransactions: todayTransactions,
      );
    }

    // Also schedule weekly stats reminder
    await checkWeeklyStatsReschedule();
  }

  // Schedule/reschedule the daily notification at 21:00
  static Future<void> _scheduleDailyNotification({
    required bool tomorrow,
    required bool hasTransactions,
    int transactionsCount = 0,
    List<Transaction> todayTransactions = const [],
  }) async {
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
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

    // Generate dynamic title & body with youthful design, insights and streak
    String title;
    String body;

    if (!hasTransactions) {
      // Reminder mode
      title = '🐑 Cuối ngày rồi, Sheepify chút không?';
      body =
          'Hôm nay bạn chưa ghi chép khoản nào. Hãy dùng Voice AI 🎙️ hoặc Scan tự động 📸 để ghi chép trong 5 giây nhé!';
    } else {
      // Insight mode
      final double todayExpense = todayTransactions
          .where((tx) => tx.isExpense)
          .fold(0.0, (sum, tx) => sum + tx.amount);
      final double todayIncome = todayTransactions
          .where((tx) => !tx.isExpense)
          .fold(0.0, (sum, tx) => sum + tx.amount);
      final int streak = _calculateTransactionStreak();

      title = '🔥 Giữ vững kỷ luật chi tiêu!';

      if (todayExpense > 0 && todayIncome > 0) {
        body =
            'Hôm nay bạn đã chi ${CurrencyUtil.formatCompact(todayExpense)} và thu ${CurrencyUtil.formatCompact(todayIncome)}. ';
      } else if (todayExpense > 0) {
        body =
            'Hôm nay bạn đã chi tiêu ${CurrencyUtil.formatCompact(todayExpense)}. ';
      } else if (todayIncome > 0) {
        body =
            'Hôm nay bạn đã ghi nhận thu nhập ${CurrencyUtil.formatCompact(todayIncome)}. ';
      } else {
        body = 'Hôm nay bạn đã ghi nhận $transactionsCount giao dịch. ';
      }

      if (streak > 0) {
        body +=
            'Bạn đã giữ vững chuỗi $streak ngày liên tiếp! Tiến lên nào! 🚀';
      } else {
        body += 'Cố gắng duy trì thói quen ghi chép mỗi ngày nhé! 🌟';
      }
    }

    await _localNotificationsPlugin.zonedSchedule(
      reminderNotificationId,
      title,
      body,
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeat daily at this time
      payload: 'daily_reminder',
    );
  }

  // Get next instance of weekday at a given time
  static tz.TZDateTime _nextInstanceOfWeekdayAt(
    int weekday,
    int hour,
    int minute,
  ) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Check and reschedule weekly stats notification on Sundays at 20:30
  static Future<void> checkWeeklyStatsReschedule() async {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    if (settings.enableNotifications == false) {
      await _localNotificationsPlugin.cancel(weeklyStatsNotificationId);
      return;
    }

    final now = DateTime.now();
    final txBox = Hive.box<Transaction>(kMoneyBox);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weekTransactions = txBox.values
        .where((tx) => tx.date.isAfter(sevenDaysAgo))
        .toList();

    final double totalExpense = weekTransactions
        .where((tx) => tx.isExpense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final double totalIncome = weekTransactions
        .where((tx) => !tx.isExpense)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    String title = '📊 Báo cáo tài chính tuần này của bạn!';
    String body;

    if (weekTransactions.isEmpty) {
      body =
          'Tuần này bạn chưa ghi chép giao dịch nào. Hãy vào xem và thiết lập kế hoạch tài chính cho tuần tới nhé! 🐑';
    } else {
      if (totalExpense > 0 && totalIncome > 0) {
        body =
            'Tuần này bạn đã chi tiêu ${CurrencyUtil.formatCompact(totalExpense)} và thu nhập ${CurrencyUtil.formatCompact(totalIncome)}. Nhấn để xem thống kê chi tiết! 📈';
      } else if (totalExpense > 0) {
        body =
            'Tuần này bạn đã chi tiêu tổng cộng ${CurrencyUtil.formatCompact(totalExpense)}. Hãy vào phân tích xem khoản nào tốn nhất nhé! 🧐';
      } else {
        body =
            'Tuần này bạn đã tích luỹ thêm ${CurrencyUtil.formatCompact(totalIncome)}. Tuyệt vời! Hãy tiếp tục phát huy nhé! 🎉';
      }
    }

    final scheduledTime = _nextInstanceOfWeekdayAt(DateTime.sunday, 20, 30);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'sheepify_weekly_stats',
          'Sheepify Weekly Statistics',
          channelDescription:
              'Weekly statistics report of your spending and income',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.cancel(weeklyStatsNotificationId);
    await _localNotificationsPlugin.zonedSchedule(
      weeklyStatsNotificationId,
      title,
      body,
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_stats',
    );
  }
}
