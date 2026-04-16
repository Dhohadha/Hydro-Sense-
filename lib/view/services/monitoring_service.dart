import 'dart:async';
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

  Timer? _timer;
  bool _isRunning = false;

  final BehaviorSubject<MonitoringData> _dataController =
      BehaviorSubject<MonitoringData>();
  Stream<MonitoringData> get dataStream => _dataController.stream;

  // Document reference removed to avoid user dependency

  String activeLine = 'line1';

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

  Future<void> refreshDataForNewLineSelection(String newLine) async {
    activeLine = newLine;
    await _fetchApiData();
  }

  Future<void> _fetchApiData() async {
    debugPrint('🔍 MonitoringService: Fetching data for $activeLine...');
    try {
      // 🔹 Fetch API
      final api = await _apiService.fetchWaterQualityData();
      debugPrint('✅ MonitoringService: API fetch success');

      // 🔹 Live current (updated to use Line 2 as the primary "Total Current" as requested)
      final double liveCurrentInAmps = api.line2;

      // 🔹 Map ACTUAL line data to phases
      final double rAmp = api.line1; // Line 1 -> R
      final double yAmp = api.line2; // Line 2 -> Y
      final double bAmp = api.line2; // Placeholder for B

      // Dynamic defaults for aerator counts
      final int totalAerators = activeLine == 'line1' ? 12 : 11;
      double currentPerAeratorInAmps = 1.5; // Estimated baseline

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
              "$approximateWorking / $totalAerators", // Restored dynamic ratio
          currentPerAeratorValue:
              "${currentPerAeratorInAmps.toStringAsFixed(2)} A",
          selectedLine: activeLine,
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
