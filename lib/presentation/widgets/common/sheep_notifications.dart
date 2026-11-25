import 'package:flutter/material.dart';
import 'sheep_widgets.dart';
import '../../../core/theme/app_colors.dart';

class SheepNotifications {
  static OverlayEntry? _currentOverlay;

  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: AppColors.primary,
      icon: Icons.check_circle_outline,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: AppColors.expense,
      icon: Icons.error_outline,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF3B82F6),
      icon: Icons.info_outline,
    );
  }

  /// Success toast with an inline action (e.g. "Undo"). Stays a bit longer
  /// so the user has time to react.
  static void showWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    _show(
      context,
      message,
      backgroundColor: AppColors.primary,
      icon: Icons.check_circle_outline,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 5),
    );
  }

  static void _dismissCurrent() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Remove current overlay if exists
    _currentOverlay?.remove();
    _currentOverlay = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _TopNotificationWidget(
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                _dismissCurrent();
                onAction();
              },
        onDismiss: _dismissCurrent,
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentOverlay == entry) {
        entry.remove();
        _currentOverlay = null;
      }
    });
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TopNotificationWidget({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<InlineSpan> _parseHtmlToSpans(
    String text,
    TextStyle normalStyle,
    TextStyle boldStyle,
  ) {
    final List<InlineSpan> spans = [];
    final RegExp regExp = RegExp(r'<b>(.*?)</b>');
    int lastIndex = 0;

    for (final RegExpMatch match in regExp.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: normalStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: boldStyle,
      ));
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: normalStyle,
      ));
    }
    if (spans.isEmpty && text.isNotEmpty) {
      spans.add(TextSpan(text: text, style: normalStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + SheepSpacing.sm,
      left: SheepSpacing.lg,
      right: SheepSpacing.lg,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SheepRadius.xl),
            child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SheepSpacing.lg,
                  vertical: SheepSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(SheepRadius.xl),
                  border: isDark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.12))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: _parseHtmlToSpans(
                            widget.message,
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              height: 1.3,
                            ),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null &&
                        widget.onAction != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          minimumSize: const Size(64, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SheepRadius.pill),
                          ),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onDismiss,
                    ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }
}
