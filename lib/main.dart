import 'dart:async';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gf1/model/notification_model.dart';
import 'package:gf1/view-model/auth/auth_state.dart';
import 'package:gf1/view-model/background_alarm.dart';
import 'package:gf1/view/screens/notifications_screen.dart';
import 'package:gf1/view/screens/alarm_screen.dart';
import 'package:gf1/view/services/local_notification_service.dart';
import 'package:gf1/view/services/notification_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// Helper function to copy alarm file to local storage for background access
Future<void> _copyAlarmFileForBackground() async {
  try {
    // Get directory for storing application files
    final appDir = await getApplicationDocumentsDirectory();
    final File alarmFile = File('${appDir.path}/alarm.mp3');

    // Check if the file already exists
    if (!alarmFile.existsSync()) {
      // Load the asset as a ByteData
      final ByteData data = await rootBundle.load('assets/alarm.mp3');
      // Write ByteData to the file
      await alarmFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );

      // Log the successful copy
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_file_path', alarmFile.path);
      await prefs.setBool('alarm_file_copied', true);
    }
  } catch (e) {
    debugPrint('Error copying alarm file: $e');
    // Log the error
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_file_error', e.toString());
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_background_message',
      'Message ID: ${message.messageId}, Title: ${message.notification?.title}, Body: ${message.notification?.body}, Time: ${DateTime.now()}',
    );
    await prefs.setBool('background_message_received', true);

    final notification = NotificationModel.fromRemoteMessage(message);
    await LocalNotificationService.saveNotification(notification);

    // Only trigger when backend explicitly flags alarm via data.alarm == '1'
    final bool shouldTrigger = (message.data['alarm'] == '1');
    if (!shouldTrigger) {
      return; // ignore silent data if not flagged
    }

    // Start the native alarm service so alarm rings even when app is killed.
    try {
      final bool alertSoundEnabled =
          prefs.getBool('alert_sound_enabled') ?? true;
      if (alertSoundEnabled) {
        await initBackgroundAlarm();
        await _copyAlarmFileForBackground();
        await triggerBackgroundAlarm();
      }
    } catch (e) {
      await prefs.setString('fcm_background_log', 'Alarm trigger error: $e');
    }
  } catch (e) {
    debugPrint('Error in background message handler: $e');
  }
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    debugPrint('🚀 App starting initialization...');
    
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('✅ Dotenv loaded');
    } catch (e) {
      debugPrint('❌ Dotenv load failed: $e');
    }

    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized');
    } catch (e) {
      debugPrint('❌ Firebase init failed: $e');
    }

    try {
      await NotificationServices().initFcm();
      await NotificationServices.ensureTokenSynced();
      await initLocalNotifications(); // Sets up local notification + Stop button
      debugPrint('✅ FCM initialized and synced');
    } catch (e) {
      debugPrint('❌ FCM init/sync failed: $e');
    }

    try {
      final alarmInitialized = await initBackgroundAlarm();
      debugPrint('Background alarm service initialized: $alarmInitialized');
    } catch (e) {
      debugPrint('❌ Alarm init failed: $e');
    }

    await _copyAlarmFileForBackground();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    runApp(const MyApp());
    debugPrint('🏁 App execution started');
  }, (error, stackTrace) {
    debugPrint('🚨 UNHANDLED ASYNC ERROR: $error');
    debugPrint('📚 STACK TRACE: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
      routes: {
        '/notifications': (context) => const NotificationsScreen(),
        '/alarm': (context) => const AlarmScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  late AnimationController _solutionController;
  late Animation<double> _solutionAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool showMainAnimation = false;

  @override
  void initState() {
    super.initState();

    _stopNativeAlarm();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _solutionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _solutionAnimation = CurvedAnimation(
      parent: _solutionController,
      curve: Curves.easeIn,
    );

    // Optionally check background message logs (no auto playback)
    _checkBackgroundMessageStatus();

    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        showMainAnimation = true;
      });
      _controller.forward();
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _solutionController.forward();

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: Duration(milliseconds: 800),
              pageBuilder: (_, __, ___) => AuthGate(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        });
      }
    });
  }

  Future<void> _stopNativeAlarm() async {
    try {
      const platform = MethodChannel('com.yubhiantech.pondmonitoring/alarm');
      await platform.invokeMethod('stopAlarm');
      debugPrint('✅ Native alarm stopped on app open');
      // Also stop any scheduled background alarm and clear flags
      try {
        await stopBackgroundAlarm();
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_playing', false);
      await prefs.setBool('play_alarm_on_next_open', false);
    } catch (e) {
      debugPrint('Error stopping native alarm: $e');
    }
  }

  // In-app alarm playback helpers removed to avoid double alarms on app open.

  // This method checks if any background messages have been received
  Future<void> _checkBackgroundMessageStatus() async {
    try {
      // Check notification permission status first
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      final permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      // Get background message status
      final prefs = await SharedPreferences.getInstance();
      final wasReceived = prefs.getBool('background_message_received') ?? false;
      final lastMessage =
          prefs.getString('last_background_message') ?? 'None received';

      // Display status message
      if (!permissionGranted) {
        _showNotificationBanner(
          'Notification Permission Required',
          'Background notifications are disabled. Please enable notifications in settings.',
          Colors.orange.shade800,
        );
      } else if (wasReceived) {
        debugPrint('✅ BACKGROUND MESSAGE WAS RECEIVED: $lastMessage');
        // _showNotificationBanner(
        //   'Background Notifications Working',
        //   'Last message received at: ${lastMessage.split('Time:').last}',
        //   Colors.green.shade700,
        // );
      } else {
        _showNotificationBanner(
          'Background Notifications Enabled',
          'No background messages received yet. Try sending a test notification.',
          Colors.blue.shade700,
        );
      }
    } catch (e) {
      debugPrint('Error checking background message status: $e');
      _showNotificationBanner(
        'Error Checking Notifications',
        'Could not verify notification status: ${e.toString()}',
        Colors.red.shade700,
      );
    }
  }

  // Shows a banner at the top of the splash screen
  void _showNotificationBanner(String title, String message, Color color) {
    // Only show after the splash animation has started
    Future.delayed(Duration(milliseconds: 1200), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(message, style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: color,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _solutionController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget buildAnimatedText() {
    final String g = 'S';
    final String reen = 'mart';
    final String f = 'S';
    final String usion = 'ynergies';

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double progress = _animation.value;

        int rLength = (reen.length * progress).floor();
        int uLength = (usion.length * progress).floor();

        String reenVisible = reen.substring(0, rLength);
        String usionVisible = usion.substring(0, uLength);

        double partialProgressReen = (reen.length * progress) - rLength;
        double partialProgressUsion = (usion.length * progress) - uLength;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  g,
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontFamily: 'Georgia',
                  ),
                ),
                if (showMainAnimation)
                  Row(
                    children: [
                      Text(
                        reenVisible,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w100,
                          color: Colors.green.shade400,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      if (rLength < reen.length)
                        Opacity(
                          opacity: partialProgressReen.clamp(0, 1),
                          child: Text(
                            reen[rLength],
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w100,
                              color: Colors.green.shade400,
                              fontFamily: 'Georgia',
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: 20),
                Text(
                  f,
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                    fontFamily: 'Times New Roman',
                  ),
                ),
                if (showMainAnimation)
                  Row(
                    children: [
                      Text(
                        usionVisible,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          color: const Color.fromARGB(255, 33, 162, 243),
                          fontFamily: 'Times New Roman',
                        ),
                      ),
                      if (uLength < usion.length)
                        Opacity(
                          opacity: partialProgressUsion.clamp(0, 1),
                          child: Text(
                            usion[uLength],
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w500,
                              color: const Color.fromARGB(255, 33, 162, 243),
                              fontFamily: 'Times New Roman',
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _solutionAnimation,
              child: Text(
                'IoT Solutions',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content with animated text
            Center(child: buildAnimatedText()),

            // Notification status indicator
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 4, color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}
