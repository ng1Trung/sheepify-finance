import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n.dart';

class SheepSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 12;
  static const double sectionGap = 24;
  static const double itemGap = 12;
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: page,
  );
}

class SheepRadius {
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double sheet = 24;
  static const double pill = 999;
}

class SheepTypeScale {
  static const double micro = 11;
  static const double meta = 12;
  static const double label = 13;
  static const double body = 14;
  static const double item = 14;
  static const double bodyLarge = 16;
  static const double title = 18;
  static const double amount = 16;
  static const double amountLarge = 30;
  static const double headline = 24;
}

class SheepTextStyles {
  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextSecondary(Theme.of(context).brightness),
      fontSize: SheepTypeScale.item,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle itemTitle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextPrimary(Theme.of(context).brightness),
      fontSize: SheepTypeScale.item,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle itemMeta(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
      color: AppColors.getTextSecondary(Theme.of(context).brightness),
      fontSize: SheepTypeScale.meta,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
  }

  static TextStyle dateHeader(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextSecondary(
        brightness,
      ).withValues(alpha: brightness == Brightness.light ? 0.42 : 0.58),
      fontSize: SheepTypeScale.item,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
  }

  static TextStyle emptyMessage(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.getTextSecondary(Theme.of(context).brightness),
      fontSize: SheepTypeScale.item,
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
        borderRadius: BorderRadius.circular(borderRadius ?? SheepRadius.xl),
        border: border ?? Border.all(color: AppColors.getBorder(brightness)),
        boxShadow: AppColors.getSoftShadow(brightness),
      ),
      child: child,
    );
  }
}

class SheepCategoryIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const SheepCategoryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(SheepRadius.md),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
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
  final VoidCallback? onPressed;
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
    final resolvedBackground = backgroundColor ?? theme.primaryColor;
    final resolvedForeground =
        foregroundColor ??
        AppColors.getOnAccent(theme.brightness, resolvedBackground);
    final style = ElevatedButton.styleFrom(
      backgroundColor: resolvedBackground,
      foregroundColor: resolvedForeground,
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
        borderRadius: BorderRadius.circular(SheepRadius.xl),
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
  final String? badgeText;
  final IconData? amountIcon;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Color? iconColor;
  final Color? iconBackground;
  final Color? iconBorderColor;

  const SheepTransactionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.dateText,
    required this.amountText,
    required this.amountColor,
    this.badgeText,
    this.amountIcon,
    this.onTap,
    this.margin,
    this.iconColor,
    this.iconBackground,
    this.iconBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final borderColor = AppColors.getBorder(brightness);
    final resolvedIconColor = iconColor ?? AppColors.getTextPrimary(brightness);
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: SheepSpacing.itemGap),
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: BorderRadius.circular(SheepRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SheepRadius.lg),
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        iconBackground ?? resolvedIconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                    border: Border.all(
                      color:
                          iconBorderColor ?? resolvedIconColor.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(icon, size: 17, color: resolvedIconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: SheepTextStyles.itemTitle(context)
                                  .copyWith(
                                    fontSize: SheepTypeScale.item,
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (amountIcon != null) ...[
                                Icon(amountIcon, size: 16, color: amountColor),
                                const SizedBox(width: 3),
                              ],
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 128,
                                ),
                                child: Text(
                                  amountText,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: SheepTypeScale.item,
                                    fontWeight: FontWeight.w700,
                                    color: amountColor,
                                    letterSpacing: 0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (dateText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        FractionallySizedBox(
                          widthFactor: 0.72,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dateText,
                            style: SheepTextStyles.itemMeta(
                              context,
                            ).copyWith(fontSize: SheepTypeScale.body),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SheepTransactionTypeVisuals {
  final IconData icon;
  final Color color;

  const SheepTransactionTypeVisuals._({
    required this.icon,
    required this.color,
  });

  static SheepTransactionTypeVisuals fromTypeIndex(int typeIndex) {
    if (typeIndex == 1) {
      return const SheepTransactionTypeVisuals._(
        icon: Icons.add_rounded,
        color: AppColors.income,
      );
    }
    if (typeIndex == 2) {
      return const SheepTransactionTypeVisuals._(
        icon: Icons.arrow_upward_rounded,
        color: AppColors.savings,
      );
    }
    return const SheepTransactionTypeVisuals._(
      icon: Icons.remove_rounded,
      color: AppColors.expense,
    );
  }

  Color get backgroundColor => color.withOpacity(0.1);

  Color get borderColor => color.withOpacity(0.22);
}

class SheepDatePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final BoxBorder? border;

  const SheepDatePill({
    super.key,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicWidth(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SheepRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                (theme.brightness == Brightness.light
                    ? Colors.white
                    : AppColors.getSurface(theme.brightness)),
            borderRadius: BorderRadius.circular(SheepRadius.xl),
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(theme.brightness),
              ),
            ),
          ),
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
        DateTime visibleDateMonth = DateTime(
          initialDate.year,
          initialDate.month,
        );
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
                    const SizedBox(height: SheepSpacing.xl),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2,
                              mainAxisSpacing: SheepSpacing.sm,
                              crossAxisSpacing: SheepSpacing.sm,
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
                            borderRadius: BorderRadius.circular(SheepRadius.md),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.primaryColor
                                    : theme.primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(
                                  SheepRadius.md,
                                ),
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
              final locale = Localizations.localeOf(context).toString();
              final visibleMonth = visibleDateMonth;
              final firstDay = DateTime(
                visibleMonth.year,
                visibleMonth.month,
                1,
              );
              final daysInMonth = DateTime(
                visibleMonth.year,
                visibleMonth.month + 1,
                0,
              ).day;
              final leadingDays = firstDay.weekday - 1;
              final totalCells = leadingDays + daysInMonth;
              final weekdayLabels = locale.startsWith('vi')
                  ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                  : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final minDate = firstDate ?? DateTime(2000);
              final maxDate = lastDate ?? DateTime(2100);

              bool isSameDay(DateTime a, DateTime b) =>
                  a.year == b.year && a.month == b.month && a.day == b.day;

              bool isSelectable(DateTime date) =>
                  !date.isBefore(
                    DateTime(minDate.year, minDate.month, minDate.day),
                  ) &&
                  !date.isAfter(
                    DateTime(maxDate.year, maxDate.month, maxDate.day),
                  );

              pickerView = Column(
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', locale).format(visibleMonth),
                        style: SheepTextStyles.itemTitle(context),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setModalState(
                          () => visibleDateMonth = DateTime(
                            visibleMonth.year,
                            visibleMonth.month - 1,
                          ),
                        ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        onPressed: () => setModalState(
                          () => visibleDateMonth = DateTime(
                            visibleMonth.year,
                            visibleMonth.month + 1,
                          ),
                        ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: SheepSpacing.sm),
                  Row(
                    children: weekdayLabels
                        .map((label) => _WeekdayLabel(label))
                        .toList(),
                  ),
                  const SizedBox(height: SheepSpacing.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: totalCells,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (context, index) {
                      if (index < leadingDays) return const SizedBox.shrink();
                      final date = DateTime(
                        visibleMonth.year,
                        visibleMonth.month,
                        index - leadingDays + 1,
                      );
                      final selected = isSameDay(tempDate, date);
                      final selectable = isSelectable(date);
                      return InkWell(
                        borderRadius: BorderRadius.circular(SheepRadius.pill),
                        onTap: selectable
                            ? () => Navigator.pop(context, date)
                            : null,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.getInteractiveAccent(
                                    theme.brightness,
                                    theme.colorScheme.primary,
                                  )
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              color: selected
                                  ? AppColors.getOnAccent(
                                      theme.brightness,
                                      theme.colorScheme.primary,
                                    )
                                  : selectable
                                  ? AppColors.getTextPrimary(theme.brightness)
                                  : AppColors.getTextSecondary(
                                      theme.brightness,
                                    ),
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(
                SheepSpacing.xl,
                SheepSpacing.xl,
                SheepSpacing.xl,
                SheepSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.getSurface(theme.brightness),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SheepRadius.sheet),
                ),
                border: Border.all(
                  color: AppColors.getBorder(theme.brightness),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(SheepRadius.sm),
                      ),
                    ),
                    const SizedBox(height: SheepSpacing.xl),
                    Text(
                      DateFormat(
                        mode == SheepDateMode.month
                            ? 'MMMM yyyy'
                            : 'dd MMMM yyyy',
                        Localizations.localeOf(context).toString(),
                      ).format(tempDate),
                      style: theme.textTheme.titleLarge,
                    ),
                    SizedBox(
                      height: mode == SheepDateMode.month
                          ? SheepSpacing.sm
                          : SheepSpacing.lg,
                    ),
                    pickerView,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SheepDateRangePicker {
  static Future<DateTimeRange?> show({
    required BuildContext context,
    required DateTimeRange initialRange,
  }) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        DateTime visibleMonth = DateTime(
          initialRange.start.year,
          initialRange.start.month,
        );
        DateTime? start = DateTime(
          initialRange.start.year,
          initialRange.start.month,
          initialRange.start.day,
        );
        DateTime? end = DateTime(
          initialRange.end.year,
          initialRange.end.month,
          initialRange.end.day,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
            final daysInMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month + 1,
              0,
            ).day;
            final leadingDays = firstDay.weekday - 1;
            final totalCells = leadingDays + daysInMonth;
            final weekdayLabels = locale.startsWith('vi')
                ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

            bool isSameDay(DateTime? a, DateTime b) =>
                a != null &&
                a.year == b.year &&
                a.month == b.month &&
                a.day == b.day;

            bool isInRange(DateTime date) =>
                start != null &&
                end != null &&
                date.isAfter(start!) &&
                date.isBefore(end!);

            void selectDate(DateTime date) {
              setModalState(() {
                if (start == null || end != null) {
                  start = date;
                  end = null;
                  return;
                }

                if (date.isBefore(start!)) {
                  end = start;
                  start = date;
                } else {
                  end = date;
                }
              });
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(
                SheepSpacing.xl,
                SheepSpacing.xl,
                SheepSpacing.xl,
                SheepSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.getSurface(theme.brightness),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SheepRadius.sheet),
                ),
                border: Border.all(
                  color: AppColors.getBorder(theme.brightness),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(SheepRadius.sm),
                      ),
                    ),
                    const SizedBox(height: SheepSpacing.xl),
                    Text(
                      end == null ||
                              (start!.year == end!.year &&
                                  start!.month == end!.month &&
                                  start!.day == end!.day)
                          ? DateFormat('dd MMMM yyyy', locale).format(start!)
                          : '${DateFormat('dd/MM/yyyy', locale).format(start!)} - ${DateFormat('dd/MM/yyyy', locale).format(end!)}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: SheepSpacing.lg),
                    Row(
                      children: [
                        Text(
                          DateFormat('MMMM yyyy', locale).format(visibleMonth),
                          style: SheepTextStyles.itemTitle(context),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setModalState(
                            () => visibleMonth = DateTime(
                              visibleMonth.year,
                              visibleMonth.month - 1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: () => setModalState(
                            () => visibleMonth = DateTime(
                              visibleMonth.year,
                              visibleMonth.month + 1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: SheepSpacing.sm),
                    Row(
                      children: weekdayLabels
                          .map((label) => _WeekdayLabel(label))
                          .toList(),
                    ),
                    const SizedBox(height: SheepSpacing.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalCells,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        if (index < leadingDays) return const SizedBox.shrink();
                        final date = DateTime(
                          visibleMonth.year,
                          visibleMonth.month,
                          index - leadingDays + 1,
                        );
                        final isEndpoint =
                            isSameDay(start, date) || isSameDay(end, date);
                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => selectDate(date),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isEndpoint
                                  ? AppColors.getInteractiveAccent(
                                      Theme.of(context).brightness,
                                      Theme.of(context).colorScheme.primary,
                                    )
                                  : isInRange(date)
                                  ? AppColors.getAccentSurface(
                                      Theme.of(context).brightness,
                                      Theme.of(context).colorScheme.primary,
                                    )
                                  : Colors.transparent,
                              shape: isEndpoint
                                  ? BoxShape.circle
                                  : BoxShape.rectangle,
                            ),
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                color: isEndpoint
                                    ? AppColors.getOnAccent(
                                        Theme.of(context).brightness,
                                        Theme.of(context).colorScheme.primary,
                                      )
                                    : AppColors.getTextPrimary(
                                        Theme.of(context).brightness,
                                      ),
                                fontWeight: isEndpoint
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final selectedEnd = end ?? start!;
                          Navigator.pop(
                            context,
                            DateTimeRange(
                              start: start!,
                              end: DateTime(
                                selectedEnd.year,
                                selectedEnd.month,
                                selectedEnd.day,
                                23,
                                59,
                                59,
                              ),
                            ),
                          );
                        },
                        child: Text(L10n.of(context).save),
                      ),
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
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(label, style: SheepTextStyles.itemMeta(context)),
      ),
    );
  }
}
