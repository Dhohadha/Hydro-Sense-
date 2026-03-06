import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gf1/model/water_quality_model.dart';
import 'package:gf1/view/services/api_service.dart';
import 'package:gf1/view/utils/color_constants.dart';
import 'package:gf1/view/widgets/shimmer.dart';
import 'package:intl/intl.dart';

class ParametersPage extends StatefulWidget {
  const ParametersPage({super.key});

  @override
  State<ParametersPage> createState() => _ParametersPageState();
}

class _ParametersPageState extends State<ParametersPage> {
  final ApiService _apiService = ApiService();
  late StreamController<WaterQualityData> _dataStreamController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _dataStreamController = StreamController<WaterQualityData>.broadcast();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dataStreamController.close();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _apiService.fetchWaterQualityData();
      if (!_dataStreamController.isClosed) {
        _dataStreamController.sink.add(data);
      }
    } catch (e) {
      if (!_dataStreamController.isClosed) {
        _dataStreamController.sink.addError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchData,
                color: AppColors.primaryColor,
                child: StreamBuilder<WaterQualityData>(
                  stream: _dataStreamController.stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return _buildDataLoadedState(null, isLoading: true);
                    }
                    if (snapshot.hasError && !snapshot.hasData) {
                      return _buildErrorState();  
                    }
                    if (snapshot.hasData) {
                      return _buildDataLoadedState(snapshot.data!, isLoading: false);
                    }
                    return _buildDataLoadedState(null, isLoading: true);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Parameters',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 0, 0, 0),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryColor, size: 28),
            onPressed: _fetchData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
    );
  }

  // ERROR STATE
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.disconnectedColor, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Connection Failed',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.titleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please activate the device or check your internet connection.',
              style: TextStyle(fontSize: 16, color: AppColors.subtextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  // DATA
  Widget _buildDataLoadedState(WaterQualityData? data, {required bool isLoading}) {
    final parameterData = [
      {'title': 'pH Level', 'value': data?.ph.toStringAsFixed(2), 'unit': '', 'icon': Icons.science_outlined, 'gradient': const LinearGradient(colors: [Color(0xFF6A82FB), Color(0xFFFC5C7D)])},
      {'title': 'Dissolved Oxygen', 'value': data?.dissolvedOxygen.toStringAsFixed(2), 'unit': 'mg/L', 'icon': Icons.air, 'gradient': const LinearGradient(colors: [Color(0xFF2AF598), Color(0xFF009EFD)])},
      {'title': 'Turbidity', 'value': data?.turbidity.toStringAsFixed(2), 'unit': 'NTU', 'icon': Icons.visibility_off_outlined, 'gradient': const LinearGradient(colors: [Color(0xFFF83600), Color(0xFFFE8C00)])},
      {'title': 'Temperature', 'value': data?.temperature.toStringAsFixed(2), 'unit': '°C', 'icon': Icons.thermostat_outlined, 'gradient': const LinearGradient(colors: [Color(0xFFFE6B8B), Color(0xFFFF8E53)])},
      {'title': 'TDS', 'value': data?.tds.toStringAsFixed(2), 'unit': 'ppm', 'icon': Icons.grain_outlined, 'gradient': const LinearGradient(colors: [Color(0xFF0BA360), Color(0xFF3CBA92)])},
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        _buildStatusHeader(data, false),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1, // ✅ Slightly taller to avoid overflow
          ),
          itemCount: parameterData.length,
          itemBuilder: (context, index) {
            if (isLoading) {
              return const ShimmerLoading();
            }
            return _ParameterCard(
              title: parameterData[index]['title'] as String,
              value: (parameterData[index]['value'] as String?) ?? "--",
              unit: parameterData[index]['unit'] as String,
              icon: parameterData[index]['icon'] as IconData,
              gradient: parameterData[index]['gradient'] as Gradient,
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // STATUS HEADER
  Widget _buildStatusHeader(WaterQualityData? data, bool hasError) {
    final isConnected = data != null && !hasError;
    final statusText = isConnected ? 'Connected' : 'Disconnected';
    final statusColor = isConnected ? AppColors.connectedColor : AppColors.disconnectedColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.borderColor, AppColors.accentColor.withValues(alpha: 0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(4, 6)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(-4, -4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.device_hub, size: 26, color: AppColors.titleColor),
              const SizedBox(width: 8),
              const Text(
                'Device Status: ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.titleColor),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1, offset: const Offset(2, 4)),
                  ],
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isConnected)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, size: 18, color: AppColors.subtextColor),
                const SizedBox(width: 6),
                Text(
                  'Last updated: ${DateFormat('MMM d, yyyy hh:mm:ss a').format(data.timestamp)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.subtextColor),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ✅ FIXED ParameterCard
class _ParameterCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Gradient gradient;

  const _ParameterCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(2, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                maxLines: 2, // ✅ wrap long titles
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown, // ✅ Prevent overflow for large numbers
              child: Text(
                "$value $unit",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
