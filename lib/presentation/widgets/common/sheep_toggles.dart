import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = (totalWidth - 8) / 2;

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(24),
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
                    color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.getSurface(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: AppColors.getSoftShadow(Theme.of(context).brightness),
                  ),
                ),
              ),
              Row(
                children: [
                   _buildToggleItem(context, leftLabel ?? L10n.of(context).get('expense'), isExpense, AppColors.expense, () => onChanged(true)),
                   _buildToggleItem(context, rightLabel ?? L10n.of(context).get('income'), !isExpense, AppColors.income, () => onChanged(false)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleItem(BuildContext context, String title, bool isActive, Color color, VoidCallback onTap) {
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
              color: isActive ? color : Theme.of(context).textTheme.labelSmall?.color,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = L10n.of(context);
        final currentLabels = labels ?? [l10n.get('expense'), l10n.get('income'), l10n.get('savings')];
        final totalWidth = constraints.maxWidth;
        final itemWidth = (totalWidth - 8) / currentLabels.length;

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(24),
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
                  Color activeColor;
                  switch (index) {
                    case 0: activeColor = AppColors.expense; break;
                    case 1: activeColor = AppColors.income; break;
                    default: activeColor = AppColors.savings; break;
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? activeColor : Theme.of(context).textTheme.labelSmall?.color,
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.getSurface(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(21),
        boxShadow: AppColors.getSoftShadow(Theme.of(context).brightness),
      ),
    );
  }
}
