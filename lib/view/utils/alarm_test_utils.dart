import 'package:flutter/material.dart';
import 'package:gf1/view-model/background_alarm.dart';
import 'package:gf1/view/services/notification_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmTestUtils {
  /// Send a test notification that will trigger the background alarm
  static Future<void> sendTestNotification(BuildContext context) async {
    try {
      // Get the device token
      final deviceToken = await NotificationServices.getDeviceToken();

      if (deviceToken == null || deviceToken.isEmpty) {
        if (!context.mounted) return;
        _showSnackBar(
          context,
          'No FCM token available. Cannot send test notification.',
        );
        return;
      }

      // Send a test notification
      final notificationService = NotificationServices();
      final success = await notificationService.sendPushNotification(
        deviceToken: deviceToken,
        title: 'Test Background Alarm',
        body: 'This is a test notification to trigger the background alarm.',
        data: {
          'triggerAlarm': 'true',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (!context.mounted) return;
      if (success) {
        _showSnackBar(
          context,
          'Test notification sent. The alarm should trigger in the background.',
        );
      } else {
        _showSnackBar(context, 'Failed to send test notification.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Error sending test notification: $e');
    }
  }

  /// Manually trigger the background alarm for testing
  static Future<void> triggerBackgroundAlarmManually(
    BuildContext context,
  ) async {
    try {
      final success = await triggerBackgroundAlarm();

      if (!context.mounted) return;
      if (success) {
        _showSnackBar(
          context,
          'Background alarm triggered manually. You should hear the alarm soon.',
        );
      } else {
        _showSnackBar(context, 'Failed to trigger background alarm.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Error triggering background alarm: $e');
    }
  }

  /// Stop the background alarm
  static Future<void> stopBackgroundAlarmManually(BuildContext context) async {
    try {
      final success = await stopBackgroundAlarm();

      if (!context.mounted) return;
      if (success) {
        _showSnackBar(context, 'Background alarm stopped.');
      } else {
        _showSnackBar(context, 'Failed to stop background alarm.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Error stopping background alarm: $e');
    }
  }

  /// Check the status of the background alarm
  static Future<void> checkBackgroundAlarmStatus(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTrigger = prefs.getString('last_alarm_trigger');

      if (!context.mounted) return;
      if (lastTrigger != null) {
        final triggerTime = DateTime.parse(lastTrigger);
        final now = DateTime.now();
        final difference = now.difference(triggerTime);

        _showSnackBar(
          context,
          'Last alarm was triggered ${difference.inMinutes} minutes ago at ${triggerTime.hour}:${triggerTime.minute}:${triggerTime.second}.',
        );
      } else {
        _showSnackBar(context, 'No background alarm has been triggered yet.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Error checking background alarm status: $e');
    }
  }

  /// Show a snackbar with a message
  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }
}
