import 'package:flutter/material.dart';
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

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
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
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
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

  const _TopNotificationWidget({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.onDismiss,
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.backgroundColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
