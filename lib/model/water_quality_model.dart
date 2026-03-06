
// --- DATA MODEL ---

class WaterQualityData {
  final String deviceId;
  final double line1;
  final double line2;
  final double temperature;
  final double turbidity;
  final double ph;
  final double dissolvedOxygen;
  final double tds;
  final DateTime timestamp;
  
factory WaterQualityData.defaults() {
  return WaterQualityData(
    deviceId: "Unknown",
    line1: 0.0,
    line2: 0.0,
    temperature: 0.0,
    turbidity: 0.0,
    ph: 7.0,                 // safe middle value
    dissolvedOxygen: 0.0,
    tds: 0.0,
    timestamp: DateTime.now(),
  );
}

  WaterQualityData({
    required this.deviceId,
    required this.line1,
    required this.line2,
    required this.temperature,
    required this.turbidity,
    required this.ph,
    required this.dissolvedOxygen,
    required this.tds,
    required this.timestamp,
  });

  // Factory constructor to create an instance from a JSON map.
  factory WaterQualityData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    // Helper to safely parse numbers that might be int or double
    double parseDouble(dynamic value) {
      if (value is int) {
        return value.toDouble();
      } else if (value is double) {
        return value;
      } else {
        return 0.0;
      }
    }
    

    return WaterQualityData(
      deviceId: data['device_id'] ?? 'Unknown',
      line1: parseDouble(data['line1']),
      line2: parseDouble(data['line2']),
      temperature: parseDouble(data['temperature']),
      turbidity: parseDouble(data['turbidity']),
      ph: parseDouble(data['ph']),
      dissolvedOxygen: parseDouble(data['do']),
      tds: parseDouble(data['tds']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp']['_seconds'] ?? 0) * 1000,
      ),
    );
  }
}
