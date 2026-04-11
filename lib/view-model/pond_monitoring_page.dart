import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:gf1/view/services/monitoring_service.dart';
import 'package:gf1/view/services/api_service.dart';
import 'package:gf1/view/utils/color_constants.dart';
// import '../utils/color_constants.dart';

class PondMonitoringPage extends StatefulWidget {
  const PondMonitoringPage({super.key});
  @override
  State<PondMonitoringPage> createState() => _PondMonitoringPageState();
}

class _PondMonitoringPageState extends State<PondMonitoringPage> {
  final TextEditingController aeratorsController = TextEditingController();
  final MonitoringService _monitoringService = MonitoringService();

  // MQTT connection for phase currents
  late MqttServerClient _mqttClient;
  double _l1 = 0.0, _l2 = 0.0, _l3 = 0.0;


  // Dropdown selection (persisted in Firestore)
  String? _selectedLine;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = _auth.currentUser?.uid;
    return _firestore.collection('users').doc(uid);
  }

  @override
  void initState() {
    super.initState();
    _monitoringService.start();
    _loadInitialFromFirestore();
    _connectMqtt();
  }

  Future<void> _connectMqtt() async {
    _mqttClient = MqttServerClient(
      'broker.emqx.io', // Broker Address
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}', // Unique Client ID
    );

    _mqttClient.port = 1883;
    _mqttClient.keepAlivePeriod = 20;
    _mqttClient.logging(on: false);

    _mqttClient.onConnected = () {
      debugPrint('✅ MQTT Connected (Pond Monitoring Page)');
      _mqttClient.subscribe('PMS/data', MqttQos.atMostOnce);
    };

    _mqttClient.onDisconnected = () {
      debugPrint('❌ MQTT Disconnected (Pond Monitoring Page)');
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
          'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
        )
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    _mqttClient.connectionMessage = connMessage;

    try {
      await _mqttClient.connect();
    } catch (e) {
      debugPrint('MQTT connection failed: $e');
      return;
    }

    _mqttClient.updates!.listen((
      List<MqttReceivedMessage<MqttMessage>> events,
    ) {
      final recMessage = events[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        recMessage.payload.message,
      );

      debugPrint('📩 MQTT Received in Pond Monitoring Page: $payload');

      try {
        final data = jsonDecode(payload);
        if (!mounted) return;
        setState(() {
          _l1 = (data['l1'] ?? _l1).toDouble();
          _l2 = (data['l2'] ?? _l2).toDouble();
          _l3 = (data['l3'] ?? _l3).toDouble();
        });
      } catch (e) {
        debugPrint('❗ Invalid MQTT JSON in Pond Monitoring Page: $e');
      }
    });
  }

  Future<void> _loadInitialFromFirestore() async {
    final snap = await _userDoc.get();
    final data = snap.data() ?? {};
    final line = (data['selectedLine'] ?? 'line2').toString();

    // Prefill the count input from the active line
    final int count = line == 'line1'
        ? (data['noAeratorsLine1'] ?? 0)
        : (data['noAeratorsLine2'] ?? 0);

    setState(() {
      _selectedLine = line;
      if (count > 0) {
        aeratorsController.text = count.toString();
      }
    });

    // Ensure doc exists
    await _userDoc.set({'selectedLine': line}, SetOptions(merge: true));
  }

  Future<void> setAeratorBaseline() async {
    FocusScope.of(context).unfocus();
    final String active = _selectedLine ?? 'line2';
    final int totalAerators = int.tryParse(aeratorsController.text.trim()) ?? 0;

    // Persist the count to Firestore
    final Map<String, dynamic> updates = {
      if (active == 'line1') 'noAeratorsLine1': totalAerators,
      if (active == 'line2') 'noAeratorsLine2': totalAerators,
    };

    // Compute baseline NOW using live current (if possible)
    double perAerator = 0.0;
    if (totalAerators > 0) {
      try {
        final api = await ApiService().fetchWaterQualityData();
        final double live = active == 'line1' ? api.line1 : api.line2;
        if (live > 1.0) {
          perAerator = live / totalAerators;
        }
      } catch (e) {
        debugPrint('Failed to compute baseline from API: $e');
      }
    }

    if (active == 'line1') {
      updates['perAerator_currentLine1'] = perAerator;
    } else {
      updates['perAerator_currentLine2'] = perAerator;
    }

    // ✅ Save to Firestore
    await _userDoc.set(updates, SetOptions(merge: true));

    // ✅ Also PATCH to external API
    try {
      final snap = await _userDoc.get();
      final data = snap.data() ?? {};
      final success = await ApiService().patchUserUpdate(
        noAeratorsLine1: data['noAeratorsLine1'] ?? 0,
        noAeratorsLine2: data['noAeratorsLine2'] ?? 0,
        perAeratorLine1: (data['perAerator_currentLine1'] ?? 0).toDouble(),
        perAeratorLine2: (data['perAerator_currentLine2'] ?? 0).toDouble(),
      );
      debugPrint(
        "The data are : ${data['noAeratorsLine1'] ?? 0}, ${data['noAeratorsLine2'] ?? 0}, ${(data['perAerator_currentLine1'] ?? 0).toDouble()}, ${(data['perAerator_currentLine2'] ?? 0).toDouble()}",
      );

      if (success) {
        debugPrint("PATCH success ✅");
      } else {
        debugPrint("PATCH failed ❌");
      }
    } catch (e) {
      debugPrint("Error during PATCH: $e");
    }

    // Refresh monitoring
    await _monitoringService.refreshDataForNewLineSelection();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aerator count updated & API patched.'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  /// Handle dropdown changes
  Future<void> _onLineSelected(String? newLine) async {
    if (newLine == null || newLine == _selectedLine) return;

    setState(() => _selectedLine = newLine);

    await _userDoc.set({'selectedLine': newLine}, SetOptions(merge: true));

    // Prefill aerators input based on newly selected line
    final snap = await _userDoc.get();
    final data = snap.data() ?? {};
    final int count = newLine == 'line1'
        ? (data['noAeratorsLine1'] ?? 0)
        : (data['noAeratorsLine2'] ?? 0);
    aeratorsController.text = count > 0 ? count.toString() : '';

    // Fetch fresh data for new line
    await _monitoringService.refreshDataForNewLineSelection();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Monitoring switched to $newLine.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    aeratorsController.dispose();
    _mqttClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: StreamBuilder<MonitoringData>(
            stream: _monitoringService.dataStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading data"));
              }

              final liveCurrent = snapshot.data?.liveCurrentValue ?? "-- A";
              final workingAerators =
                  snapshot.data?.aeratorsWorkingValue ?? "-- / --";
              final currentPerAerator =
                  snapshot.data?.currentPerAeratorValue ?? "-- A";
              final activeLine = snapshot.data?.selectedLine ?? _selectedLine;
              // Using values from local MQTT state as requested
              final r = _l1;
              final y = _l2;
              final b = _l3;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildLineSelector(activeLine),
                  const SizedBox(height: 16),

                  _InfoCard(
                    title:
                        "Live Total Current (${activeLine == 'line1' ? 'Line 1' : 'Line 2'})",
                    value: liveCurrent,
                    icon: Icons.flash_on_rounded,
                    iconColor: AppColors.accentSoft,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentSoft.withValues(alpha: 0.7),
                        AppColors.accentSoft.withValues(alpha: 0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InputCard(
                    gradient: AppColors.pastelSkyLavender,
                    title: "Total Number of Aerators",
                    controller: aeratorsController,
                    onTap: setAeratorBaseline,
                  ),
                  const SizedBox(height: 16),
                  _StatusGrid(
                    currentPerAerator: currentPerAerator,
                    aeratorsWorking: workingAerators,
                  ),
                  _PhaseSummaryCard(
                    rValue: "${r.toStringAsFixed(2)} A",
                    yValue: "${y.toStringAsFixed(2)} A",
                    bValue: "${b.toStringAsFixed(2)} A",
                  ),

                  // I edited this code
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Dropdown builder
  Widget _buildLineSelector(String? activeLine) {
    if (activeLine == null) {
      return const SizedBox(height: 50);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 230, 227, 227),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentSoft.withValues(alpha: 0.6),
            ),
            child: const Icon(
              Icons.electrical_services_rounded,
              color: AppColors.cardBackground,
              size: 22,
            ),
          ),

          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Monitor Current From',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.subtextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<String>(
            value: activeLine,
            onChanged: _onLineSelected,
            icon: Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.accentSoft.withValues(alpha: 0.6),
            ),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 'line1',
                child: Text(
                  'Line 1',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DropdownMenuItem(
                value: 'line2',
                child: Text(
                  'Line 2',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pond Monitoring System',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Real-time Aerator Status',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.subtextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PhaseSummaryCard extends StatelessWidget {
  final String rValue;
  final String yValue;
  final String bValue;

  const _PhaseSummaryCard({
    required this.rValue,
    required this.yValue,
    required this.bValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.accentSoft.withValues(alpha: 0.6),
            AppColors.accentSoft.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _phaseItem("R", rValue),
          _phaseItem("Y", yValue),
          _phaseItem("B", bValue),
        ],
      ),
    );
  }

  Widget _phaseItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.subtextColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// --- Your Custom UI Widgets (Unchanged) ---

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Gradient gradient;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.gradient = AppColors.titleGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 230, 227, 227),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ========= CIRCLE ICON (Updated) =========
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(icon, size: 26, color: iconColor),
          ),

          // =========================================
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.subtextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  color: AppColors.titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final VoidCallback onTap;
  final Gradient gradient;

  const _InputCard({
    required this.title,
    required this.controller,
    required this.onTap,
    this.gradient = AppColors.titleGradient,
  });

  @override
  State<_InputCard> createState() => _InputCardState();
}

class _InputCardState extends State<_InputCard> {
  bool _isLocked = true; // default: locked

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 230, 227, 227),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.subtextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: widget.controller,

                  readOnly: _isLocked, // 🔒 control lock/unlock
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 22,
                    color: AppColors.titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      gapPadding: 3,
                      borderSide: const BorderSide(style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(9),
                    hintText: 'e.g., 10',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isLocked ? Icons.lock : Icons.lock_open,
                        color: _isLocked ? Colors.black : AppColors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isLocked = !_isLocked;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _GradientButton(text: "Fix", onTap: widget.onTap),
        ],
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  final String currentPerAerator;
  final String aeratorsWorking;

  const _StatusGrid({
    required this.currentPerAerator,
    required this.aeratorsWorking,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusCard(
            title: "Fixed Current",
            subtitle: "per Aerator",
            value: currentPerAerator,
            gradient: LinearGradient(
              colors: [
                AppColors.card,
                AppColors.accentSoft.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.settings_input_component_rounded,
            iconColor: AppColors.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatusCard(
            title: "Aerators",
            subtitle: "Working",
            value: aeratorsWorking,
            icon: Icons.power_rounded,
            gradient: LinearGradient(
              colors: [
                AppColors.card,
                AppColors.accentSoft.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            iconColor: AppColors.primaryColor,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final Color iconColor;

  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    this.gradient = AppColors.softGreenTeal,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 230, 227, 227),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.subtextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.subtextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // =========  CIRCLE ICON (Updated) =========
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),

              // ==========================================
            ],
          ),

          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              color: AppColors.titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _GradientButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentSoft.withValues(alpha: 0.7),
              AppColors.accentSoft.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
