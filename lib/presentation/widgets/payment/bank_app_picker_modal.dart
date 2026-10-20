import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/bank_deeplink_service.dart';
import '../common/sheep_widgets.dart';

/// Modal bottom sheet để người dùng tìm kiếm và chọn ứng dụng ngân hàng / ví điện tử
class BankAppPickerModal extends StatefulWidget {
  final BankAppModel? selectedBank;
  final ValueChanged<BankAppModel> onBankSelected;
  final String title;

  const BankAppPickerModal({
    super.key,
    required this.selectedBank,
    required this.onBankSelected,
    this.title = 'Chọn App Ngân Hàng / Ví',
  });

  /// Helper mở bottom sheet tiện lợi
  static Future<BankAppModel?> show({
    required BuildContext context,
    required BankAppModel? selectedBank,
    ValueChanged<BankAppModel>? onBankSelected,
    String title = 'Chọn App Ngân Hàng / Ví',
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<BankAppModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BankAppPickerModal(
        selectedBank: selectedBank,
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: SheepTextStyles.itemTitle(context).copyWith(
                    fontSize: SheepTypeScale.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            child: filteredBanks.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy ngân hàng phù hợp',
                      style: SheepTextStyles.itemMeta(context),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredBanks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final bank = filteredBanks[index];
                      final isSelected = widget.selectedBank?.id == bank.id;

                      return ListTile(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onBankSelected(bank);
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
                              color: bank.brandColor.withValues(alpha: 0.28),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            bank.shortName
                                .substring(0, bank.shortName.length.clamp(1, 3))
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
                              style: SheepTextStyles.itemTitle(context).copyWith(
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
                          style: SheepTextStyles.itemMeta(context).copyWith(
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded,
                                color: bank.brandColor)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Widget hiển thị thẻ chọn ứng dụng ngân hàng dạng dropdown / card
class BankAppSelectorTile extends StatelessWidget {
  final BankAppModel? bank;
  final VoidCallback onTap;
  final String label;

  const BankAppSelectorTile({
    super.key,
    required this.bank,
    required this.onTap,
    this.label = 'CHỌN APP NGÂN HÀNG / VÍ ĐỂ CHUYỂN TIỀN',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final b = bank ?? BankDeeplinkService.supportedBanks.first;

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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: b.brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(SheepRadius.sm),
                      border: Border.all(
                        color: b.brandColor.withValues(alpha: 0.25),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      b.shortName
                          .substring(0, b.shortName.length.clamp(1, 3))
                          .toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: b.brandColor,
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
                              b.shortName,
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
                                color: b.canAutofillPayment
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(SheepRadius.sm),
                              ),
                              child: Text(
                                b.canAutofillPayment ? 'Tự động' : 'Xác nhận',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: b.canAutofillPayment
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.fullName,
                          style: SheepTextStyles.itemMeta(context).copyWith(
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
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
