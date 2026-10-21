import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/services/bank_deeplink_service.dart';
import '../../../data/services/wallet_service.dart';
import '../../screens/wallet/wallet_management_screen.dart';
import '../common/sheep_widgets.dart';

/// Modal bottom sheet để người dùng tìm kiếm và chọn ứng dụng ngân hàng / ví điện tử từ toàn bộ danh sách hỗ trợ
/// (Thường dùng khi tạo/sửa thông tin ví trong Quản lý ví)
class BankAppPickerModal extends StatefulWidget {
  final BankAppModel? selectedBank;
  final ValueChanged<BankAppModel?> onBankSelected;
  final String title;
  final bool allowManualOption;

  const BankAppPickerModal({
    super.key,
    required this.selectedBank,
    required this.onBankSelected,
    this.title = 'Chọn App Ngân Hàng / Ví',
    this.allowManualOption = false,
  });

  /// Helper mở bottom sheet tiện lợi
  static Future<BankAppModel?> show({
    required BuildContext context,
    required BankAppModel? selectedBank,
    ValueChanged<BankAppModel?>? onBankSelected,
    String title = 'Chọn App Ngân Hàng / Ví',
    bool allowManualOption = false,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<BankAppModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BankAppPickerModal(
        selectedBank: selectedBank,
        allowManualOption: allowManualOption,
        onBankSelected: (bank) {
          onBankSelected?.call(bank);
          Navigator.pop(ctx, bank);
        },
        title: title,
      ),
    );
  }

  @override
  State<BankAppPickerModal> createState() => _BankAppPickerModalState();
}

