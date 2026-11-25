import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_cropper/image_cropper.dart' as cropper;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/constants.dart';
import '../../data/models/category_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction.dart';
import '../widgets/transaction_form.dart';
import '../tabs/diary_tab.dart';
import '../tabs/category_tab.dart';
import '../tabs/stats_tab.dart';
import '../tabs/settings_tab.dart';
import '../widgets/category_form.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/avatar_image_store.dart';
import '../../core/utils/currency_util.dart';
import '../../core/utils/financial_cycle_util.dart';
import '../../core/utils/l10n.dart';

import 'package:line_icons/line_icons.dart';
import '../widgets/common/sheep_notifications.dart';
import '../widgets/common/sheep_dialogs.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_kit.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/wallet_service.dart';
import 'notifications_screen.dart';
import 'scanner/smart_qr_scanner_screen.dart';
import '../../data/services/pending_transfer_service.dart';
import '../widgets/payment/pending_transfer_prompt.dart';
import 'payment/quick_transfer_screen.dart';
import 'package:quick_actions/quick_actions.dart';
import '../../core/utils/transaction_image_store.dart';
import '../../data/services/bank_inbox_service.dart';
import '../../data/services/sheepify_scan_ai_service.dart';
import '../widgets/payment/bank_inbox_sheet.dart';
import 'wallet/wallet_management_screen.dart';

enum _DrawerInsightType { budget, cycle, savings, today, streak }

