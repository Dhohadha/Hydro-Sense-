import 'package:flutter/material.dart';
import 'package:gf1/view/services/local_notification_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color badgeColor;
  final double size;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.onTap,
    this.badgeColor = Colors.red,
    this.size = 20.0,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await LocalNotificationService.getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_unreadCount > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: widget.badgeColor,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: widget.size,
                  minHeight: widget.size,
                ),
                child: _unreadCount > 9
                    ? Center(
                        child: Text(
                          '9+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.size * 0.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _unreadCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.size * 0.6,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
