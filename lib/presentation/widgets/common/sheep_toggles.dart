import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SheepTypeToggle extends StatelessWidget {
  final bool isExpense;
  final Function(bool) onChanged;
  final String leftLabel;
  final String rightLabel;

  const SheepTypeToggle({
    super.key,
    required this.isExpense,
    required this.onChanged,
    this.leftLabel = "Chi",
    this.rightLabel = "Thu",
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: AppColors.softShadow,
                  ),
                ),
              ),
              Row(
                children: [
                   _buildToggleItem(leftLabel, isExpense, AppColors.expense, () => onChanged(true)),
                   _buildToggleItem(rightLabel, !isExpense, AppColors.income, () => onChanged(false)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleItem(String title, bool isActive, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isActive ? color : AppColors.textSecondary,
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
  final List<String> labels;
  final PageController? controller;

  const SheepTripleToggle({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels = const ["Chi tiêu", "Thu nhập", "Tích luỹ"],
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = (totalWidth - 8) / labels.length;

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
                        child: _buildIndicator(),
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
                    child: _buildIndicator(),
                  ),
              
              // TEXT LABELS
              Row(
                children: List.generate(labels.length, (index) {
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? activeColor : AppColors.textSecondary,
                          ),
                          child: Text(labels[index]),
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

  Widget _buildIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: AppColors.softShadow,
      ),
    );
  }
}
