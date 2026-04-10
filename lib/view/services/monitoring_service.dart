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
