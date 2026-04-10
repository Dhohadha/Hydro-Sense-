import 'package:flutter/material.dart';
import 'package:gf1/view/widgets/notification_badge.dart';
import '../view/utils/color_constants.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primaryColor,
      unselectedItemColor: AppColors.grey,
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),

        // Notification item with badge
        BottomNavigationBarItem(
          icon: const NotificationBadge(
            size: 16.0,
            child: Icon(Icons.notifications),
          ),
          label: 'Alerts',
        ),

        const BottomNavigationBarItem(
          icon: Icon(Icons.bolt),
          label: 'Capacitors',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
