import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n.dart';
import '../widgets/common/sheep_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
                  } else if (value == 'clear_all') {
                    await box.clear();
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
                    value: 'clear_all',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          l10n.get('clear_all'),
                          style: const TextStyle(color: Colors.red),
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
              child: SheepEmptyState(
                message: l10n.get('no_notifications'),
              ),
            );
          }

          // Convert Hive box items to list and sort by dateTime descending
          final items = box.toMap().entries.toList()
            ..sort((a, b) {
              final aTime = DateTime.parse(a.value['dateTime'] as String);
              final bTime = DateTime.parse(b.value['dateTime'] as String);
              return bTime.compareTo(aTime);
            });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final entry = items[index];
              final key = entry.key;
              final map = Map<String, dynamic>.from(entry.value as Map);
              final String id = map['id'] as String;
              final String title = map['title'] as String;
              final String content = map['content'] as String;
              final DateTime dateTime = DateTime.parse(map['dateTime'] as String);
              final bool isRead = map['isRead'] as bool? ?? false;
              final String type = map['type'] as String;

              final visual = _getNotificationVisual(type, isDark);

              return Dismissible(
                key: Key(id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: SheepSpacing.itemGap),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SheepRadius.xl),
                  ),
                  child: const Icon(
                    LineIcons.trash,
                    color: AppColors.expense,
                    size: 28,
                  ),
                ),
                onDismissed: (_) async {
                  await box.delete(key);
                },
                child: Container(
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
                    boxShadow: isRead ? null : [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
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

                      // Special click actions:
                      // If savings completed or halfway, jump to Savings tab (index 2)
                      if (type == 'savings_completed' || type == 'savings_halfway') {
                        if (context.mounted) {
                          Navigator.pop(context, 2); // Return index 2 to navigate to Savings tab
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: visual.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(SheepRadius.md),
                            ),
                            child: Icon(visual.icon, color: visual.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.bold : FontWeight.w800,
                                          fontSize: SheepTypeScale.item,
                                          color: AppColors.getTextPrimary(theme.brightness),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(dateTime, l10n.locale.languageCode),
                                      style: TextStyle(
                                        fontSize: SheepTypeScale.micro,
                                        color: AppColors.getTextSecondary(theme.brightness),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  content,
                                  style: TextStyle(
                                    fontSize: SheepTypeScale.body,
                                    color: isRead
                                        ? AppColors.getTextSecondary(theme.brightness)
                                        : AppColors.getTextPrimary(theme.brightness),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Unread Blue Dot
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
        return _NotifVisual(Icons.warning_amber_rounded, const Color(0xFFF9A825)); // Gold/Yellow
      case 'savings_completed':
        return _NotifVisual(Icons.star_rounded, const Color(0xFFFBC02D)); // Gold Star
      case 'savings_halfway':
        return _NotifVisual(Icons.trending_up_rounded, AppColors.savings);
      case 'daily_reminder':
      default:
        return _NotifVisual(Icons.alarm_on_rounded, AppColors.income);
    }
  }
}

class _NotifVisual {
  final IconData icon;
  final Color color;
  const _NotifVisual(this.icon, this.color);
}
