// import 'dart:async';


// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:gf1/view/services/api_service.dart';
// import 'package:gf1/view/services/notification_services.dart';
// import 'package:rxdart/rxdart.dart'; 

// // A simple data class to hold the latest values for the UI.
// class MonitoringData {
//   final String liveCurrentValue;
//   final String aeratorsWorkingValue;
//   final String currentPerAeratorValue;

//   MonitoringData({
//     required this.liveCurrentValue,
//     required this.aeratorsWorkingValue,
//     required this.currentPerAeratorValue,
//   });
// }

// class MonitoringService {
//   // Singleton pattern to ensure only one instance of the service exists.
//   static final MonitoringService _instance = MonitoringService._internal();
//   factory MonitoringService() => _instance;
//   MonitoringService._internal();

//   final ApiService _apiService = ApiService();
//   Timer? _timer;
//   bool _isRunning = false;

//   // StreamController to broadcast monitoring data to the UI.
//   // final StreamController<MonitoringData> _dataController = StreamController.broadcast();
//    final BehaviorSubject<MonitoringData> _dataController = BehaviorSubject<MonitoringData>();
//   Stream<MonitoringData> get dataStream => _dataController.stream;

//   void start() {
//     if (_isRunning) return; // Already running
//     print("Starting MonitoringService...");
//     _isRunning = true;
//     _fetchApiData(); // Fetch immediately
//     _timer = Timer.periodic(const Duration(seconds: 15), (timer) => _fetchApiData());
//   }

//   void stop() {
//     print("Stopping MonitoringService.");
//     _timer?.cancel();
//     _isRunning = false;
//   }

//   Future<void> _fetchApiData() async {
//     try {
//       final data = await _apiService.fetchWaterQualityData();
//       // final liveCurrentInAmps = data.line1;
//       final liveCurrentInAmps = data.line2;
//       // final liveCurrentInAmps = 10.9;

//       final prefs = await SharedPreferences.getInstance();
//       final totalAerators = prefs.getInt('numberOfAerators') ?? 0;
//       double currentPerAeratorInAmps = prefs.getDouble('fixedCurrentPerAerator') ?? 0.0;

//       // Recalculate baseline if it's not set and conditions are right
//       if (currentPerAeratorInAmps == 0.0 && totalAerators > 0 && liveCurrentInAmps > 1.0) {
//         currentPerAeratorInAmps = liveCurrentInAmps / totalAerators;
//         await prefs.setDouble('fixedCurrentPerAerator', currentPerAeratorInAmps);
//         print("Monitoring Service automatically set a new baseline: $currentPerAeratorInAmps A");
//       }

//       int approximateWorking = 0;
//       if (liveCurrentInAmps < 1.0) {
//         approximateWorking = 0;
//       } else if (totalAerators > 0 && currentPerAeratorInAmps > 0) {
//         approximateWorking = (liveCurrentInAmps / currentPerAeratorInAmps).round().clamp(0, totalAerators);
//       }
      
//       final uiData = MonitoringData(
//         liveCurrentValue: "${liveCurrentInAmps.toStringAsFixed(1)} A",
//         aeratorsWorkingValue: "$approximateWorking / $totalAerators",
//         currentPerAeratorValue: "${currentPerAeratorInAmps.toStringAsFixed(1)} A",
//       );

//       _dataController.add(uiData);
//       await _checkAndSendNotifications(liveCurrentInAmps, approximateWorking, totalAerators);

//     } catch (e) {
//       print("Error in MonitoringService fetch: $e");
//     }
//   }

//   Future<void> _checkAndSendNotifications(double liveCurrentInAmps, int approximateWorking, int totalAerators) async {
//     final deviceToken = await NotificationServices.getDeviceToken();
//     if (deviceToken == null) return;
    
//     final prefs = await SharedPreferences.getInstance();
//     final notificationService = NotificationServices();

//     String? lastPowerStatus = prefs.getString('lastPowerStatus');
//     int lastNotifiedWorkingCount = prefs.getInt('lastNotifiedWorkingCount') ?? -1;
    
//     const POWER_ON_THRESHOLD_AMPS = 5.0;
//     String currentPowerStatus = liveCurrentInAmps >= POWER_ON_THRESHOLD_AMPS ? "on" : "off";