enum _AvatarAction { preview, change, delete }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0; // Bắt đầu từ Nhật ký
  int _diaryViewMode = 1; // 1: list, 2: gallery, 3: timeline

  // TIME AND VIEW MODE MANAGEMENT
  DateTime _selectedDate = DateTime.now();
  late DateTimeRange _diaryRange = _dayRange(DateTime.now());
  late final ValueListenable<Box<Transaction>> _moneyListenable;
  final _insightRandom = Random();
  bool _isDrawerOpen = false;
  DateTime? _drawerLastClosedAt;
  _DrawerInsightType? _activeInsightType;
  Timer? _foregroundTimer;
  DateTime? _lastForegroundTickAt;
  Future<void>? _streakBoxOpenFuture;

  static const Duration _insightRepickDelay = Duration(seconds: 180);
  static const int _dailyStreakCompletionSeconds = 30;

  // Smart Payment & Undo state
  Transaction? _pendingPaymentUndoTx;
  String? _pendingPaymentUndoWalletId;
  double? _pendingPaymentUndoAmount;
  Timer? _undoPaymentTimer;
  int _undoCountdown = 15;

  static DateTimeRange _dayRange(DateTime date) {
    return DateTimeRange(
      start: DateTime(date.year, date.month, date.day),
      end: DateTime(date.year, date.month, date.day, 23, 59, 59),
    );
  }

  DateTimeRange _currentCycleRange({DateTime? date}) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    return FinancialCycleUtil.cycleRangeFor(
      date ?? DateTime.now(),
      settings.financialCycleStartDay,
    );
  }

  static DateTimeRange _monthRange(DateTime date) {
    return DateTimeRange(
      start: DateTime(date.year, date.month, 1),
      end: DateTime(date.year, date.month + 1, 0, 23, 59, 59),
    );
  }

  final _catBox = Hive.box<CategoryModel>(kCatBox);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _moneyListenable = Hive.box<Transaction>(kMoneyBox).listenable();
    _moneyListenable.addListener(_handleTransactionEvents);
    _diaryRange = _currentCycleRange();
    _seedParentCategories();
    _activeInsightType = _pickRandomInsightType();
    unawaited(_prepareStreakTracking());
    unawaited(NotificationService.initialize());
    NotificationService.selectNotificationStream.addListener(
      _handleNotificationPayload,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationPayload();
      // Cold start after paying in the bank app: settle it right away.
      Future.delayed(const Duration(milliseconds: 600), _onAppActive);
    });
    _setUpHomeShortcuts();
    BankInboxService.ensureListening();
    BankInboxService.changes.addListener(_onNativeInboxChange);
  }

  /// Android reported a bank alert / shared image. Only act while the app is
  /// on screen; in the background the "Ghi sổ giao dịch này?" notification
  /// must stay up, and the next resume picks everything up.
  void _onNativeInboxChange() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _onAppActive();
    }
  }

  bool _isSyncingInbox = false;

  /// Runs whenever the app comes to the front (or Android reports a new bank
  /// alert / shared image): settle what happened outside the app.
  Future<void> _onAppActive() async {
    if (_isSyncingInbox || !mounted) return;
    _isSyncingInbox = true;
    try {
      final result = await BankInboxService.sync();
      if (!mounted) return;
      if (result.autoConfirmed.isNotEmpty) {
        final total = result.autoConfirmed.fold<double>(
          0,
          (sum, tx) => sum + tx.amount,
        );
        SheepNotifications.showSuccess(
          context,
          'Ngân hàng đã báo trừ ${CurrencyUtil.formatMoney(total, locale: 'vi_VN')}₫, đã tự xác nhận giúp bạn',
        );
      }

      final sharedImage = await BankInboxService.takeSharedImage();
      if (sharedImage != null && mounted) {
        await _logSharedReceipt(sharedImage);
        return;
      }

      final openInbox = await BankInboxService.takeOpenInboxRequest();
      if (!mounted) return;
      await PendingTransferPrompt.maybeShow(context);
      if (mounted && (openInbox || result.added > 0)) {
        await BankInboxSheet.show(context);
      }
    } finally {
      _isSyncingInbox = false;
    }
  }

  /// A receipt / bill image shared to Sheepify from another app.
  Future<void> _logSharedReceipt(String path) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    SheepNotifications.showInfo(context, 'Đang đọc biên lai…');
    final result = await SheepifyScanAIService.processInvoiceScan(XFile(path));
    if (!mounted) return;
    if (result == null) {
      SheepNotifications.showError(context, 'Không đọc được biên lai này');
      return;
    }
    final storedImage = await TransactionImageStore.saveFromSourcePath(path);
    if (!mounted) return;
    await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionForm(
        scannedData: result,
        scannedImagePath: storedImage,
      ),
    );
  }

  /// Long-press the launcher icon -> "Quét QR" / "Chuyển tiền": pay (and log)
  /// in one step without hunting through the app.
  void _setUpHomeShortcuts() {
    const quickActions = QuickActions();
    quickActions.initialize((type) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (type == 'scan_qr') {
        _openVietQrScanner();
      } else if (type == 'transfer') {
        _openQuickTransfer();
      }
    });
    quickActions.setShortcutItems(const [
      ShortcutItem(
        type: 'scan_qr',
        localizedTitle: 'Quét QR thanh toán',
        icon: 'ic_shortcut_qr',
      ),
      ShortcutItem(
        type: 'transfer',
        localizedTitle: 'Chuyển tiền',
        icon: 'ic_shortcut_send',
      ),
    ]).catchError((_) {});
  }

  Future<void> _openQuickTransfer() async {
    final tx = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(builder: (_) => const QuickTransferScreen()),
    );
    if (tx != null && mounted) {
      _onPaymentTransactionCreated(tx);
    }
  }

  @override
  void dispose() {
    _undoPaymentTimer?.cancel();
    BankInboxService.changes.removeListener(_onNativeInboxChange);
    NotificationService.selectNotificationStream.removeListener(
      _handleNotificationPayload,
    );
    _stopForegroundTracking();
    _moneyListenable.removeListener(_handleTransactionEvents);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleNotificationPayload() {
    final payload = NotificationService.selectNotificationStream.value;
    if (payload == null || !mounted) return;
    NotificationService.selectNotificationStream.value =
        null; // Clear so it doesn't trigger again

    if (payload != 'daily_reminder') {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    if (payload.startsWith(NotificationService.pendingTransferPayloadPrefix)) {
      final id = payload.substring(
        NotificationService.pendingTransferPayloadPrefix.length,
      );
      PendingTransferPrompt.showById(context, id);
      return;
    }

    if (payload == 'savings_completed' || payload == 'savings_halfway') {
      _selectTab(2); // Tab Tích lũy
    } else if (payload == 'budget_exceeded' || payload == 'budget_threshold') {
      _selectTab(3); // Tab Danh mục
    } else if (payload == 'weekly_stats') {
      _selectTab(1); // Tab Thống kê
    } else if (payload == 'daily_reminder') {
      _showAddTransactionForm(); // Mở Suggest Sheet
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startForegroundTracking();
      unawaited(NotificationService.checkDailyReminderReschedule());
      // Back from the bank app? Ask whether the transfer went through, and
      // pick up anything the bank reported meanwhile.
      Future.delayed(const Duration(milliseconds: 400), _onAppActive);
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopForegroundTracking();
    }
  }

  void _handleTransactionEvents() {
    _completeStreakDaysForTransactions();
    if (!Hive.isBoxOpen(kStreakBox)) {
      unawaited(_syncStreakAfterBoxOpen());
    }
    if (!_isDrawerOpen || !mounted) return;
    setState(() {
      _activeInsightType =
          _validInsightType(_activeInsightType) ?? _pickRandomInsightType();
    });
  }

  Future<void> _prepareStreakTracking() async {
    try {
      await _ensureStreakBoxOpen();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _completeStreakDaysForTransactions();
    _startForegroundTracking();
    setState(() {});
  }

  Future<void> _syncStreakAfterBoxOpen() async {
    try {
      await _ensureStreakBoxOpen();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _completeStreakDaysForTransactions();
    setState(() {});
  }

  Future<void> _ensureStreakBoxOpen() {
    if (Hive.isBoxOpen(kStreakBox)) {
      return Future.value();
    }
    return _streakBoxOpenFuture ??= Hive.openBox(kStreakBox)
        .then((_) {})
        .catchError((Object error) {
          _streakBoxOpenFuture = null;
          throw error;
        });
  }

  Box<dynamic>? _streakBoxOrNull({bool openIfNeeded = true}) {
    if (Hive.isBoxOpen(kStreakBox)) {
      return Hive.box(kStreakBox);
    }
    if (openIfNeeded) {
      unawaited(_ensureStreakBoxOpen().catchError((Object _) {}));
    }
    return null;
  }

  void _startForegroundTracking() {
    _lastForegroundTickAt = DateTime.now();
    _foregroundTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _trackForegroundTime(),
    );
  }

  void _stopForegroundTracking() {
    _trackForegroundTime(openIfNeeded: false);
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _lastForegroundTickAt = null;
  }

  void _trackForegroundTime({bool openIfNeeded = true}) {
    final now = DateTime.now();
    final lastTick = _lastForegroundTickAt;
    _lastForegroundTickAt = now;
    if (lastTick == null) return;

    final elapsedSeconds = now.difference(lastTick).inSeconds;
    if (elapsedSeconds <= 0) return;

    final todayKey = _dayKey(now);
    final completedKey = _streakCompletedKey(todayKey);
    final streakBox = _streakBoxOrNull(openIfNeeded: openIfNeeded);
    if (streakBox == null) return;
    if (streakBox.get(completedKey) == true) return;

    final activeKey = _streakActiveSecondsKey(todayKey);
    final previousSeconds = streakBox.get(activeKey) as int? ?? 0;
    final nextSeconds = previousSeconds + elapsedSeconds;
    streakBox.put(activeKey, nextSeconds);

    if (nextSeconds >= _dailyStreakCompletionSeconds) {
      streakBox.put(completedKey, true);
      if (mounted) setState(() {});
    }
  }

  void _completeStreakDaysForTransactions() {
    final streakBox = _streakBoxOrNull();
    if (streakBox == null) return;
    for (final tx in Hive.box<Transaction>(kMoneyBox).values) {
      if (tx.isCompleted) {
        streakBox.put(_streakCompletedKey(_dayKey(tx.date)), true);
      }
    }
  }

  void _handleDrawerChanged(bool isOpened) {
    final now = DateTime.now();
    if (!isOpened) {
      setState(() {
        _isDrawerOpen = false;
        _drawerLastClosedAt = now;
      });
      return;
    }

    final shouldPickInsight =
        _activeInsightType == null ||
        _drawerLastClosedAt == null ||
        now.difference(_drawerLastClosedAt!) >= _insightRepickDelay;

    setState(() {
      _isDrawerOpen = true;
      _activeInsightType = shouldPickInsight
          ? _pickRandomInsightType(excluding: _activeInsightType)
          : (_validInsightType(_activeInsightType) ?? _pickRandomInsightType());
    });
  }

  void _seedParentCategories() {
    final defaultCategories = [
      CategoryModel(
        id: 'cat_bill',
        name: 'Hoá đơn',
        iconCode: Icons.receipt.codePoint,
        isExpense: true,
        typeIndex: 0,
        colorValue: AppColors.expense.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_eat',
        name: 'Ăn uống',
        iconCode: Icons.restaurant.codePoint,
        isExpense: true,
        typeIndex: 0,
        colorValue: AppColors.expense.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_shop',
        name: 'Mua sắm',
        iconCode: Icons.shopping_cart.codePoint,
        isExpense: true,
        typeIndex: 0,
        colorValue: AppColors.expense.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_salary',
        name: 'Lương',
        iconCode: Icons.attach_money.codePoint,
        isExpense: false,
        typeIndex: 1,
        colorValue: AppColors.income.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_bonus',
        name: 'Thưởng',
        iconCode: Icons.card_giftcard.codePoint,
        isExpense: false,
        typeIndex: 1,
        colorValue: AppColors.income.toARGB32(),
      ),
      CategoryModel(
        id: 'cat_savings',
        name: 'Tiết kiệm',
        iconCode: Icons.savings.codePoint,
        isExpense: false,
        typeIndex: 2,
        colorValue: AppColors.savings.toARGB32(),
      ),
    ];

    if (_catBox.isEmpty) {
      _catBox.addAll(defaultCategories);
      return;
    }

    final defaultsById = {for (final cat in defaultCategories) cat.id: cat};
    final existingDefaults = _catBox.values
        .where((cat) => defaultsById.containsKey(cat.id))
        .toList();
    final needsLegacyMigration = existingDefaults.any((cat) {
      final defaultCategory = defaultsById[cat.id]!;
      return cat.id != 'cat_savings' &&
          (cat.isExpense != defaultCategory.isExpense ||
              cat.typeIndex != defaultCategory.typeIndex ||
              cat.colorValue == null);
    });

    for (final cat in existingDefaults) {
      final defaultCategory = defaultsById[cat.id]!;
      cat.isExpense = defaultCategory.isExpense;
      cat.typeIndex = defaultCategory.typeIndex;
      cat.colorValue ??= defaultCategory.colorValue;
      cat.save();
    }

    final hasSavingsDefault = existingDefaults.any(
      (cat) => cat.id == 'cat_savings',
    );
    if (needsLegacyMigration && !hasSavingsDefault) {
      _catBox.add(defaultsById['cat_savings']!);
    }
  }

  void _changeTime(int offset) {
    setState(() {
      if (_isDiaryTimeline) {
        _diaryRange = _monthRange(
          DateTime(_diaryRange.start.year, _diaryRange.start.month + offset),
        );
      } else if (_usesDateRange) {
        final start = _diaryRange.start.add(Duration(days: offset));
        final end = _diaryRange.end.add(Duration(days: offset));
        _diaryRange = DateTimeRange(start: start, end: end);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: offset));
      }
    });
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _selectedDate = DateTime.now();
      if (_tabUsesDateRange(index)) {
        _diaryRange = index == 0 && _diaryViewMode == 3
            ? _monthRange(DateTime.now())
            : _currentCycleRange();
      }
    });
  }

  Future<void> _pickTime() async {
    if (_isDiaryTimeline) {
      final picked = await SheepDatePicker.show(
        context: context,
        initialDate: _diaryRange.start,
        mode: SheepDateMode.month,
      );
      if (picked != null) {
        setState(() => _diaryRange = _monthRange(picked));
      }
      return;
    }

    if (_usesDateRange) {
      final picked = await SheepDateRangePicker.show(
        context: context,
        initialRange: _diaryRange,
      );
      if (picked != null) {
        setState(() => _diaryRange = picked);
      }
      return;
    }

    final picked = await SheepDatePicker.show(
      context: context,
      initialDate: _selectedDate,
      mode: SheepDateMode.day,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  bool get _usesDateRange => _tabUsesDateRange(_currentIndex);

  bool _tabUsesDateRange(int index) => index == 0 || index == 1;

  bool get _isDiaryTimeline => _currentIndex == 0 && _diaryViewMode == 3;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final headerBase = AppColors.getPalette(settings.themePresetName).primary;
    final headerForeground = headerBase.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;

    // PREMIUM APPBAR NAVIGATOR
    Widget buildAppBarTitle() {
      if (_currentIndex == 2) {
        return Text(
          l10n.savings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerForeground,
          ),
        );
      }
      if (_currentIndex == 3) {
        return Text(
          l10n.categories,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerForeground,
          ),
        );
      }
      if (_currentIndex == 4) {
        return Text(
          l10n.wallets,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerForeground,
          ),
        );
      }
      if (_currentIndex == 5) {
        return Text(
          l10n.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerForeground,
          ),
        );
      }

      if (!_usesDateRange) {
        return const SizedBox.shrink();
      }

      String dateText;
      final locale = Localizations.localeOf(context).toString();
      final isSingleDiaryDay =
          (_diaryRange.start.year == _diaryRange.end.year &&
          _diaryRange.start.month == _diaryRange.end.month &&
          _diaryRange.start.day == _diaryRange.end.day);
      final start = DateFormat('dd/MM/yyyy', locale).format(_diaryRange.start);
      final end = DateFormat('dd/MM/yyyy', locale).format(_diaryRange.end);
      dateText = start == end ? start : '$start - $end';

      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSingleDiaryDay) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: AppColors.getInteractiveAccent(
                    theme.brightness,
                    headerForeground,
                  ),
                ),
                onPressed: () => _changeTime(-1),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: SheepDatePill(label: dateText, onTap: _pickTime),
            ),
            if (isSingleDiaryDay) ...[
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.getInteractiveAccent(
                    theme.brightness,
                    headerForeground,
                  ),
                ),
                onPressed: () => _changeTime(1),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildBody() {
      switch (_currentIndex) {
        case 0:
          return DiaryTab(
            selectedRange: _diaryRange,
            selectedViewMode: _diaryViewMode,
            onViewModeChanged: (mode) {
              setState(() {
                final wasTimeline = _diaryViewMode == 3;
                _diaryViewMode = mode;
                if (mode == 3) {
                  _diaryRange = _monthRange(_diaryRange.start);
                } else if (wasTimeline) {
                  _diaryRange = _currentCycleRange(date: _diaryRange.start);
                }
              });
            },
          );
        case 1:
          return StatsTab(selectedRange: _diaryRange);
        case 2:
          return const CategoryTab(
            key: ValueKey('savings-tab'),
            initialTypeIndex: 2,
            showTypeToggle: false,
          );
        case 3:
          return const CategoryTab(key: ValueKey('categories-tab'));
        case 4:
          return const WalletManagementScreen(isTab: true);
        case 5:
          return const SettingsTab();
        default:
          return const SizedBox();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(theme.brightness),
      drawerScrimColor: const Color(0x6B000000),
      onDrawerChanged: _handleDrawerChanged,
      drawer: _buildSideMenu(context),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: headerBase,
        foregroundColor: headerForeground,
        iconTheme: IconThemeData(
          color: AppColors.getInteractiveAccent(
            theme.brightness,
            headerForeground,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        toolbarHeight: _usesDateRange ? 68 : 60,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            icon: Icon(
              Icons.menu_rounded,
              color: AppColors.getInteractiveAccent(
                theme.brightness,
                headerForeground,
              ),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: buildAppBarTitle(),
        actions: [
          if (_currentIndex == 0 || _currentIndex == 1) ...[
            IconButton(
              tooltip: 'Quét VietQR',
              icon: Icon(
                LineIcons.qrcode,
                color: AppColors.getInteractiveAccent(
                  theme.brightness,
                  headerForeground,
                ),
                size: 26,
              ),
              onPressed: _openVietQrScanner,
            ),
            const SizedBox(width: 2),
          ],
          if (_currentIndex == 2 || _currentIndex == 3 || _currentIndex == 4) ...[
            IconButton(
              tooltip: _currentIndex == 4 ? 'Thêm ví mới' : null,
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.getInteractiveAccent(
                  theme.brightness,
                  headerForeground,
                ),
                size: 28,
              ),
              onPressed: _currentIndex == 4
                  ? () => WalletManagementScreen.showAddOrEditWalletDialog(context)
                  : _showAddCategoryForm,
            ),
            const SizedBox(width: 4),
          ],
          _buildNotificationBell(context, headerForeground),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          buildBody(),
          if (_pendingPaymentUndoTx != null)
            _buildUndoPaymentBanner(context, headerBase),
        ],
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? Padding(
              padding: const EdgeInsets.only(bottom: 24.0, right: 8.0),
              child: FloatingActionButton(
                onPressed: _showAddTransactionForm,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNotificationBell(BuildContext context, Color color) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('notifications').listenable(),
      builder: (context, Box box, _) {
        final unreadCount = box.values
            .where((item) => item is Map && item['isRead'] == false)
            .length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_rounded,
                color: AppColors.getInteractiveAccent(
                  Theme.of(context).brightness,
                  color,
                ),
                size: 26,
              ),
              onPressed: () async {
                final result = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                if (result != null && mounted) {
                  _selectTab(result);
                }
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: SheepTypeScale.micro,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSideMenu(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final username = settings.userName ?? 'Jason';
    final headerBase = AppColors.getPalette(settings.themePresetName).primary;
    // Header text follows the palette's luminance (white on dark palettes,
    // black on light ones such as Golden Hour).
    final headerFg = headerBase.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final drawerWidth = MediaQuery.sizeOf(context).width * 0.82;
    final safePadding = MediaQuery.paddingOf(context);
    final streakCount = _calculateTransactionStreak();
    final overview = _buildFinancialOverview(settings);

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: AppColors.getSurface(theme.brightness),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(SheepRadius.sheet),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(SheepRadius.sheet),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 232,
              padding: EdgeInsets.fromLTRB(10, safePadding.top + 20, 10, 10),
              color: headerBase,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(l10n),
                              style: TextStyle(
                                color: headerFg.withValues(alpha: 0.86),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 22 / 16,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: headerFg,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                height: 36 / 30,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 48,
                        child: ValueListenableBuilder(
                          valueListenable: Hive.box<AppSettings>(
                            kSettingsBox,
                          ).listenable(),
                          builder: (context, settingsBox, _) {
                            final currentSettings =
                                settingsBox.get('current') ?? AppSettings();
                            final avatarFile = AvatarImageStore.resolve(
                              currentSettings.avatarImageRef,
                            );

                            return _DrawerAvatar(
                              username: username,
                              streakCount: streakCount,
                              avatarFile: avatarFile,
                              onTap: () =>
                                  _showAvatarActions(context, currentSettings),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _DrawerOverviewCard(
                    status: overview,
                    foreground: headerFg,
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder(
                    valueListenable: Hive.box<AppSettings>(
                      kSettingsBox,
                    ).listenable(),
                    builder: (context, settingsBox, _) {
                      final currentSettings =
                          settingsBox.get('current') ?? AppSettings();
                      return Row(
                        children: [
                          Expanded(
                            child: _DrawerCyclePill(
                              foreground: headerFg,
                              label: _formatCurrentCycleLabel(
                                context,
                                currentSettings,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _DrawerPrivacyButton(
                            foreground: headerFg,
                            isHidden: currentSettings.hideAmounts,
                            onPressed: () {
                              currentSettings.hideAmounts =
                                  !currentSettings.hideAmounts;
                              currentSettings.save();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: constraints.maxHeight < 430
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            10,
                            14,
                            10,
                            safePadding.bottom + 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDrawerItem(
                                context,
                                index: 0,
                                icon: Icons.receipt_long_rounded,
                                label: l10n.diary,
                              ),
                              _buildDrawerItem(
                                context,
                                index: 1,
                                icon: Icons.pie_chart_rounded,
                                label: l10n.stats,
                              ),
                              _buildDrawerItem(
                                context,
                                index: 2,
                                icon: Icons.savings_rounded,
                                label: l10n.savings,
                              ),
                              _buildDrawerItem(
                                context,
                                index: 3,
                                icon: Icons.sell_rounded,
                                label: l10n.categories,
                              ),
                              _buildDrawerItem(
                                context,
                                index: 4,
                                icon: Icons.account_balance_wallet_rounded,
                                label: l10n.wallets,
                              ),
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                color: AppColors.getBorder(theme.brightness),
                              ),
                              _buildDrawerItem(
                                context,
                                index: 5,
                                icon: Icons.settings_rounded,
                                label: l10n.settings,
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 14),
                                child: Text(
                                  'Sheepify v1.0.0',
                                  style: TextStyle(
                                    color: AppColors.getTextMuted(theme.brightness),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPaymentTransactionCreated(Transaction tx, {String? walletId, double? amount}) {
    _undoPaymentTimer?.cancel();
    setState(() {
      _pendingPaymentUndoTx = tx;
      _pendingPaymentUndoWalletId = walletId;
      _pendingPaymentUndoAmount = amount;
      _undoCountdown = 15;
      _selectedDate = tx.date;
      _diaryRange = _currentCycleRange(date: tx.date);
    });

    _undoPaymentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_undoCountdown > 1) {
          _undoCountdown--;
        } else {
          _pendingPaymentUndoTx = null;
          _pendingPaymentUndoWalletId = null;
          _pendingPaymentUndoAmount = null;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _undoPaymentTransaction() async {
    if (_pendingPaymentUndoTx == null) return;
    final tx = _pendingPaymentUndoTx!;
    final walletId = _pendingPaymentUndoWalletId;
    final refundAmount = _pendingPaymentUndoAmount ?? tx.amount;

    _undoPaymentTimer?.cancel();
    setState(() {
      _pendingPaymentUndoTx = null;
      _pendingPaymentUndoWalletId = null;
      _pendingPaymentUndoAmount = null;
    });

    // Read the state *before* removing anything: a pending transfer never
    // touched the wallet, a completed one did.
    final wasPending = tx.isPending;
    final wasCompleted = tx.isCompleted;
    final refundWalletId = walletId ?? tx.walletId;

    if (wasPending) {
      // Also drops the pending-transfer record so it can't be confirmed later.
      await PendingTransferService.cancelTransfer(tx.id);
    }
    if (tx.isInBox) {
      await tx.delete();
    } else {
      await Hive.box<Transaction>(kMoneyBox).delete(tx.id);
    }
    NotificationService.showTransactionActionNotification(
      action: TransactionActionType.deleted,
      note: tx.note,
      amount: tx.amount,
    );

    if (wasCompleted && refundWalletId != null) {
      try {
        final wallet = WalletService.getWallet(refundWalletId);
        if (wallet != null) {
          await WalletService.adjustBalance(
            wallet.id,
            wallet.initialBalance + refundAmount,
          );
        }
      } catch (_) {}
    }

    if (mounted) {
      SheepNotifications.showSuccess(
        context,
        'Đã hoàn tác và xóa giao dịch ${CurrencyUtil.formatMoney(tx.amount, locale: 'vi_VN')}₫',
      );
    }
  }

  Future<void> _openVietQrScanner() async {
    final tx = await Navigator.push<Transaction>(
      context,
      MaterialPageRoute(builder: (_) => const SmartQrScannerScreen()),
    );
    if (tx != null && mounted) {
      _onPaymentTransactionCreated(tx);
    }
  }

  Widget _buildUndoPaymentBanner(BuildContext context, Color accentColor) {
    final brightness = Theme.of(context).brightness;
    final tx = _pendingPaymentUndoTx!;

    return Positioned(
      left: SheepSpacing.page,
      right: SheepSpacing.page,
      bottom: 90,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(SheepRadius.lg),
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getSurface(brightness),
            borderRadius: BorderRadius.circular(SheepRadius.lg),
            border: Border.all(color: accentColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LineIcons.paperPlane,
                  color: AppColors.expense,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Đã ghi: -${CurrencyUtil.formatMoney(tx.amount, locale: 'vi_VN')}₫',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${_undoCountdown}s)',
                          style: SheepTextStyles.itemMeta(context).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      tx.note.isNotEmpty ? tx.note : 'Thanh toán chuyển khoản',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SheepTextStyles.itemMeta(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _undoPaymentTransaction,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.expense.withValues(alpha: 0.12),
                  foregroundColor: AppColors.expense,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SheepRadius.sm),
                  ),
                ),
                child: const Text(
                  'Hoàn tác',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.getTextSecondary(brightness),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _undoPaymentTimer?.cancel();
                  setState(() {
                    _pendingPaymentUndoTx = null;
                    _pendingPaymentUndoWalletId = null;
                    _pendingPaymentUndoAmount = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTransactionForm() async {
    final sourceIndex = _currentIndex;
    final resultDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionForm(
        initialDate: DateTime.now(),
        onPaymentTransactionCreated: _onPaymentTransactionCreated,
      ),
    );

    if (resultDate != null) {
      setState(() {
        _selectedDate = resultDate;
        _diaryRange = _currentCycleRange(date: resultDate);
        _currentIndex = sourceIndex == 1 ? 1 : 0;
      });
    }
  }

  Future<void> _showAddCategoryForm() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SheepRadius.sheet)),
      ),
      builder: (ctx) => CategoryForm(
        category: null,
        fixedTypeIndex: _currentIndex == 2 ? 2 : null,
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final settings = Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    final brightness = Theme.of(context).brightness;
    final selectedColor = AppColors.getInteractiveAccent(brightness, accentColor);
    final foreground = isSelected
        ? AppColors.getTextPrimary(brightness)
        : AppColors.getTextSecondary(brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? AppColors.getAccentSurface(brightness, accentColor)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(SheepRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(SheepRadius.md),
          overlayColor: WidgetStateProperty.all(accentColor.withValues(alpha: 0.08)),
          onTap: () {
            _selectTab(index);
            Navigator.of(context).pop();
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? selectedColor : foreground,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: SheepTypeScale.bodyLarge,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAvatarActions(
    BuildContext context,
    AppSettings settings,
  ) async {
    final avatarFile = AvatarImageStore.resolve(settings.avatarImageRef);
    final hasAvatar = avatarFile != null && avatarFile.existsSync();
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheepDragHandle(),
                const SizedBox(height: 14),
                _AvatarActionTile(
                  icon: Icons.account_circle_rounded,
                  label: 'Xem ảnh đại diện',
                  enabled: hasAvatar,
                  color: theme.primaryColor,
                  onTap: () =>
                      Navigator.pop(sheetContext, _AvatarAction.preview),
                ),
                _AvatarActionTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Đổi ảnh',
                  color: theme.primaryColor,
                  onTap: () =>
                      Navigator.pop(sheetContext, _AvatarAction.change),
                ),
                _AvatarActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Xoá ảnh',
                  enabled: hasAvatar,
                  color: AppColors.expense,
                  onTap: () =>
                      Navigator.pop(sheetContext, _AvatarAction.delete),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _AvatarAction.preview:
        _previewAvatar(settings);
        break;
      case _AvatarAction.change:
        await _changeAvatar(settings);
        break;
      case _AvatarAction.delete:
        _confirmDeleteAvatar(settings);
        break;
    }
  }

  void _confirmDeleteAvatar(AppSettings settings) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => SheepConfirmDialog(
        title: 'Xoá ảnh đại diện?',
        content: 'Ảnh đại diện hiện tại sẽ bị xoá khỏi thiết bị.',
        confirmLabel: 'Xoá ảnh',
        confirmColor: AppColors.expense,
        icon: Icons.delete_outline_rounded,
        onConfirm: () => _deleteAvatar(settings),
      ),
    );
  }

  void _previewAvatar(AppSettings settings) {
    final avatarFile = AvatarImageStore.resolve(settings.avatarImageRef);
    if (avatarFile == null || !avatarFile.existsSync()) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(avatarFile, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeAvatar(AppSettings settings) async {
    final themeColor = Theme.of(context).primaryColor;
    final oldAvatarRef = settings.avatarImageRef;
    String? newAvatarRef;

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final cropped = await cropper.ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const cropper.CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressFormat: cropper.ImageCompressFormat.jpg,
        compressQuality: 80,
        uiSettings: [
          cropper.AndroidUiSettings(
            toolbarTitle: 'Đổi ảnh đại diện',
            toolbarColor: themeColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: themeColor,
            initAspectRatio: cropper.CropAspectRatioPreset.square,
            aspectRatioPresets: const [cropper.CropAspectRatioPreset.square],
            lockAspectRatio: true,
          ),
          cropper.IOSUiSettings(
            title: 'Đổi ảnh đại diện',
            doneButtonTitle: 'Lưu',
            cancelButtonTitle: 'Huỷ',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: const [cropper.CropAspectRatioPreset.square],
          ),
        ],
      );
      if (cropped == null) return;

      newAvatarRef = await AvatarImageStore.saveFromSourcePath(cropped.path);
      settings.avatarImageRef = newAvatarRef;
      await settings.save();
      await AvatarImageStore.deleteStoredRef(oldAvatarRef);
      if (!mounted) return;
      SheepNotifications.showSuccess(context, 'Đã cập nhật ảnh đại diện');
    } catch (_) {
      await AvatarImageStore.deleteStoredRef(newAvatarRef);
      if (!mounted) return;
      SheepNotifications.showError(context, 'Không thể cập nhật ảnh đại diện');
    }
  }

  Future<void> _deleteAvatar(AppSettings settings) async {
    final oldAvatarRef = settings.avatarImageRef;
    if (oldAvatarRef == null || oldAvatarRef.isEmpty) return;

    try {
      settings.avatarImageRef = null;
      await settings.save();
      await AvatarImageStore.deleteStoredRef(oldAvatarRef);
      if (!mounted) return;
      SheepNotifications.showSuccess(context, 'Đã xoá ảnh đại diện');
    } catch (_) {
      if (!mounted) return;
      SheepNotifications.showError(context, 'Không thể xoá ảnh đại diện');
    }
  }

  int _calculateTransactionStreak() {
    final streakBox = _streakBoxOrNull();
    if (streakBox == null) {
      unawaited(_syncStreakAfterBoxOpen());
    }
    final completedDayKeys = <String>{
      ...Hive.box<Transaction>(kMoneyBox)
          .values
          .where((tx) => tx.isCompleted)
          .map((tx) => _dayKey(tx.date)),
      if (streakBox != null)
        ...streakBox.keys
            .whereType<String>()
            .where((key) => key.startsWith('completed:'))
            .where((key) => streakBox.get(key) == true)
            .map((key) => key.substring('completed:'.length)),
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    var cursor = completedDayKeys.contains(_dayKey(today)) ? today : yesterday;
    var streak = 0;

    while (completedDayKeys.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _dayKey(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return DateFormat('yyyy-MM-dd').format(day);
  }

  String _streakCompletedKey(String dayKey) => 'completed:$dayKey';

  String _streakActiveSecondsKey(String dayKey) => 'active_seconds:$dayKey';

  _DrawerOverviewStatus _buildFinancialOverview(AppSettings settings) {
    final type = _activeInsightType ?? _validInsightType(null);
    if (type == null) return _buildTodayOverview(settings);
    return _overviewForType(type, settings) ?? _buildTodayOverview(settings);
  }

  _DrawerInsightType _pickRandomInsightType({_DrawerInsightType? excluding}) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    var availableTypes = _availableInsightTypes(settings);
    if (availableTypes.isEmpty) return _DrawerInsightType.today;

    if (excluding != null && availableTypes.length > 1) {
      availableTypes = availableTypes
          .where((type) => type != excluding)
          .toList();
    }

    return availableTypes[_insightRandom.nextInt(availableTypes.length)];
  }

  _DrawerInsightType? _validInsightType(_DrawerInsightType? preferredType) {
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    if (preferredType != null &&
        _overviewForType(preferredType, settings) != null) {
      return preferredType;
    }

    final availableTypes = _availableInsightTypes(settings);
    return availableTypes.isEmpty ? null : _pickRandomInsightType();
  }

  List<_DrawerInsightType> _availableInsightTypes(AppSettings settings) {
    return _DrawerInsightType.values
        .where((type) => _overviewForType(type, settings) != null)
        .toList();
  }

  _DrawerOverviewStatus? _overviewForType(
    _DrawerInsightType type,
    AppSettings settings,
  ) {
    return switch (type) {
      _DrawerInsightType.budget => _buildBudgetOverview(settings),
      _DrawerInsightType.cycle => _buildCycleOverview(settings),
      _DrawerInsightType.savings => _buildSavingsOverview(settings),
      _DrawerInsightType.today => _buildTodayOverview(settings),
      _DrawerInsightType.streak => _buildStreakOverview(),
    };
  }

  _DrawerOverviewStatus? _buildBudgetOverview(AppSettings settings) {
    final now = DateTime.now();
    final cycleRange = FinancialCycleUtil.cycleRangeFor(
      now,
      settings.financialCycleStartDay,
    );
    final transactions = Hive.box<Transaction>(kMoneyBox).values.toList();
    _DrawerOverviewStatus? bestUnderBudget;
    double bestProgress = -1;
    _DrawerOverviewStatus? bestOverBudget;
    double bestOverage = -1;

    for (final category in Hive.box<CategoryModel>(kCatBox).values) {
      final budget = category.budget;
      if (category.effectiveTypeIndex != 0 || budget == null || budget <= 0) {
        continue;
      }

      final spent = transactions
          .where(
            (tx) =>
                tx.isCompleted &&
                tx.categoryId == category.id &&
                FinancialCycleUtil.isInRange(tx.date, cycleRange),
          )
          .fold(0.0, (sum, tx) => sum + tx.amount);
      if (spent <= 0) continue;

      final progressPercent = (spent / budget * 100).round();
      if (spent > budget) {
        final overPercent = ((spent - budget) / budget * 100).round();
        if (overPercent > bestOverage) {
          bestOverage = overPercent.toDouble();
          bestOverBudget = _DrawerOverviewStatus(
            icon: category.iconData,
            imagePath: category.imagePath,
            title: category.name,
            message: 'vượt ngân sách $overPercent%',
            color: AppColors.expense,
            backgroundColor: const Color(0x1FEE6055),
          );
        }
      } else if (progressPercent > bestProgress) {
        bestProgress = progressPercent.toDouble();
        bestUnderBudget = _DrawerOverviewStatus(
          icon: category.iconData,
          imagePath: category.imagePath,
          title: category.name,
          message: 'đã tiêu $progressPercent% ngân sách',
        );
      }
    }

    return bestOverBudget ?? bestUnderBudget;
  }

  _DrawerOverviewStatus? _buildCycleOverview(AppSettings settings) {
    final now = DateTime.now();
    final currentRange = FinancialCycleUtil.cycleRangeFor(
      now,
      settings.financialCycleStartDay,
    );
    final previousRange = FinancialCycleUtil.previousCycleRange(
      now,
      settings.financialCycleStartDay,
    );
    final transactions = Hive.box<Transaction>(kMoneyBox).values.toList();
    final categoriesById = {
      for (final cat in Hive.box<CategoryModel>(kCatBox).values) cat.id: cat,
    };

    double sumForRange(DateTime start, DateTime end, int typeIndex) {
      return transactions
          .where((tx) {
            if (!tx.isCompleted) return false;
            final category = categoriesById[tx.categoryId];
            final effectiveTypeIndex =
                category?.effectiveTypeIndex ?? (tx.isExpense ? 0 : 1);
            return effectiveTypeIndex == typeIndex &&
                !tx.date.isBefore(start) &&
                !tx.date.isAfter(end);
          })
          .fold(0.0, (sum, tx) => sum + tx.amount);
    }

    final currentExpense = sumForRange(currentRange.start, currentRange.end, 0);
    final previousExpense = sumForRange(
      previousRange.start,
      previousRange.end,
      0,
    );
    if (previousExpense > 0 && currentExpense != previousExpense) {
      final percent =
          ((currentExpense - previousExpense).abs() / previousExpense * 100)
              .round();
      final isLower = currentExpense < previousExpense;
      return _DrawerOverviewStatus(
        icon: Icons.pie_chart_rounded,
        title: 'Chi tiêu',
        message: '${isLower ? 'ít' : 'nhiều'} hơn $percent% so với kỳ trước',
        color: isLower ? AppColors.income : AppColors.expense,
        backgroundColor: isLower
            ? const Color(0x1F20C997)
            : const Color(0x1FEE6055),
      );
    }

    final currentIncome = sumForRange(currentRange.start, currentRange.end, 1);
    final previousIncome = sumForRange(
      previousRange.start,
      previousRange.end,
      1,
    );
    if (previousIncome > 0 && currentIncome > previousIncome) {
      final percent = ((currentIncome - previousIncome) / previousIncome * 100)
          .round();
      return _DrawerOverviewStatus(
        icon: Icons.pie_chart_rounded,
        title: 'Thu nhập',
        message: 'tăng $percent% so với kỳ trước',
        color: AppColors.income,
        backgroundColor: const Color(0x1F20C997),
      );
    }

    return null;
  }

  _DrawerOverviewStatus? _buildSavingsOverview(AppSettings settings) {
    final transactions = Hive.box<Transaction>(kMoneyBox).values.toList();
    _DrawerOverviewStatus? bestStatus;
    double bestProgress = -1;

    for (final category in Hive.box<CategoryModel>(kCatBox).values) {
      final target = category.targetAmount;
      if (category.effectiveTypeIndex != 2 || target == null || target <= 0) {
        continue;
      }

      final initial = category.initialAmount ?? 0.0;
      final saved = transactions
          .where((tx) => tx.isCompleted && tx.categoryId == category.id)
          .fold(0.0, (sum, tx) => sum + tx.amount) + initial;
      final progress = saved / target;
      if (progress <= bestProgress) continue;

      bestProgress = progress;
      if (saved >= target) {
        bestStatus = _DrawerOverviewStatus(
          icon: category.iconData,
          imagePath: category.imagePath,
          title: 'Mục tiêu ${category.name}',
          message: 'đã hoàn thành 🎉',
          color: AppColors.income,
          backgroundColor: const Color(0x1F20C997),
        );
      } else if (progress >= 0.5) {
        bestStatus = _DrawerOverviewStatus(
          icon: category.iconData,
          imagePath: category.imagePath,
          title: 'Mục tiêu ${category.name}',
          message: 'đã đạt ${(progress * 100).round()}%',
        );
      } else {
        final remaining = _formatCompactAmount(target - saved, settings);
        bestStatus = _DrawerOverviewStatus(
          icon: category.iconData,
          imagePath: category.imagePath,
          title: 'Mục tiêu ${category.name}',
          message: 'còn $remaining nữa là hoàn thành',
        );
      }
    }

    return bestStatus;
  }

  _DrawerOverviewStatus _buildTodayOverview(AppSettings settings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayTransactions = Hive.box<Transaction>(kMoneyBox).values.where(
      (tx) => tx.isCompleted && !tx.date.isBefore(today) && tx.date.isBefore(tomorrow),
    );
    final todayExpense = todayTransactions
        .where((tx) => tx.isExpense)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final count = todayTransactions.length;

    if (count == 0) {
      return const _DrawerOverviewStatus(
        icon: Icons.receipt_long_rounded,
        title: 'Hôm nay',
        message: 'chưa có giao dịch nào',
        color: AppColors.income,
        backgroundColor: Color(0x1F20C997),
      );
    }

    return _DrawerOverviewStatus(
      icon: Icons.receipt_long_rounded,
      title: 'Hôm nay',
      message:
          'đã chi ${_formatCompactAmount(todayExpense, settings)} với $count giao dịch',
    );
  }

  _DrawerOverviewStatus? _buildStreakOverview() {
    final streak = _calculateTransactionStreak();
    if (streak <= 0) return null;

    return _DrawerOverviewStatus(
      icon: Icons.local_fire_department_rounded,
      title: 'Streak',
      message: '$streak ngày liên tiếp',
      color: AppColors.savings,
      backgroundColor: const Color(0x1F4EA8DE),
    );
  }

  String _formatCompactAmount(double amount, AppSettings settings) {
    return CurrencyUtil.formatCompact(amount);
  }

  String _formatCurrentCycleLabel(BuildContext context, AppSettings settings) {
    final range = FinancialCycleUtil.cycleRangeFor(
      DateTime.now(),
      settings.financialCycleStartDay,
    );
    final locale = Localizations.localeOf(context).toString();
    final start = DateFormat('dd/MM', locale).format(range.start);
    final end = DateFormat('dd/MM', locale).format(range.end);
    return '${L10n.of(context).get('current_cycle')}: $start - $end';
  }

  String _getGreeting(L10n l10n) {
    final hour = DateTime.now().hour;
    final isVietnamese = l10n.locale.languageCode == 'vi';

    if (hour < 12) {
      return isVietnamese ? 'Chào buổi sáng 👋' : 'Good morning 👋';
    }
    if (hour < 18) {
      return isVietnamese ? 'Chào buổi chiều 👋' : 'Good afternoon 👋';
    }
    return isVietnamese ? 'Chào buổi tối 👋' : 'Good evening 👋';
  }
}

class _DrawerOverviewStatus {
  final IconData icon;
  final String? imagePath;
  final String title;
  final String message;
  final Color color;
  final Color backgroundColor;

  const _DrawerOverviewStatus({
    required this.icon,
    this.imagePath,
    required this.title,
    required this.message,
    this.color = AppColors.savings,
    this.backgroundColor = const Color(0x1F4EA8DE),
  });
}

/// Sits on the coloured drawer header, so it follows the header's
/// foreground (like the cycle pill) and keeps the status colour only on the
/// icon. Status colours on a palette background were unreadable.
class _DrawerOverviewCard extends StatelessWidget {
  final _DrawerOverviewStatus status;
  final Color foreground;

  const _DrawerOverviewCard({required this.status, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(SheepRadius.md),
        border: Border.all(color: foreground.withValues(alpha: 0.19)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SheepCategoryIcon(
              icon: status.icon,
              color: status.color,
              size: 20,
              imagePath: status.imagePath,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            // Text.rich (not RichText) so the app font is inherited.
            child: Text.rich(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              TextSpan(
                style: TextStyle(
                  color: foreground,
                  fontSize: SheepTypeScale.micro,
                  fontWeight: FontWeight.w600,
                  height: 1.22,
                  letterSpacing: 0,
                ),
                children: [
                  TextSpan(
                    text: status.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' ${status.message}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _AvatarActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final foreground = enabled ? color : AppColors.getTextMuted(brightness);
    return ListTile(
      enabled: enabled,
      minVerticalPadding: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: foreground, size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: enabled
              ? AppColors.getTextPrimary(brightness)
              : AppColors.getTextMuted(brightness),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

class _DrawerAvatar extends StatelessWidget {
  final String username;
  final int streakCount;
  final File? avatarFile;
  final VoidCallback onTap;

  const _DrawerAvatar({
    required this.username,
    required this.streakCount,
    required this.avatarFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = username.trim().isEmpty
        ? 'S'
        : username.trim().characters.first.toUpperCase();
    final hasStreak = streakCount >= 1;
    final streakLabel = streakCount > 999 ? '999+' : '$streakCount';
    final hasAvatar = avatarFile != null && avatarFile!.existsSync();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0x38FFFFFF),
              shape: BoxShape.circle,
            ),
            child: hasAvatar
                ? Image.file(
                    avatarFile!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
          ),
          if (hasStreak)
            Positioned(
              top: -7,
              right: -5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x52000000),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x66FFFFFF), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFFA726),
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        streakLabel,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          color: Color(0xFFFFA726),
                          fontSize: SheepTypeScale.micro,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawerCyclePill extends StatelessWidget {
  final String label;
  final Color foreground;

  const _DrawerCyclePill({required this.label, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(SheepRadius.pill),
        border: Border.all(color: foreground.withValues(alpha: 0.19)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range_rounded, color: foreground, size: 14),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: SheepTypeScale.micro,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerPrivacyButton extends StatelessWidget {
  final bool isHidden;
  final VoidCallback onPressed;
  final Color foreground;

  const _DrawerPrivacyButton({
    required this.isHidden,
    required this.onPressed,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      onPressed: onPressed,
      icon: Icon(
        isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: foreground,
        size: 22,
      ),
    );
  }
}
