import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../../core/constants/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_util.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/services/bank_deeplink_service.dart';
import '../../../data/services/wallet_service.dart';
import '../../widgets/common/sheep_notifications.dart';
import '../../widgets/common/sheep_widgets.dart';
import '../../widgets/payment/bank_app_picker_modal.dart';

class WalletManagementScreen extends StatefulWidget {
  final bool isTab;
  const WalletManagementScreen({super.key, this.isTab = false});

  @override
  State<WalletManagementScreen> createState() => _WalletManagementScreenState();

  static Future<WalletModel?> showAddOrEditWalletDialog(
    BuildContext context, {
    WalletModel? walletToEdit,
  }) {
    final isEditing = walletToEdit != null;
    final nameController =
        TextEditingController(text: walletToEdit?.name ?? '');
    final balanceController = TextEditingController(
      text: walletToEdit != null && walletToEdit.initialBalance > 0
          ? NumberFormat('#,###', 'vi_VN')
              .format(walletToEdit.initialBalance.toInt())
          : '',
    );

    BankAppModel? selectedBank = walletToEdit?.bankId != null
        ? BankDeeplinkService.findById(walletToEdit!.bankId)
        : null;
    bool isDefault = walletToEdit?.isDefault ?? false;

    return showModalBottomSheet<WalletModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final brightness = theme.brightness;
        final settings =
            Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
        final accentColor =
            AppColors.getPalette(settings.themePresetName).primary;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.getSurface(brightness),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SheepRadius.sheet),
                ),
              ),
              padding: EdgeInsets.only(
                top: SheepSpacing.md,
                left: SheepSpacing.page,
                right: SheepSpacing.page,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + SheepSpacing.xl,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.getTextSecondary(brightness)
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: SheepSpacing.md),
                    Text(
                      isEditing ? 'Chỉnh Sửa Ví' : 'Thêm Ví / Tài Khoản Mới',
                      style: SheepTextStyles.itemTitle(context).copyWith(
                        fontSize: SheepTypeScale.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SheepSpacing.lg),

                    // Tên ví
                    TextField(
                      controller: nameController,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: SheepTypeScale.item,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(brightness),
                      ),
                      decoration: InputDecoration(
                        labelText: 'TÊN VÍ',
                        labelStyle: SheepTextStyles.itemMeta(context).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        hintText: 'VD: Techcombank, Tiền mặt, Ví MoMo...',
                        filled: true,
                        fillColor: AppColors.getSubtleSurface(brightness),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: SheepSpacing.md),

                    // Ngân hàng liên kết
                    BankAppSelectorTile(
                      bank: selectedBank,
                      label: 'NGÂN HÀNG HOẶC VÍ LIÊN KẾT',
                      onTap: () {
                        BankAppPickerModal.show(
                          context: context,
                          selectedBank: selectedBank,
                          allowManualOption: true,
                          title: 'Chọn Ngân Hàng / Ví Liên Kết',
                          onBankSelected: (bank) {
                            setModalState(() {
                              selectedBank = bank;
                              if (!isEditing &&
                                  nameController.text.isEmpty &&
                                  selectedBank != null) {
                                nameController.text = selectedBank!.shortName;
                              } else if (!isEditing &&
                                  nameController.text.isEmpty &&
                                  selectedBank == null) {
                                nameController.text = 'Tiền mặt';
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: SheepSpacing.md),

                    // Số dư ban đầu
                    TextField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: SheepTypeScale.bodyLarge,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(brightness),
                      ),
                      decoration: InputDecoration(
                        labelText: 'SỐ DƯ HIỆN TẠI / BAN ĐẦU',
                        labelStyle: SheepTextStyles.itemMeta(context).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        hintText: '0',
                        suffixText: '₫',
                        suffixStyle: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                        ),
                        filled: true,
                        fillColor: AppColors.getSubtleSurface(brightness),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SheepRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(locale: 'vi_VN'),
                      ],
                    ),
                    const SizedBox(height: SheepSpacing.md),

                    // Checkbox Ví mặc định
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isDefault,
                      activeColor: accentColor,
                      title: Text(
                        'Đặt làm ví thanh toán mặc định ⭐',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: SheepTypeScale.label,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(brightness),
                        ),
                      ),
                      subtitle: Text(
                        'Ưu tiên chọn ví này khi quét QR thanh toán',
                        style: SheepTextStyles.itemMeta(context),
                      ),
                      onChanged: (val) {
                        setModalState(() => isDefault = val ?? false);
                      },
                    ),
                    const SizedBox(height: SheepSpacing.lg),

                    // Nút Lưu
                    SheepButton(
                      label: isEditing ? 'Cập nhật ví' : 'Lưu ví mới',
                      isFullWidth: true,
                      backgroundColor: accentColor,
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          SheepNotifications.showError(
                            context,
                            'Vui lòng nhập tên ví!',
                          );
                          return;
                        }

                        final cleanAmount = balanceController.text
                            .replaceAll(RegExp(r'[^0-9]'), '');
                        final balance = double.tryParse(cleanAmount) ?? 0;

                        final newWallet = WalletModel(
                          id: walletToEdit?.id ??
                              'wallet_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          bankId: selectedBank?.id,
                          bankBin: selectedBank?.bin,
                          initialBalance: balance,
                          isDefault: isDefault,
                          colorValue: selectedBank?.brandColor.toARGB32() ??
                              accentColor.toARGB32(),
                          createdAt: walletToEdit?.createdAt ?? DateTime.now(),
                        );

                        await WalletService.saveWallet(newWallet);
                        if (isDefault) {
                          await WalletService.setDefaultWallet(newWallet.id);
                        }

                        if (context.mounted) {
                          Navigator.pop(context, newWallet);
                          SheepNotifications.showSuccess(
                            context,
                            isEditing
                                ? 'Đã cập nhật thông tin ví!'
                                : 'Đã thêm ví mới thành công!',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showAdjustBalanceDialog(
    BuildContext context,
    WalletModel wallet,
  ) {
    final balanceController = TextEditingController(
      text: wallet.initialBalance > 0
          ? NumberFormat('#,###', 'vi_VN').format(wallet.initialBalance.toInt())
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        final settings =
            Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
        final accentColor =
            AppColors.getPalette(settings.themePresetName).primary;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(brightness),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SheepRadius.sheet),
            ),
          ),
          padding: EdgeInsets.only(
            top: SheepSpacing.md,
            left: SheepSpacing.page,
            right: SheepSpacing.page,
            bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(brightness)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: SheepSpacing.md),
              Text(
                'Điều Chỉnh Số Dư Thực Tế',
                style: SheepTextStyles.itemTitle(context).copyWith(
                  fontSize: SheepTypeScale.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nhập lại số dư thực tế trong tài khoản ${wallet.name} của bạn',
                style: SheepTextStyles.itemMeta(context),
              ),
              const SizedBox(height: SheepSpacing.lg),
              TextField(
                controller: balanceController,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: SheepTypeScale.headline,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(brightness),
                ),
                decoration: InputDecoration(
                  labelText: 'SỐ DƯ CHÍNH XÁC HIỆN TẠI',
                  suffixText: '₫',
                  suffixStyle: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: AppColors.getSubtleSurface(brightness),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(locale: 'vi_VN'),
                ],
              ),
              const SizedBox(height: SheepSpacing.xl),
              SheepButton(
                label: 'Cập nhật số dư',
                isFullWidth: true,
                backgroundColor: accentColor,
                onPressed: () async {
                  final cleanAmount = balanceController.text
                      .replaceAll(RegExp(r'[^0-9]'), '');
                  final newBalance = double.tryParse(cleanAmount) ?? 0;

                  await WalletService.adjustBalance(wallet.id, newBalance);
                  if (context.mounted) {
                    Navigator.pop(context);
                    SheepNotifications.showSuccess(
                      context,
                      'Đã cập nhật số dư ví ${wallet.name} thành ${CurrencyUtil.formatMoney(newBalance, locale: 'vi_VN')}₫',
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletManagementScreenState extends State<WalletManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final settings =
        Hive.box<AppSettings>(kSettingsBox).get('current') ?? AppSettings();
    final palette = AppColors.getPalette(settings.themePresetName);
    final accentColor = palette.primary;

    final bodyContent = ValueListenableBuilder<Box<String>>(
      valueListenable: Hive.box<String>(kWalletsBox).listenable(),
      builder: (context, box, _) {
          final wallets = WalletService.getWallets();
          final totalBalance = WalletService.getTotalBalance();

          return ListView(
            padding: const EdgeInsets.all(SheepSpacing.page),
            children: [
              // Thẻ Tổng Tài Sản
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(SheepRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TỔNG TÀI SẢN KHẢ DỤNG',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: SheepTypeScale.micro,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(SheepRadius.pill),
                          ),
                          child: Text(
                            '${wallets.length} ví',
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${CurrencyUtil.formatMoney(totalBalance, locale: 'vi_VN')} ₫',
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: SheepTypeScale.amountLarge,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tự động đồng bộ số dư khi quét QR hoặc chuyển tiền',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SheepSpacing.lg),

              SheepSectionTitle(
                title: 'DANH SÁCH VÍ CỦA BẠN',
                padding: const EdgeInsets.only(bottom: 8),
              ),

              // Danh sách từng ví
              ...wallets.map((wallet) {
                final linkedBank = wallet.bankId != null
                    ? BankDeeplinkService.findById(wallet.bankId)
                    : null;
                final walletColor = wallet.colorValue != null
                    ? Color(wallet.colorValue!)
                    : (linkedBank?.brandColor ?? accentColor);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SheepCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Avatar ví
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: walletColor.withValues(alpha: 0.14),
                            borderRadius:
                                BorderRadius.circular(SheepRadius.md),
                            border: Border.all(
                              color: walletColor.withValues(alpha: 0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: linkedBank != null
                              ? Text(
                                  linkedBank.shortName
                                      .substring(0, 3)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: walletColor,
                                  ),
                                )
                              : Icon(
                                  LineIcons.wallet,
                                  color: walletColor,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 12),

                        // Tên & Ngân hàng
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    wallet.name,
                                    style: SheepTextStyles.itemTitle(context),
                                  ),
                                  if (wallet.isDefault) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            accentColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Mặc định',
                                        style: TextStyle(
                                          fontFamily: 'Quicksand',
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                linkedBank?.fullName ??
                                    'Ví tiền mặt / Thủ công',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SheepTextStyles.itemMeta(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${CurrencyUtil.formatMoney(wallet.initialBalance, locale: 'vi_VN')} ₫',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: SheepTypeScale.item,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.getTextPrimary(brightness),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Menu Action 3 chấm
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: AppColors.getTextSecondary(brightness),
                            size: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SheepRadius.md),
                          ),
                          onSelected: (action) async {
                            if (action == 'default') {
                              await WalletService.setDefaultWallet(wallet.id);
                              if (context.mounted) {
                                SheepNotifications.showSuccess(
                                  context,
                                  'Đã đặt ${wallet.name} làm ví thanh toán mặc định!',
                                );
                              }
                            } else if (action == 'adjust') {
                              WalletManagementScreen.showAdjustBalanceDialog(
                                context,
                                wallet,
                              );
                            } else if (action == 'edit') {
                              WalletManagementScreen.showAddOrEditWalletDialog(
                                context,
                                walletToEdit: wallet,
                              );
                            } else if (action == 'delete') {
                              final deleted =
                                  await WalletService.deleteWallet(wallet.id);
                              if (context.mounted) {
                                if (deleted) {
                                  SheepNotifications.showSuccess(
                                    context,
                                    'Đã xóa ví ${wallet.name}',
                                  );
                                } else {
                                  SheepNotifications.showError(
                                    context,
                                    'Không thể xóa ví cuối cùng!',
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            if (!wallet.isDefault)
                              const PopupMenuItem(
                                value: 'default',
                                child: Row(
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 18, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text('Đặt làm mặc định'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'adjust',
                              child: Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Điều chỉnh số dư'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Sửa thông tin'),
                                ],
                              ),
                            ),
                            if (wallets.length > 1)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xóa ví',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: SheepSpacing.md),

              // Nút Thêm ví mới
              OutlinedButton.icon(
                icon: Icon(Icons.add_circle_outline_rounded,
                    color: accentColor, size: 20),
                label: Text(
                  'Thêm ví / tài khoản khác',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                  ),
                ),
                onPressed: () =>
                    WalletManagementScreen.showAddOrEditWalletDialog(context),
              ),
            ],
          );
        },
      );

    if (widget.isTab) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(brightness),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(brightness),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.getTextPrimary(brightness),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quản lý Ví & Tài khoản',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w700,
            fontSize: SheepTypeScale.title,
            color: AppColors.getTextPrimary(brightness),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: accentColor, size: 28),
            tooltip: 'Thêm ví mới',
            onPressed: () =>
                WalletManagementScreen.showAddOrEditWalletDialog(context),
          ),
        ],
      ),
      body: bodyContent,
    );
  }
}
