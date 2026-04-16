import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gf1/view-model/background_alarm.dart';
import 'package:gf1/model/notification_model.dart';
import 'package:gf1/view/services/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gf1/view/services/device_service.dart';

// --- GLOBAL NAVIGATOR KEY ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --- LOCAL NOTIFICATIONS PLUGIN ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialize local notifications with Stop Alarm action button.
/// Call this once from main() before runApp.
Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onNotificationAction,
    onDidReceiveBackgroundNotificationResponse: _onNotificationActionBackground,
  );

  // Create alarm notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alarm_channel',
    'Alarm Notifications',
    description: 'Aerator alert notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// Show a local notification with a STOP ALARM action button.
Future<void> showAlarmNotification({
  required String title,
  required String body,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'alarm_channel',
    'Alarm Notifications',
    channelDescription: 'Aerator alert notifications',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    ongoing: true,
    autoCancel: false,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        'stop_alarm', // action id
        '🛑 Stop Alarm',
        cancelNotification: true,
        showsUserInterface: false,
      ),
    ],
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    888, // fixed id so we can cancel it
    title,
    body,
    notificationDetails,
    payload: 'alarm',
  );
}

/// Cancel the alarm notification (call when alarm is stopped)
Future<void> cancelAlarmNotification() async {
  await flutterLocalNotificationsPlugin.cancel(888);
}

