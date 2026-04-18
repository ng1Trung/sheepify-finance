import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

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
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        border: border,
        boxShadow: AppColors.getSoftShadow(brightness),
      ),
      child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    );

    Widget buttonChild = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon!,
              const SizedBox(width: 8),
              Text(label),
            ],
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
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 15),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) subtitle!,
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
