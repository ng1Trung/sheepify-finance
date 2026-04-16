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
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleItem(
              leftLabel,
              isExpense,
              AppColors.expense,
            ),
          ),
          Expanded(
            child: _buildToggleItem(
              rightLabel,
              !isExpense,
              AppColors.income,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool isActive, Color color) {
    return GestureDetector(
      onTap: () => onChanged(title == leftLabel),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          boxShadow: isActive ? AppColors.softShadow : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? color : AppColors.textSecondary,
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

  const SheepTripleToggle({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels = const ["Chi tiêu", "Thu nhập", "Tích luỹ"],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: isActive ? AppColors.softShadow : null,
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? activeColor : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
