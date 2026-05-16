import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n.dart';

class SheepSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  const SheepSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 42,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTrackColor = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );
    final isEnabled = onChanged != null;
    final inactiveTrackColor = theme.brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE5E7EB);
    final trackColor = value ? activeTrackColor : inactiveTrackColor;
    final thumbColor = value
        ? AppColors.getOnAccent(theme.brightness, activeTrackColor)
        : Colors.white;
    const inset = 2.0;
    final thumbSize = height - (inset * 2);
    final thumbLeft = value ? width - thumbSize - inset : inset;

    return Semantics(
      toggled: value,
      enabled: isEnabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? () => onChanged!(!value) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: isEnabled ? 1 : 0.45,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  left: thumbLeft,
                  top: inset,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
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
}

class SheepTypeToggle extends StatelessWidget {
  final bool isExpense;
  final Function(bool) onChanged;
  final String? leftLabel;
  final String? rightLabel;

  const SheepTypeToggle({
    super.key,
    required this.isExpense,
    required this.onChanged,
    this.leftLabel,
    this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );
    final onActiveColor = AppColors.getOnAccent(theme.brightness, activeColor);
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = (totalWidth - 8) / 2;

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.getSubtleSurface(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.getBorder(Theme.of(context).brightness),
            ),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: (isExpense ? 0 : 1) * itemWidth,
                width: itemWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppColors.getSoftShadow(
                      Theme.of(context).brightness,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildToggleItem(
                    context,
                    leftLabel ?? L10n.of(context).get('expense'),
                    isExpense,
                    onActiveColor,
                    () => onChanged(true),
                  ),
                  _buildToggleItem(
                    context,
                    rightLabel ?? L10n.of(context).get('income'),
                    !isExpense,
                    onActiveColor,
                    () => onChanged(false),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleItem(
    BuildContext context,
    String title,
    bool isActive,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? color
                  : Theme.of(context).textTheme.labelSmall?.color,
            ),
            child: Text(title),
          ),
        ),
      ),
    );
  }
}

class SheepTripleToggle extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onChanged;
  final List<String>? labels;
  final PageController? controller;

  const SheepTripleToggle({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );
    final onActiveColor = AppColors.getOnAccent(theme.brightness, activeColor);
    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = L10n.of(context);
        final currentLabels =
            labels ??
            [l10n.get('expense'), l10n.get('income'), l10n.get('savings')];
        final totalWidth = constraints.maxWidth;
        final itemWidth = (totalWidth - 8) / currentLabels.length;

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.getSubtleSurface(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.getBorder(Theme.of(context).brightness),
            ),
          ),
          child: Stack(
            children: [
              // SLIDING INDICATOR DRIVEN BY CONTROLLER OR INDEX
              controller != null
                  ? AnimatedBuilder(
                      animation: controller!,
                      builder: (context, _) {
                        double page = selectedIndex.toDouble();
                        if (controller!.hasClients) {
                          try {
                            page = controller!.page ?? selectedIndex.toDouble();
                          } catch (_) {}
                        }
                        return Positioned(
                          left: page * itemWidth,
                          width: itemWidth,
                          top: 0,
                          bottom: 0,
                          child: _buildIndicator(context),
                        );
                      },
                    )
                  : AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: selectedIndex * itemWidth,
                      width: itemWidth,
                      top: 0,
                      bottom: 0,
                      child: _buildIndicator(context),
                    ),

              // TEXT LABELS
              Row(
                children: List.generate(currentLabels.length, (index) {
                  final isActive = selectedIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? onActiveColor
                                    : Theme.of(
                                        context,
                                      ).textTheme.labelSmall?.color,
                              ),
                          child: Text(currentLabels[index]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = AppColors.getInteractiveAccent(
      theme.brightness,
      theme.colorScheme.primary,
    );
    return Container(
      decoration: BoxDecoration(
        color: activeColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppColors.getSoftShadow(Theme.of(context).brightness),
      ),
    );
  }
}