//     if (currentPowerStatus != lastPowerStatus) {
//       if (currentPowerStatus == "off") {
//         await notificationService.sendPushNotification(deviceToken: deviceToken, title: "Power Alert 🔌", body: "The aerators power has been turned off.");
//       } else {
//         await notificationService.sendPushNotification(deviceToken: deviceToken, title: "Power Alert 💡", body: "The aerators power is on.");
//       }
//       await prefs.setString('lastPowerStatus', currentPowerStatus);
//       if (currentPowerStatus == "off") {
//          await prefs.setInt('lastNotifiedWorkingCount', -1);
//       }
//     }

//     if (currentPowerStatus == "on" && totalAerators > 0) {
//       if (approximateWorking < totalAerators && approximateWorking != lastNotifiedWorkingCount) {
//         await notificationService.sendPushNotification(deviceToken: deviceToken, title: "Aerator Alert ⚠️", body: "$approximateWorking of $totalAerators aerators are working.");
//         await prefs.setInt('lastNotifiedWorkingCount', approximateWorking);
//       } else if (approximateWorking == totalAerators && lastNotifiedWorkingCount != totalAerators && lastNotifiedWorkingCount != -1) {
//         await notificationService.sendPushNotification(deviceToken: deviceToken, title: "System Restored ✅", body: "All $totalAerators aerators are now working correctly.");
//         await prefs.setInt('lastNotifiedWorkingCount', totalAerators);
//       }
//     }
//   }
// }

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:gf1/view/services/api_service.dart';

/// Holds latest monitoring values for UI
class MonitoringData {
  final String liveCurrentValue;
  final double rPhase;
  final double yPhase;
  final double bPhase;
  final String aeratorsWorkingValue;
  final String currentPerAeratorValue;
  final String selectedLine;

  MonitoringData({
    required this.liveCurrentValue,
    required this.rPhase,
    required this.yPhase,
    required this.bPhase,
    required this.aeratorsWorkingValue,
    required this.currentPerAeratorValue,
    required this.selectedLine,
  });
}

class MonitoringService {
  // Singleton
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  final ApiService _apiService = ApiService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _timer;
  bool _isRunning = false;

  final BehaviorSubject<MonitoringData> _dataController =
      BehaviorSubject<MonitoringData>();
  Stream<MonitoringData> get dataStream => _dataController.stream;

