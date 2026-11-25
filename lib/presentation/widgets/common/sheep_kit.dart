import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'sheep_widgets.dart';

/// Small building blocks shared by every screen. Prefer these over
/// hand-rolled Containers so spacing, radius and colours stay in sync.

class SheepDragHandle extends StatelessWidget {
  const SheepDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.getBorder(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(SheepRadius.pill),
        ),
      ),
    );
  }
}

/// Standard bottom-sheet body: surface, top radius, drag handle, optional
/// title, safe-area aware padding. Open it with [SheepSheet.show] or with
/// `showModalBottomSheet(backgroundColor: Colors.transparent, ...)`.
class SheepSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const SheepSheet({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      SheepSpacing.lg,
      0,
      SheepSpacing.lg,
      SheepSpacing.lg,
    ),
    this.scrollable = false,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final body = Padding(
      padding: padding,
      child: child,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SheepRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: SheepSpacing.sm + 2),
            const SheepDragHandle(),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SheepSpacing.lg,
                  SheepSpacing.lg,
                  SheepSpacing.lg,
                  SheepSpacing.md,
                ),
                child: Text(title!, style: SheepTextStyles.sheetTitle(context)),
              )
            else
              const SizedBox(height: SheepSpacing.lg),
            if (scrollable) Flexible(child: SingleChildScrollView(child: body)) else body,
          ],
        ),
      ),
    );
  }
}

/// A rounded card whose children are separated by hairline dividers.
/// Used for grouped lists (transactions of a day, settings rows...).
class SheepGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final double dividerIndent;

  const SheepGroup({
    super.key,
    required this.children,
    this.margin,
    this.dividerIndent = 60,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(indent: dividerIndent, height: 1));
      }
      items.add(children[i]);
    }
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness),
        borderRadius: BorderRadius.circular(SheepRadius.xl),
        border: Border.all(color: AppColors.getBorder(brightness)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

/// Pill-shaped selectable chip. Selected = neutral primary fill; the
/// optional [leading] keeps any category colour.
class SheepChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  const SheepChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = selected
        ? AppColors.getPrimaryFill(brightness)
        : AppColors.getSurface(brightness);
    final foreground = selected
        ? AppColors.getOnPrimaryFill(brightness)
        : AppColors.getTextPrimary(brightness);
    return Material(
      color: background,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? background : AppColors.getBorder(brightness),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: EdgeInsets.only(
              left: leading != null ? 6 : 14,
              right: 14,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Text(
                  label,
                  style: SheepTextStyles.itemTitle(context).copyWith(
                    fontSize: SheepTypeScale.label,
                    fontWeight: FontWeight.w600,
                    color: foreground,
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

/// Round icon button with a soft background. Use [color] for destructive
/// or accented actions; defaults to neutral.
class SheepIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final double size;

  const SheepIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.size = SheepControl.heightLarge,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final foreground = color ?? AppColors.getTextPrimary(brightness);
    final background = color != null
        ? AppColors.tint(color!, brightness)
        : AppColors.getSubtleSurface(brightness);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: foreground, size: 22),
          ),
        ),
      ),
    );
  }
}
