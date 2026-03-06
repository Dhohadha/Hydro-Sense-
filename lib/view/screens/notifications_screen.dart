import 'package:flutter/material.dart';
import 'package:gf1/model/notification_model.dart';
import 'package:gf1/view/services/local_notification_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await LocalNotificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await LocalNotificationService.markAllAsRead();
      await _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await LocalNotificationService.clearAllNotifications();
      await _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications cleared')),
      );
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await LocalNotificationService.markAsRead(id);
      await _loadNotifications();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await LocalNotificationService.deleteNotification(id);
      await _loadNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification deleted')));
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return 'Today, ${DateFormat.jm().format(date)}';
    } else if (notificationDate == yesterday) {
      return 'Yesterday, ${DateFormat.jm().format(date)}';
    } else {
      return DateFormat('MMM d, y • h:mm a').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  _markAllAsRead();
                } else if (value == 'clear_all') {
                  _clearAllNotifications();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Text('Mark all as read'),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all notifications'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll be notified when something arrives',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return Dismissible(
                    key: Key(notification.id),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      _deleteNotification(notification.id);
                    },
                    child: InkWell(
                      onTap: () {
                        if (!notification.isRead) {
                          _markAsRead(notification.id);
                        }
                        // Show notification details in a dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(notification.title),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notification.body),
                                const SizedBox(height: 12),
                                Text(
                                  _formatDate(notification.timestamp),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        color: notification.isRead
                            ? null
                            : Colors.blue.withValues(alpha: 0.05),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: notification.isRead
                                ? Colors.grey[300]
                                : Colors.blue,
                            child: Icon(
                              Icons.notifications,
                              color: notification.isRead
                                  ? Colors.grey[600]
                                  : Colors.white,
                            ),
                          ),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(notification.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: notification.isRead
                              ? null
                              : Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue,
                                  ),
                                ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      // floatingActionButton: Column(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   children: [
      //     FloatingActionButton.extended(
      //       onPressed: () => AlarmTestUtils.sendTestNotification(context),
      //       label: const Text('Test Notification'),
      //       icon: const Icon(Icons.send),
      //       heroTag: 'send_test',
      //     ),
      //     const SizedBox(height: 10),
      //     FloatingActionButton.extended(
      //       onPressed: () =>
      //           AlarmTestUtils.triggerBackgroundAlarmManually(context),
      //       label: const Text('Test Background Alarm'),
      //       icon: const Icon(Icons.alarm),
      //       heroTag: 'test_alarm',
      //     ),
      //     const SizedBox(height: 10),
      //     FloatingActionButton.extended(
      //       onPressed: () =>
      //           AlarmTestUtils.stopBackgroundAlarmManually(context),
      //       label: const Text('Stop Alarm'),
      //       icon: const Icon(Icons.alarm_off),
      //       heroTag: 'stop_alarm',
      //     ),
      //   ],
      // ),
    );
  }
}