class _BankAppPickerModalState extends State<BankAppPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final filteredBanks = BankDeeplinkService.supportedBanks.where((b) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return b.shortName.toLowerCase().contains(q) ||
          b.fullName.toLowerCase().contains(q) ||
          b.bin.toLowerCase().contains(q);
    }).toList();

    final showManualTile = widget.allowManualOption &&
        (_searchQuery.trim().isEmpty ||
            'tiền mặt'.contains(_searchQuery.toLowerCase()) ||
            'thủ công'.contains(_searchQuery.toLowerCase()) ||
            'cash'.contains(_searchQuery.toLowerCase()));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        top: SheepSpacing.sm,
        left: SheepSpacing.page,
        right: SheepSpacing.page,
        bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: SheepSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.getTextSecondary(brightness)
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Tiêu đề
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: SheepTextStyles.itemTitle(context).copyWith(
                      fontSize: SheepTypeScale.title,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${BankDeeplinkService.supportedBanks.length} ứng dụng',
                  style: SheepTextStyles.itemMeta(context).copyWith(
                    fontSize: SheepTypeScale.micro,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Ô tìm kiếm ngân hàng
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Tìm ngân hàng (Techcombank, VCB, MB, MoMo...)',
              hintStyle: SheepTextStyles.itemMeta(context),
              filled: true,
              fillColor: AppColors.getSubtleSurface(brightness),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SheepRadius.md),
                borderSide: BorderSide.none,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
            },
          ),
          const SizedBox(height: SheepSpacing.md),

          // Danh sách ngân hàng
          Expanded(
            child: (!showManualTile && filteredBanks.isEmpty)
                ? Center(
                    child: Text(
                      'Không tìm thấy ngân hàng phù hợp',
                      style: SheepTextStyles.itemMeta(context),
                    ),
                  )
                : ListView(
                    children: [
                      // Tuỳ chọn Tiền mặt / Thủ công (nếu allowManualOption = true)
                      if (showManualTile) ...[
                        ListTile(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onBankSelected(null);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(SheepRadius.md),
                            side: BorderSide(
                              color: widget.selectedBank == null
                                  ? theme.colorScheme.primary
                                  : AppColors.getBorder(brightness),
                              width: widget.selectedBank == null ? 1.5 : 1.0,
                            ),
                          ),
                          tileColor: widget.selectedBank == null
                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                              : AppColors.getSubtleSurface(brightness),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(SheepRadius.sm),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.payments_outlined,
                              size: 22,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            'Tiền mặt / Ví thủ công',
                            style:
                                SheepTextStyles.itemTitle(context).copyWith(
                              fontWeight: widget.selectedBank == null
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Không liên kết ứng dụng chuyển tiền',
                            style: SheepTextStyles.itemMeta(context).copyWith(
                              fontSize: 11.5,
                            ),
                          ),
                          trailing: widget.selectedBank == null
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Danh sách các ngân hàng được hỗ trợ
                      ...filteredBanks.map((bank) {
                        final isSelected = widget.selectedBank?.id == bank.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onBankSelected(bank);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SheepRadius.md),
                              side: BorderSide(
                                color: isSelected
                                    ? bank.brandColor
                                    : AppColors.getBorder(brightness),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            tileColor: isSelected
                                ? bank.brandColor.withValues(alpha: 0.08)
                                : AppColors.getSubtleSurface(brightness),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: bank.brandColor.withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(SheepRadius.sm),
                                border: Border.all(
                                  color: bank.brandColor
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                bank.shortName
                                    .substring(
                                      0,
                                      bank.shortName.length.clamp(1, 3),
                                    )
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: bank.brandColor,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  bank.shortName,
                                  style: SheepTextStyles.itemTitle(context)
                                      .copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bank.canAutofillPayment
                                        ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.15)
                                        : const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(SheepRadius.sm),
                                  ),
                                  child: Text(
                                    bank.canAutofillPayment
                                        ? 'Tự động'
                                        : 'Xác nhận',
                                    style: TextStyle(
                                      fontFamily: 'Quicksand',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: bank.canAutofillPayment
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              bank.fullName,
                              style:
                                  SheepTextStyles.itemMeta(context).copyWith(
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: bank.brandColor,
                                  )
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Widget hiển thị thẻ chọn ứng dụng ngân hàng dạng dropdown / card
/// (Dùng khi chọn app liên kết lúc tạo/sửa ví trong Quản lý ví)
class BankAppSelectorTile extends StatelessWidget {
  final BankAppModel? bank;
  final VoidCallback onTap;
  final String label;

  const BankAppSelectorTile({
    super.key,
    required this.bank,
    required this.onTap,
    this.label = 'NGÂN HÀNG HOẶC VÍ LIÊN KẾT',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SheepTextStyles.itemMeta(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: SheepTypeScale.micro,
          ),
        ),
        const SizedBox(height: SheepSpacing.xs),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(SheepRadius.md),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.getSubtleSurface(brightness),
                borderRadius: BorderRadius.circular(SheepRadius.md),
                border: Border.all(
                  color: AppColors.getBorder(brightness),
                ),
              ),
              child: Row(
                children: [
                  if (bank != null) ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bank!.brandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SheepRadius.sm),
                        border: Border.all(
                          color: bank!.brandColor.withValues(alpha: 0.25),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bank!.shortName
                            .substring(0, bank!.shortName.length.clamp(1, 3))
                            .toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: bank!.brandColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                bank!.shortName,
                                style:
                                    SheepTextStyles.itemTitle(context).copyWith(
                                  fontSize: SheepTypeScale.item,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: bank!.canAutofillPayment
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(SheepRadius.sm),
                                ),
                                child: Text(
                                  bank!.canAutofillPayment
                                      ? 'Tự động'
                                      : 'Xác nhận',
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: bank!.canAutofillPayment
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bank!.fullName,
                            style: SheepTextStyles.itemMeta(context).copyWith(
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SheepRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.payments_outlined,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tiền mặt / Ví thủ công',
                            style:
                                SheepTextStyles.itemTitle(context).copyWith(
                              fontSize: SheepTypeScale.item,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Không liên kết ứng dụng chuyển tiền',
                            style: SheepTextStyles.itemMeta(context).copyWith(
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.getTextSecondary(brightness),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal bottom sheet để người dùng chọn VÍ NGÂN HÀNG ĐÃ CÀI ĐẶT TRONG APP
/// Chỉ hiển thị các ví ngân hàng đã liên kết (loại bỏ hoàn toàn ví tiền mặt vì giao dịch tự động)
class InstalledWalletPickerModal extends StatefulWidget {
  final String? selectedWalletId;
  final void Function(WalletModel wallet, BankAppModel bank) onWalletSelected;
  final String title;

  const InstalledWalletPickerModal({
    super.key,
    required this.selectedWalletId,
    required this.onWalletSelected,
    this.title = 'Chọn ví thanh toán',
  });

  static Future<void> show({
    required BuildContext context,
    required String? selectedWalletId,
    required void Function(WalletModel wallet, BankAppModel bank) onWalletSelected,
    String title = 'Chọn ví thanh toán',
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InstalledWalletPickerModal(
        selectedWalletId: selectedWalletId,
        onWalletSelected: (wallet, bank) {
          onWalletSelected(wallet, bank);
          Navigator.pop(ctx);
        },
        title: title,
      ),
    );
  }

  @override
  State<InstalledWalletPickerModal> createState() =>
      _InstalledWalletPickerModalState();
}

class _InstalledWalletPickerModalState
    extends State<InstalledWalletPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accentColor = theme.colorScheme.primary;

    // Chỉ lấy các ví ngân hàng đã cài đặt trong app (loại bỏ ví tiền mặt / bankId == null)
    final allWallets = WalletService.getWallets();
    final bankWallets = allWallets
        .where((w) => w.bankId != null && w.bankId!.trim().isNotEmpty)
        .toList();

    // Chỉ hiển thị search bar khi danh sách ví vượt quá 1 viewport (cần phải cuộn > 4 ví)
    final needsScroll = bankWallets.length > 4;

    final filteredWallets = bankWallets.where((w) {
      final bank = BankDeeplinkService.findById(w.bankId);
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = w.name.toLowerCase().contains(q);
      final bankShortMatch = bank?.shortName.toLowerCase().contains(q) ?? false;
      final bankFullMatch = bank?.fullName.toLowerCase().contains(q) ?? false;
      return nameMatch || bankShortMatch || bankFullMatch;
    }).toList();

    return Container(
      height: needsScroll ? MediaQuery.of(context).size.height * 0.72 : null,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        top: SheepSpacing.sm,
        left: SheepSpacing.page,
        right: SheepSpacing.page,
        bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.lg,
      ),
      child: Column(
        mainAxisSize: needsScroll ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: SheepSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.getTextSecondary(brightness)
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: SheepTextStyles.itemTitle(context).copyWith(
                      fontSize: SheepTypeScale.title,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${bankWallets.length} ví',
                  style: SheepTextStyles.itemMeta(context).copyWith(
                    fontSize: SheepTypeScale.micro,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          if (bankWallets.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getSubtleSurface(brightness),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 44,
                      color: AppColors.getTextSecondary(brightness),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có ví ngân hàng nào trong app',
                    style: SheepTextStyles.itemTitle(context).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tính năng Chuyển tiền & ghi sổ tự động chỉ áp dụng cho ví ngân hàng đã liên kết (không hỗ trợ ví tiền mặt). Vui lòng thêm ví ngân hàng để sử dụng!',
                    style: SheepTextStyles.itemMeta(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SheepButton(
                    label: 'Thêm ví ngân hàng mới',
                    backgroundColor: accentColor,
                    onPressed: () {
                      Navigator.pop(context);
                      WalletManagementScreen.showAddOrEditWalletDialog(
                        context,
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            // Ô tìm kiếm ví (Chỉ hiển thị khi danh sách ví vượt quá 1 viewport cần cuộn)
            if (needsScroll) ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Tìm ví đã cài đặt...',
                  hintStyle: SheepTextStyles.itemMeta(context),
                  filled: true,
                  fillColor: AppColors.getSubtleSurface(brightness),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
              const SizedBox(height: SheepSpacing.md),
            ],

            // Danh sách ví đã cài đặt
            if (needsScroll)
              Expanded(
                child: _buildWalletList(
                  filteredWallets,
                  needsScroll: true,
                ),
              )
            else
              _buildWalletList(
                filteredWallets,
                needsScroll: false,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletList(
    List<WalletModel> wallets, {
    required bool needsScroll,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    if (wallets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Không tìm thấy ví phù hợp',
            style: SheepTextStyles.itemMeta(context),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: !needsScroll,
      physics: needsScroll
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: wallets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final wallet = wallets[index];
        final bank = BankDeeplinkService.findById(wallet.bankId) ??
            BankDeeplinkService.supportedBanks.first;
        final isSelected = widget.selectedWalletId == wallet.id;

        return ListTile(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onWalletSelected(wallet, bank);
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SheepRadius.md),
            side: BorderSide(
              color: isSelected
                  ? bank.brandColor
                  : AppColors.getBorder(brightness),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          tileColor: isSelected
              ? bank.brandColor.withValues(alpha: 0.08)
              : AppColors.getSubtleSurface(brightness),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bank.brandColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(SheepRadius.sm),
              border: Border.all(
                color: bank.brandColor.withValues(alpha: 0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              bank.shortName
                  .substring(
                    0,
                    bank.shortName.length.clamp(1, 3),
                  )
                  .toUpperCase(),
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: bank.brandColor,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  wallet.name,
                  style: SheepTextStyles.itemTitle(context).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (wallet.isDefault) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Mặc định',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: bank.canAutofillPayment
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(SheepRadius.sm),
                ),
                child: Text(
                  bank.canAutofillPayment ? 'Tự động' : 'Xác nhận',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: bank.canAutofillPayment
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Text(
                  bank.shortName,
                  style: SheepTextStyles.itemMeta(context).copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '•  Số dư: ${CurrencyUtil.formatMoney(wallet.initialBalance, locale: 'vi_VN')}₫',
                    style: SheepTextStyles.itemMeta(context).copyWith(
                      fontSize: 11.5,
                      color: AppColors.getTextPrimary(brightness),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle_rounded,
                  color: bank.brandColor,
                )
              : null,
        );
      },
    );
  }
}

/// Widget hiển thị thẻ chọn VÍ NGÂN HÀNG ĐÃ CÀI ĐẶT
/// (Dùng trong QuickTransferScreen và PaymentConfirmationBottomSheet)
class InstalledWalletSelectorTile extends StatelessWidget {
  final WalletModel? wallet;
  final BankAppModel? bank;
  final VoidCallback onTap;
  final String label;

  const InstalledWalletSelectorTile({
    super.key,
    required this.wallet,
    required this.bank,
    required this.onTap,
    this.label = 'CHỌN VÍ THANH TOÁN',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SheepTextStyles.itemMeta(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: SheepTypeScale.micro,
          ),
        ),
        const SizedBox(height: SheepSpacing.xs),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(SheepRadius.md),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.getSubtleSurface(brightness),
                borderRadius: BorderRadius.circular(SheepRadius.md),
                border: Border.all(
                  color: AppColors.getBorder(brightness),
                ),
              ),
              child: Row(
                children: [
                  if (wallet != null && bank != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bank!.brandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SheepRadius.sm),
                        border: Border.all(
                          color: bank!.brandColor.withValues(alpha: 0.25),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bank!.shortName
                            .substring(0, bank!.shortName.length.clamp(1, 3))
                            .toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: bank!.brandColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  wallet!.name,
                                  style:
                                      SheepTextStyles.itemTitle(context).copyWith(
                                    fontSize: SheepTypeScale.item,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: bank!.canAutofillPayment
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(SheepRadius.sm),
                                ),
                                child: Text(
                                  bank!.canAutofillPayment
                                      ? 'Tự động'
                                      : 'Xác nhận',
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: bank!.canAutofillPayment
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bank!.shortName} • Số dư: ${CurrencyUtil.formatMoney(wallet!.initialBalance, locale: 'vi_VN')}₫',
                            style: SheepTextStyles.itemMeta(context).copyWith(
                              fontSize: 11.5,
                              color: AppColors.getTextSecondary(brightness),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SheepRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add_card_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Chưa chọn ví ngân hàng',
                            style:
                                SheepTextStyles.itemTitle(context).copyWith(
                              fontSize: SheepTypeScale.item,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bấm để chọn ví ngân hàng thanh toán',
                            style: SheepTextStyles.itemMeta(context).copyWith(
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.getTextSecondary(brightness),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
