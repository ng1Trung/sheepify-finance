import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n.dart';
import '../widgets/common/sheep_widgets.dart';
import '../widgets/common/sheep_dialogs.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _limit = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(theme.brightness),
      appBar: AppBar(
        title: Text(
          l10n.get('notifications'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: Hive.box('notifications').listenable(),
            builder: (context, Box box, _) {
              if (box.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'mark_read') {
                    for (var key in box.keys) {
                      final item = box.get(key);
                      if (item is Map && item['isRead'] == false) {
                        final updated = Map<String, dynamic>.from(item);
                        updated['isRead'] = true;
                        await box.put(key, updated);
                      }
                    }
                  } else if (value == 'delete_all') {
                    showDialog(
                      context: context,
                      builder: (ctx) => SheepConfirmDialog(
                        title: l10n.locale.languageCode == 'vi' ? 'Xoá tất cả thông báo?' : 'Delete all notifications?',
                        content: l10n.locale.languageCode == 'vi' ? 'Hành động này sẽ xoá toàn bộ lịch sử thông báo và không thể hoàn tác.' : 'This action will clear all notification history and cannot be undone.',
                        confirmLabel: l10n.locale.languageCode == 'vi' ? 'Xoá' : 'Delete',
                        confirmColor: AppColors.expense,
                        icon: Icons.delete_sweep_outlined,
                        onConfirm: () async {
                          await box.clear();
                        },
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        const Icon(Icons.mark_chat_read_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.get('mark_all_read')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_sweep_outlined,
                          size: 20,
                          color: AppColors.expense,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.locale.languageCode == 'vi' ? 'Xoá tất cả' : 'Delete all',
                          style: const TextStyle(color: AppColors.expense),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('notifications').listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return Center(
              child: SheepEmptyState(message: l10n.get('no_notifications')),
            );
          }

          // Convert Hive box items to list, filter valid notifications, and sort by dateTime descending
          final items =
              box
                  .toMap()
                  .entries
                  .where(
                    (entry) =>
                        entry.value is Map && entry.value['dateTime'] != null,
                  )
                  .toList()
                ..sort((a, b) {
                  final aTime = DateTime.parse(a.value['dateTime'] as String);
                  final bTime = DateTime.parse(b.value['dateTime'] as String);
                  return bTime.compareTo(aTime);
                });

          final totalCount = items.length;
          final displayedItems = items.take(_limit).toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: displayedItems.length + (totalCount > _limit ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == displayedItems.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _limit += 10;
                        });
                      },
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(
                        l10n.locale.languageCode == 'vi'
                            ? 'Xem thêm'
                            : 'Load more',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                          side: BorderSide(
                            color: theme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final entry = displayedItems[index];
              final key = entry.key;
              final map = Map<String, dynamic>.from(entry.value as Map);
              final String content = map['content'] as String;
              final DateTime dateTime = DateTime.parse(
                map['dateTime'] as String,
              );
              final bool isRead = map['isRead'] as bool? ?? false;
              final String type = map['type'] as String;

              final visual = _getNotificationVisual(type, isDark);

              return Container(
                margin: const EdgeInsets.only(bottom: SheepSpacing.itemGap),
                decoration: BoxDecoration(
                  color: isRead
                      ? AppColors.getSurface(theme.brightness)
                      : (isDark
                            ? const Color(0xFF2E2C36)
                            : theme.primaryColor.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(SheepRadius.xl),
                  border: Border.all(
                    color: isRead
                        ? AppColors.getBorder(theme.brightness)
                        : theme.primaryColor.withValues(alpha: 0.2),
                    width: isRead ? 1.0 : 1.5,
                  ),
                  boxShadow: isRead
                      ? null
                      : [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SheepRadius.xl),
                  onTap: () async {
                    // Mark as read
                    if (!isRead) {
                      map['isRead'] = true;
                      await box.put(key, map);
                    }

                    // Navigation logic:
                    if (context.mounted) {
                      if (type == 'savings_completed' ||
                          type == 'savings_halfway') {
                        Navigator.pop(
                          context,
                          2,
                        ); // Return index 2 to navigate to Savings tab
                      } else if (type == 'budget_exceeded' ||
                          type == 'budget_threshold') {
                        Navigator.pop(
                          context,
                          3,
                        ); // Return index 3 to navigate to Categories tab
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: 4,
                      left: 4,
                      right: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: visual.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(SheepRadius.md),
                          ),
                          child: Icon(
                            visual.icon,
                            color: visual.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: _parseHtmlToSpans(
                                    content,
                                    TextStyle(
                                      fontSize: SheepTypeScale.body,
                                      color: AppColors.getTextPrimary(
                                        theme.brightness,
                                      ),
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.w500,
                                      height: 1.4,
                                    ),
                                    TextStyle(
                                      fontSize: SheepTypeScale.body,
                                      color: AppColors.getTextPrimary(
                                        theme.brightness,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(dateTime, l10n.locale.languageCode),
                                style: TextStyle(
                                  fontSize: SheepTypeScale.micro,
                                  color: AppColors.getTextSecondary(
                                    theme.brightness,
                                  ).withValues(alpha: 0.6),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 2),
                        // 3-dots actions menu
                        Material(
                          color: Colors.transparent,
                          child: IconButton(
                            icon: const Icon(Icons.more_vert_rounded),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            splashRadius: 14,
                            color: AppColors.getTextSecondary(theme.brightness),
                            onPressed: () {
                              _showNotificationOptions(
                                context: context,
                                hiveKey: key,
                                map: map,
                                box: box,
                                l10n: l10n,
                                theme: theme,
                              );
                            },
                          ),
                        ),
                        // Unread Blue Dot (At the very end of card)
                        if (!isRead) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showNotificationOptions({
    required BuildContext context,
    required dynamic hiveKey,
    required Map<String, dynamic> map,
    required Box box,
    required L10n l10n,
    required ThemeData theme,
  }) {
    final isRead = map['isRead'] as bool? ?? false;
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(theme.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF42404B)
                        : const Color(0xFFE7DDE1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                // Toggle Read/Unread option
                _NotificationActionTile(
                  icon: isRead
                      ? Icons.mark_chat_unread_outlined
                      : Icons.mark_chat_read_outlined,
                  label: isRead
                      ? l10n.get('mark_as_unread')
                      : l10n.get('mark_as_read'),
                  color: theme.primaryColor,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final updated = Map<String, dynamic>.from(map);
                    updated['isRead'] = !isRead;
                    await box.put(hiveKey, updated);
                  },
                ),
                // Delete notification option
                _NotificationActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: l10n.get('delete_notification'),
                  color: AppColors.expense,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await box.delete(hiveKey);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime, String lang) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return lang == 'vi' ? 'Vừa xong' : 'Just now';
    } else if (difference.inMinutes < 60) {
      return lang == 'vi'
          ? '${difference.inMinutes} phút trước'
          : '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && dateTime.day == now.day) {
      return DateFormat('HH:mm').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  _NotifVisual _getNotificationVisual(String type, bool isDark) {
    switch (type) {
      case 'budget_exceeded':
        return _NotifVisual(Icons.error_outline_rounded, AppColors.expense);
      case 'budget_threshold':
        return _NotifVisual(
          Icons.warning_amber_rounded,
          const Color(0xFFF9A825),
        ); // Gold/Yellow
      case 'savings_completed':
        return _NotifVisual(
          Icons.star_rounded,
          const Color(0xFFFBC02D),
        ); // Gold Star
      case 'savings_halfway':
        return _NotifVisual(Icons.trending_up_rounded, AppColors.savings);
      case 'daily_reminder':
      default:
        return _NotifVisual(Icons.alarm_on_rounded, AppColors.income);
    }
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
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: normalStyle,
          ),
        );
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: normalStyle));
    }
    if (spans.isEmpty && text.isNotEmpty) {
      spans.add(TextSpan(text: text, style: normalStyle));
    }
    return spans;
  }
}

class _NotifVisual {
  final IconData icon;
  final Color color;
  const _NotifVisual(this.icon, this.color);
}

class _NotificationActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NotificationActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      minVerticalPadding: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: color == AppColors.expense
              ? AppColors.expense
              : AppColors.getTextPrimary(theme.brightness),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      onTap: onTap,
    );
  }
}
