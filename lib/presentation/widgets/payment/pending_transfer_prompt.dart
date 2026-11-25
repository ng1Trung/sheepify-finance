import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/pending_transfer.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/pending_transfer_service.dart';
import '../common/sheep_kit.dart';
import '../common/sheep_notifications.dart';
import '../common/sheep_widgets.dart';

/// "Did the transfer go through?" — shown when the user comes back from the
/// bank app, so a pending transfer is settled right away instead of sitting
/// in the list until someone notices it.
class PendingTransferPrompt {
  /// Ids already asked about in this app session ("later" means later).
  static final Set<String> _asked = {};
  static bool _isShowing = false;

  /// Asks about the newest pending transfer created recently, once.
  static Future<void> maybeShow(BuildContext context) async {
    if (_isShowing) return;
    final candidates = PendingTransferService.recentPending()
        .where((p) => !_asked.contains(p.id))
        .toList();
    if (candidates.isEmpty) return;
    final pending = candidates.first;
    _asked.add(pending.id);
    _isShowing = true;
    try {
      await show(context, pending);
    } finally {
      _isShowing = false;
    }
  }

  /// Opened from the reminder notification: ask about that transfer even if
  /// it was already asked about (the user chose to come back for it).
  static Future<void> showById(BuildContext context, String pendingId) async {
    if (_isShowing) return;
    final pending = PendingTransferService.getPendingTransfer(pendingId);
    if (pending == null) return;
    _asked.add(pending.id);
    _isShowing = true;
    try {
      await show(context, pending);
    } finally {
      _isShowing = false;
    }
  }

  static Future<void> show(BuildContext context, PendingTransfer pending) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PromptBody(pending: pending, hostContext: context),
    );
  }
}

class _PromptBody extends StatelessWidget {
  final PendingTransfer pending;

  /// The screen underneath; toasts go there once the sheet is closed.
  final BuildContext hostContext;

  const _PromptBody({required this.pending, required this.hostContext});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final category = Hive.box<CategoryModel>(kCatBox).values
        .where((c) => c.id == pending.categoryId)
        .firstOrNull;
    final amountText =
        '${CurrencyUtil.formatMoney(pending.amount, locale: 'vi_VN')} ₫';

    Future<void> confirm() async {
      final navigator = Navigator.of(context);
      final updated = await PendingTransferService.confirmTransfer(pending.id);
      navigator.pop();
      if (updated == null || !hostContext.mounted) return;
      NotificationService.showTransactionActionNotification(
        action: TransactionActionType.confirmed,
        note: updated.note,
        amount: updated.amount,
        categoryName: category?.name,
      );
      SheepNotifications.showSuccess(hostContext, 'Đã ghi sổ $amountText');
    }

    Future<void> cancel() async {
      final navigator = Navigator.of(context);
      await PendingTransferService.cancelTransfer(pending.id);
      navigator.pop();
      if (!hostContext.mounted) return;
      SheepNotifications.showInfo(hostContext, 'Đã huỷ giao dịch chờ');
    }

    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: SheepTextStyles.itemMeta(context)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: SheepTextStyles.itemTitle(context),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SheepSpacing.page,
        SheepSpacing.md,
        SheepSpacing.page,
        SheepSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SheepDragHandle()),
          const SizedBox(height: SheepSpacing.lg),
          Text(
            'Bạn đã chuyển xong chưa?',
            textAlign: TextAlign.center,
            style: SheepTextStyles.sheetTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            'Sheepify chỉ ghi vào sổ chi khi bạn xác nhận.',
            textAlign: TextAlign.center,
            style: SheepTextStyles.itemMeta(context),
          ),
          const SizedBox(height: SheepSpacing.lg),
          Center(
            child: Text(
              amountText,
              style: SheepTextStyles.amount(
                context,
                size: SheepTypeScale.amountLarge,
              ),
            ),
          ),
          const SizedBox(height: SheepSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SheepSpacing.md,
              vertical: SheepSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.getSubtleSurface(brightness),
              borderRadius: BorderRadius.circular(SheepRadius.md),
            ),
            child: Column(
              children: [
                detail(
                  'Người nhận',
                  '${pending.accountNo} · ${pending.recipientBankName ?? ''}',
                ),
                if (pending.note.isNotEmpty) detail('Nội dung', pending.note),
                if (category != null) detail('Danh mục', category.name),
              ],
            ),
          ),
          const SizedBox(height: SheepSpacing.xl),
          SheepButton(
            label: 'Đã chuyển thành công',
            isFullWidth: true,
            large: true,
            onPressed: confirm,
          ),
          const SizedBox(height: SheepSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SheepButton(
                  label: 'Chưa chuyển, huỷ',
                  variant: SheepButtonVariant.secondary,
                  isFullWidth: true,
                  onPressed: cancel,
                ),
              ),
              const SizedBox(width: SheepSpacing.sm),
              Expanded(
                child: SheepButton(
                  label: 'Để sau',
                  variant: SheepButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
