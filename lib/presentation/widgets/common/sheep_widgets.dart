import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n.dart';

class SheepSpacing {
  static const double page = 24;
  static const double sectionGap = 24;
  static const double itemGap = 12;
  static const double cardRadius = 16;
  static const double controlRadius = 12;
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: page,
  );
}

class SheepTextStyles {
  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextSecondary(Theme.of(context).brightness),
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle itemTitle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextPrimary(Theme.of(context).brightness),
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle itemMeta(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
      color: AppColors.getTextSecondary(Theme.of(context).brightness),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
  }

  static TextStyle emptyMessage(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextSecondary(Theme.of(context).brightness),
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.45,
      letterSpacing: 0,
    );
  }
}

class SheepCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? color;
  final BoxBorder? border;

  const SheepCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.getSurface(brightness),
        borderRadius: BorderRadius.circular(
          borderRadius ?? SheepSpacing.cardRadius,
        ),
        border: border ?? Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: AppColors.getSoftShadow(brightness),
      ),
      child: child,
    );
  }
}

class SheepSectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SheepSectionTitle({
    super.key,
    required this.title,
    this.padding = SheepSpacing.pageHorizontal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: SheepTextStyles.sectionTitle(context)),
      ),
    );
  }
}

class SheepEmptyState extends StatelessWidget {
  final String message;
  final String? description;
  final double assetWidth;
  final bool repeat;

  const SheepEmptyState({
    super.key,
    required this.message,
    this.description,
    this.assetWidth = 190,
    this.repeat = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/empty.json',
              width: assetWidth,
              repeat: repeat,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SheepTextStyles.emptyMessage(context),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: SheepTextStyles.itemMeta(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SheepButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? icon;

  const SheepButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isFullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? theme.primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      minimumSize: Size.fromHeight(
        icon != null ? 56 : 48,
      ), // Use icon presence as proxy for primary actions
    );

    Widget buttonChild = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon!, const SizedBox(width: 8), Text(label)],
          )
        : Text(label);

    Widget btn = ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: buttonChild,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

class SheepListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SheepListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SheepCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: SheepSpacing.itemGap),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SheepSpacing.cardRadius),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 15)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SheepTextStyles.itemTitle(context)),
                  if (subtitle != null)
                    DefaultTextStyle(
                      style: SheepTextStyles.itemMeta(context),
                      child: subtitle!,
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class SheepTransactionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String dateText;
  final String amountText;
  final Color amountColor;
  final String badgeText;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Color iconColor;
  final Color iconBackground;

  const SheepTransactionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.dateText,
    required this.amountText,
    required this.amountColor,
    required this.badgeText,
    this.onTap,
    this.margin,
    this.iconColor = Colors.black,
    this.iconBackground = const Color(0xFFF5F5F5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: SheepSpacing.itemGap),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 24, color: iconColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: SheepTextStyles.itemTitle(
                            context,
                          ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateText,
                          style: SheepTextStyles.itemMeta(
                            context,
                          ).copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF7A7A7A),
                    size: 30,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F1F1))),
              ),
              child: Row(
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE7E7E7)),
                    ),
                    child: Text(
                      badgeText,
                      style: SheepTextStyles.itemMeta(context).copyWith(
                        color: AppColors.getTextPrimary(
                          Theme.of(context).brightness,
                        ),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SheepDateMode { day, month }

class SheepDatePicker {
  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    SheepDateMode mode = SheepDateMode.day,
  }) async {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        DateTime tempDate = initialDate;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget pickerView;

            if (mode == SheepDateMode.month) {
              pickerView = SizedBox(
                height: 300,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setModalState(
                            () => tempDate = DateTime(
                              tempDate.year - 1,
                              tempDate.month,
                            ),
                          ),
                        ),
                        Text(
                          '${tempDate.year}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setModalState(
                            () => tempDate = DateTime(
                              tempDate.year + 1,
                              tempDate.month,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final isSelected = tempDate.month == month;
                          return InkWell(
                            onTap: () {
                              final newDate = DateTime(tempDate.year, month);
                              Navigator.pop(context, newDate);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.primaryColor
                                    : theme.primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${l10n.get('month')} $month',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : theme.textTheme.bodyMedium?.color,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            } else {
              pickerView = Theme(
                data: theme.copyWith(
                  colorScheme: theme.colorScheme.copyWith(
                    primary: theme.primaryColor,
                  ),
                ),
                child: SizedBox(
                  height: 350,
                  child: CalendarDatePicker(
                    initialDate: tempDate,
                    firstDate: firstDate ?? DateTime(2000),
                    lastDate: lastDate ?? DateTime(2100),
                    onDateChanged: (date) {
                      Navigator.pop(context, date);
                    },
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    DateFormat(
                      mode == SheepDateMode.month
                          ? 'MMMM yyyy'
                          : 'dd MMMM yyyy',
                      Localizations.localeOf(context).toString(),
                    ).format(tempDate),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  pickerView,
                  const SizedBox(height: 10),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
