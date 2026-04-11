import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart'; // Import for AlertDialog
import 'package:flutter/services.dart';
import 'package:gf1/view-model/background_alarm.dart';
import 'package:gf1/model/notification_model.dart';
import 'package:gf1/view/services/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- ADD THIS GLOBAL KEY ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        _showForegroundAlert(message);
      } catch (e) {
        debugPrint('Failed to trigger alarm in foreground: $e');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('A new onMessageOpenedApp event was published!');
      debugPrint('Message data: ${message.data}');
      // Persist again (id-based de-dup keeps list clean)
      try {
        final notification = NotificationModel.fromRemoteMessage(message);
        await LocalNotificationService.saveNotification(notification);
      } catch (e) {
        debugPrint('Failed to save openedApp notification: $e');
      }
      // On tap from system notification, navigate but do not duplicate storage or sound
      navigatorKey.currentState?.pushNamed('/notifications');
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
              await _stopAlarmNow();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Stop'),
          ),
          TextButton(
            onPressed: () async {
              await _stopAlarmNow();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              navigatorKey.currentState?.pushNamed('/notifications');
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  /// Stop native alarm service and clear playing flags
  Future<void> _stopAlarmNow() async {
    try {
      const platform = MethodChannel('com.yubhiantech.pondmonitoring/alarm');
      await platform.invokeMethod('stopAlarm');
    } catch (_) {}
    try {
      await stopBackgroundAlarm();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_playing', false);
  }

  // Local persistence of notifications disabled per requirement to rely on backend notifications only.

  /// Save FCM token in SharedPreferences + Firestore (update or create)
  Future<void> _saveTokenToPrefs(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    debugPrint("FCM Token saved to SharedPreferences.");

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        // Always update/merge → will create if not exists, update if exists
        await userDoc.set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("✅ FCM Token saved/updated in Firestore for user: ${user.uid}");
      } catch (e) {
        debugPrint("❌ Error saving FCM token to Firestore: $e");
      }
    } else {
      debugPrint("⚠️ No logged-in user, token not saved to Firestore.");
    }
  }

  static Future<String?> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Ensure Firestore user document contains the latest FCM token.
  /// Call this after login or app resume.
  static Future<void> ensureTokenSynced() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final localToken = prefs.getString(_tokenKey);
    final currentToken = await FirebaseMessaging.instance.getToken();

    final tokenToUse = currentToken ?? localToken;
    if (tokenToUse == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final snap = await docRef.get();
      final remoteToken = snap.data()?['fcmToken'];
      if (remoteToken != tokenToUse) {
        await docRef.set({
          'fcmToken': tokenToUse,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }

  // --- SECURITY WARNING REMAINS ---
  // Future<AccessCredentials> _getAccessToken() async {
  //   final serviceAccountPath = dotenv.env['PATH_TO_SECRET'];
  //   // SECURITY NOTE: Consider moving this off-device in production.
  //   String serviceAccountJson = await rootBundle.loadString(
  //     serviceAccountPath!,
  //   );
  //   final serviceAccount = ServiceAccountCredentials.fromJson(
  //     serviceAccountJson,
  //   );
  //   final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  //   final client = await clientViaServiceAccount(serviceAccount, scopes);
  //   return client.credentials;
  // }

  Future<bool> sendPushNotification({
    required String deviceToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint(
      '🔒 SECURITY: Client-side push notifications are disabled for production. '
      'Please implement this logic on a secure backend (e.g., Firebase Cloud Functions).'
    );
    return false; // Disabled intentionally
  }

}

// NOTE: For Android FCM custom sound to play from the system notification,
// you must place a native raw resource file at:
// android/app/src/main/res/raw/alarm.mp3
// This is separate from the Flutter asset (assets/alarm.mp3) used by the in-app/foreground service.
// Both can exist so system notification plays instantly while the foreground loop continues.
