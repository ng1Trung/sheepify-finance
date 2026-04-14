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
