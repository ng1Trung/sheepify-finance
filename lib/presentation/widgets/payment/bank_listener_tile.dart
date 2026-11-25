import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/bank_inbox_service.dart';
import '../common/sheep_dialogs.dart';
import '../common/sheep_toggles.dart';
import '../common/sheep_widgets.dart';

/// Settings row for "log from bank notifications". The permission lives in
/// Android settings, so the switch reflects that and re-checks on return.
class BankListenerTile extends StatefulWidget {
  final TextStyle? titleStyle;

  const BankListenerTile({super.key, this.titleStyle});

  @override
  State<BankListenerTile> createState() => _BankListenerTileState();
}

class _BankListenerTileState extends State<BankListenerTile>
    with WidgetsBindingObserver {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await BankInboxService.isListenerEnabled();
    if (mounted && enabled != _enabled) setState(() => _enabled = enabled);
  }

  void _onTap() {
    if (_enabled) {
      // Turning it off happens in the same system screen.
      BankInboxService.openListenerSettings();
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (_) => SheepConfirmDialog(
        title: 'Tự ghi từ thông báo ngân hàng',
        content:
            'Khi app ngân hàng báo biến động số dư, Sheepify gợi ý ghi sổ ngay, '
            'bạn chỉ cần chọn danh mục. Chuyển tiền từ Sheepify sẽ được tự xác nhận.\n\n'
            'Android sẽ hỏi quyền truy cập thông báo. Sheepify chỉ đọc thông báo '
            'có số tiền biến động, mọi thứ ở lại trên máy bạn.',
        confirmLabel: 'Mở cài đặt',
        cancelLabel: 'Để sau',
        icon: Icons.notifications_active_outlined,
        confirmColor: AppColors.income,
        onConfirm: BankInboxService.openListenerSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!BankInboxService.isSupported) return const SizedBox.shrink();
    return ListTile(
      onTap: _onTap,
      title: Text('Tự ghi từ thông báo ngân hàng', style: widget.titleStyle),
      subtitle: Text(
        _enabled
            ? 'Đang bật · gợi ý ghi sổ khi ngân hàng báo biến động'
            : 'Không cần nhập tay khi trả tiền trong app ngân hàng',
        style: SheepTextStyles.itemMeta(context),
      ),
      trailing: IgnorePointer(
        child: SheepSwitch(value: _enabled, onChanged: (_) {}),
      ),
    );
  }
}