  /// Current user's Firestore document
  DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception("User not logged in");
    }
    return _firestore.collection('users').doc(uid);
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _fetchApiData();
    _timer =
        Timer.periodic(const Duration(seconds: 15), (_) => _fetchApiData());
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
  }

  Future<void> refreshDataForNewLineSelection() async {
    await _fetchApiData();
  }

  Future<void> _fetchApiData() async {
    try {
      final userRef = _userDoc();
      await userRef.set({}, SetOptions(merge: true));

      final snap = await userRef.get();
      final data = snap.data() ?? {};

      final String selectedLine =
          (data['selectedLine'] ?? 'line2').toString();

      // 🔹 Fetch API
      final api = await _apiService.fetchWaterQualityData();

      // 🔹 Live current (line-wise)
      final double liveCurrentInAmps =
          selectedLine == 'line1' ? api.line1 : api.line2;

      // 🔹 MIRROR live current to R / Y / B (as requested)
      final double rAmp = liveCurrentInAmps;
      final double yAmp = liveCurrentInAmps;
      final double bAmp = liveCurrentInAmps;

      // Aerator count
      final int totalAerators = selectedLine == 'line1'
          ? (data['noAeratorsLine1'] ?? 0)
          : (data['noAeratorsLine2'] ?? 0);

      double currentPerAeratorInAmps = selectedLine == 'line1'
          ? (data['perAerator_currentLine1'] ?? 0.0).toDouble()
          : (data['perAerator_currentLine2'] ?? 0.0).toDouble();

      // Auto baseline
      if (currentPerAeratorInAmps == 0.0 &&
          totalAerators > 0 &&
          liveCurrentInAmps > 1.0) {
        currentPerAeratorInAmps =
            liveCurrentInAmps / totalAerators;

        await userRef.update({
          if (selectedLine == 'line1')
            'perAerator_currentLine1': currentPerAeratorInAmps,
          if (selectedLine == 'line2')
            'perAerator_currentLine2': currentPerAeratorInAmps,
        });
      }

      // Approx working aerators
      int approximateWorking = 0;
      if (liveCurrentInAmps >= 1.0 &&
          totalAerators > 0 &&
          currentPerAeratorInAmps > 0) {
        approximateWorking =
            (liveCurrentInAmps / currentPerAeratorInAmps)
                .round()
                .clamp(0, totalAerators);
      }

      // 🔹 Push to stream
      _dataController.add(
        MonitoringData(
          liveCurrentValue:
              "${liveCurrentInAmps.toStringAsFixed(2)} A",
          rPhase: rAmp,
          yPhase: yAmp,
          bPhase: bAmp,
          aeratorsWorkingValue:
              "$approximateWorking / $totalAerators",
          currentPerAeratorValue:
              "${currentPerAeratorInAmps.toStringAsFixed(2)} A",
          selectedLine: selectedLine,
        ),
      );
    } catch (e) {
      debugPrint("Error in MonitoringService fetch: $e");

      _dataController.add(
        MonitoringData(
          liveCurrentValue: "0.0 A",
          rPhase: 0.0,
          yPhase: 0.0,
          bPhase: 0.0,
          aeratorsWorkingValue: "0 / 0",
          currentPerAeratorValue: "0.0 A",
          selectedLine: "line1",
        ),
      );
    }
  }

  /// Call on logout / app close
  void dispose() {
    _timer?.cancel();
    _dataController.close();
  }
}


  // Future<void> _checkAndSendNotifications({
  //   required DocumentReference<Map<String, dynamic>> userRef,
  //   required double liveCurrentInAmps,
  //   required int approximateWorking,
  //   required int totalAerators,
  // }) async {
  //   final deviceToken = await NotificationServices.getDeviceToken();
  //   if (deviceToken == null) return;

  //   final snap = await userRef.get();
  //   final data = snap.data() ?? {};

  //   String? lastPowerStatus = data['lastPowerStatus'] as String?;
  //   int lastNotifiedWorkingCount = (data['lastNotifiedWorkingCount'] ?? -1) as int;

  //   const double POWER_ON_THRESHOLD_AMPS = 5.0;
  //   final String currentPowerStatus =
  //       liveCurrentInAmps >= POWER_ON_THRESHOLD_AMPS ? "on" : "off";

  //   // Power on/off transition
  //   if (currentPowerStatus != lastPowerStatus) {
  //     final service = NotificationServices();
  //     if (currentPowerStatus == "off") {
  //       await service.sendPushNotification(
  //         deviceToken: deviceToken,
  //         title: "Power Alert 🔌",
  //         body: "The aerators power has been turned off.",
  //       );
  //     } else {
  //       await service.sendPushNotification(
  //         deviceToken: deviceToken,
  //         title: "Power Alert 💡",
  //         body: "The aerators power is on.",
  //       );
  //     }
  //     await userRef.update({
  //       'lastPowerStatus': currentPowerStatus,
  //       if (currentPowerStatus == "off") 'lastNotifiedWorkingCount': -1,
  //     });
  //     // If turned off we early exit; next loop will handle counts
  //     if (currentPowerStatus == "off") return;
  //   }

  //   // Aerator working / restore notifications (only when power is on)
  //   if (currentPowerStatus == "on" && totalAerators > 0) {
  //     final service = NotificationServices();

  //     if (approximateWorking < totalAerators &&
  //         approximateWorking != lastNotifiedWorkingCount) {
  //       await service.sendPushNotification(
  //         deviceToken: deviceToken,
  //         title: "Aerator Alert ⚠️",
  //         body: "$approximateWorking of $totalAerators aerators are working.",
  //       );
  //       await userRef.update({'lastNotifiedWorkingCount': approximateWorking});
  //     } else if (approximateWorking == totalAerators &&
  //         lastNotifiedWorkingCount != totalAerators &&
  //         lastNotifiedWorkingCount != -1) {
  //       await service.sendPushNotification(
  //         deviceToken: deviceToken,
  //         title: "System Restored ✅",
  //         body: "All $totalAerators aerators are now working correctly.",
  //       );
  //       await userRef.update({'lastNotifiedWorkingCount': totalAerators});
  //     }
  //   }
  // }