/// Handles notification action taps (foreground / background)
@pragma('vm:entry-point')
void _onNotificationActionBackground(NotificationResponse response) async {
  if (response.actionId == 'stop_alarm') {
    // Stop native alarm service
    try {
      const platform = MethodChannel('com.yubhiantech.pondmonitoring/alarm');
      await platform.invokeMethod('stopAlarm');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
    await cancelAlarmNotification();
  }
}

void _onNotificationAction(NotificationResponse response) async {
  if (response.actionId == 'stop_alarm') {
    try {
      const platform = MethodChannel('com.yubhiantech.pondmonitoring/alarm');
      await platform.invokeMethod('stopAlarm');
    } catch (_) {}
    try {
      await stopBackgroundAlarm();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
    await cancelAlarmNotification();
  }
}

class NotificationServices {
  final _firebaseMessaging = FirebaseMessaging.instance;
  static const String _tokenKey = 'fcm_token';
  // No in-app audio playback here to avoid double alarms.

  // Foreground dialog removed to avoid double notifications; rely on backend/system notification.

  // In-app sound helpers removed to avoid double alarms; backend/system drives sound.

  Future<void> initFcm() async {
    String? fcmToken;
    // await _firebaseMessaging.requestPermission();
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("✅ Notifications permission granted");
      fcmToken = await _firebaseMessaging.getToken();
    } else {
      debugPrint("❌ Notifications permission denied");
    }

    debugPrint("FCM Token: $fcmToken");

    if (fcmToken != null) {
      debugPrint("FCM Token Found: $fcmToken");
      await _saveTokenToPrefs(fcmToken);
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint("FCM Token Refreshed: $newToken");
      await _saveTokenToPrefs(newToken);
    });

    // 1. Handle Cold Start (App launched from terminated state via notification)
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM: App launched from terminated state via message');
      _handleNotificationClick(initialMessage);
    }

    // 2. Handle Resume (App in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM: App resumed from background via message');
      _handleNotificationClick(message);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // Foreground: trigger same background alarm path (with duplicate guard and timed stop)
      debugPrint(
        'Foreground FCM received: ${message.messageId} | ${message.notification?.title}',
      );
      // Persist to local storage so it shows in Notifications screen with time/title/body
      try {
        final notification = NotificationModel.fromRemoteMessage(message);
        await LocalNotificationService.saveNotification(notification);
      } catch (e) {
        debugPrint('Failed to save foreground notification: $e');
      }
      final bool shouldTrigger =
          (message.data['alarm'] == '1') || (message.notification != null);
      if (!shouldTrigger) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        final bool alertSoundEnabled =
            prefs.getBool('alert_sound_enabled') ?? true;

        if (alertSoundEnabled) {
          await initBackgroundAlarm();
          await triggerBackgroundAlarm();
        }
        // Always show local notification with Stop button regardless of sound setting
        await showAlarmNotification(
          title: message.notification?.title ?? '⚠️ Aerator Alert!',
          body: alertSoundEnabled
              ? (message.notification?.body ?? 'Tap to stop alarm.')
              : (message.notification?.body ?? 'Alert received.'),
        );
        _showForegroundAlert(message);
      } catch (e) {
        debugPrint('Failed to trigger alarm in foreground: $e');
      }
    });

  }

  /// Unified handler for notification clicks (Cold Start & Resume)
  void _handleNotificationClick(RemoteMessage message) async {
    debugPrint('Handling notification click. Data: ${message.data}');

    // Persist to local storage so it shows in Notifications screen
    try {
      final notification = NotificationModel.fromRemoteMessage(message);
      await LocalNotificationService.saveNotification(notification);
    } catch (e) {
      debugPrint('Failed to save clicked notification: $e');
    }

    // Determine the route based on the 'alarm' flag or content
    final bool isAlarm = message.data['alarm'] == '1';
    final String routeName = isAlarm ? '/alarm' : '/notifications';
    final Map<String, dynamic> arguments = {
      'title': message.notification?.title ?? 'Alert',
      'body': message.notification?.body ?? '',
      'isFromNotification': true, // signal AlarmScreen to show Stop dialog
    };

    // Ensure navigator is ready. 
    // If it's a cold start, we might need a small delay for the app to build.
    Future.microtask(() async {
      int retryCount = 0;
      while (navigatorKey.currentState == null && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retryCount++;
      }

      if (navigatorKey.currentState != null) {
        debugPrint('Navigating to $routeName');
        navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
      } else {
        debugPrint('ERROR: Navigator state still null after retries');
      }
    });
  }

  /// Show a foreground alert dialog with options to Stop or View
  void _showForegroundAlert(RemoteMessage message) {
    final ctx = navigatorKey.currentState?.context;
    if (ctx == null) return;
    final title = message.notification?.title ?? 'Alert';
    final body = message.notification?.body ?? '';

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () async {
              await stopAlarmNow();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Stop'),
          ),
          TextButton(
            onPressed: () async {
              await stopAlarmNow();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              _handleNotificationClick(message);
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  /// Stop native alarm service and clear playing flags
  Future<void> stopAlarmNow() async {
    try {
      const platform = MethodChannel('com.yubhiantech.pondmonitoring/alarm');
      await platform.invokeMethod('stopAlarm');
    } catch (_) {}
    try {
      await stopBackgroundAlarm();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
    // Also dismiss the persistent local notification with the Stop button
    await cancelAlarmNotification();
  }

  // Local persistence of notifications disabled per requirement to rely on backend notifications only.

  /// Save FCM token in SharedPreferences + Firestore (update or create)
  Future<void> _saveTokenToPrefs(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    debugPrint("FCM Token saved to SharedPreferences.");

    // FCM Token registration for "no-user" architecture
    // Each device saves under its own unique document (keyed by FCM token)
    // but shares the same deviceId field, so the server's query finds ALL devices.
    final deviceId = await DeviceService.getDeviceId();
    if (deviceId != null && deviceId.isNotEmpty) {
      try {
        // Use the token hash as doc ID so each install gets its own document
        final docId = 'fcm_${token.hashCode.toRadixString(16)}';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .set({
          'fcmToken': token,
          'deviceId': deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
          'isNoUserMode': true,
        }, SetOptions(merge: true));
        debugPrint("✅ FCM Token registered in Firestore for device: $deviceId (doc: $docId)");
      } catch (e) {
        debugPrint("❌ Failed to register FCM token in Firestore: $e");
      }
    }
  }

  static Future<String?> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Ensure Firestore user document contains the latest FCM token.
  /// Call this after login or app resume.
  static Future<void> ensureTokenSynced() async {
    final token = await getDeviceToken();
    if (token == null) return;

    final deviceId = await DeviceService.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) return;

    try {
      // Use the token hash as doc ID so each install gets its own document
      final docId = 'fcm_${token.hashCode.toRadixString(16)}';
      final docRef = FirebaseFirestore.instance.collection('users').doc(docId);
      final snap = await docRef.get();

      if (!snap.exists || snap.data()?['fcmToken'] != token) {
        await docRef.set({
          'fcmToken': token,
          'deviceId': deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
          'isNoUserMode': true,
        }, SetOptions(merge: true));
        debugPrint("✅ FCM Token sync complete for device: $deviceId (doc: $docId)");
      }
    } catch (e) {
      debugPrint("❌ FCM Token sync failed: $e");
    }
  }

  Future<AccessCredentials> _getAccessToken() async {
    final serviceAccountPath = dotenv.env['PATH_TO_SECRET'];
    String serviceAccountJson = await rootBundle.loadString(
      serviceAccountPath!,
    );
    final serviceAccount = ServiceAccountCredentials.fromJson(
      serviceAccountJson,
    );
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await clientViaServiceAccount(serviceAccount, scopes);
    return client.credentials;
  }

  Future<bool> sendPushNotification({
    required String deviceToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final projectId = dotenv.env['PROJECT_ID'];
      final String endpoint =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final credentials = await _getAccessToken();

      final Map<String, dynamic> message = {
        'message': {
          'token': deviceToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data ?? {},
          'android': {
            'notification': {
              'sound': 'alarm',
              'channel_id': 'alarm_channel',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
            'priority': 'high',
          },
        }
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${credentials.accessToken.data}',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        debugPrint('Notification sent successfully');
        return true;
      } else {
        debugPrint('Failed to send notification: ${response.statusCode}');
        debugPrint(response.body);
        return false;
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return false;
    }
  }

}

// NOTE: For Android FCM custom sound to play from the system notification,
// you must place a native raw resource file at:
// android/app/src/main/res/raw/alarm.mp3
// This is separate from the Flutter asset (assets/alarm.mp3) used by the in-app/foreground service.
// Both can exist so system notification plays instantly while the foreground loop continues.
