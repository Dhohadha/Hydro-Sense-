import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gf1/view/services/monitoring_service.dart';
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

  @override
  void initState() {
    super.initState();
    _monitoringService.start();
    _loadInitialFromFirestore();
  }

  Future<void> _loadInitialFromFirestore() async {
    // Bypassing Firestore initialization
    const int count = 11; // Hardcoded to 11 total aerators

    if (!mounted) return;
    setState(() {
      aeratorsController.text = count.toString();
    });
  }

  Future<void> setAeratorBaseline() async {
    FocusScope.of(context).unfocus();
    
    // Using local calculation, so we just rebuild
    setState(() {});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Total aerators updated!'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  @override
  void dispose() {
    aeratorsController.dispose();
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

              final currentPerAerator =
                  snapshot.data?.currentPerAeratorValue ?? "1.50 A";
              
              // Using values from the monitoring stream (API) to ensure live data is shown
              final r = snapshot.data?.rPhase ?? 0.0;
              final y = snapshot.data?.yPhase ?? 0.0;
              
              // Calculate Working Aerators locally
              final double currentPerAeratorInAmps = 1.5;
              final double totalLiveCurrent = snapshot.data?.yPhase ?? 0.0; // Line 2 as Total Current
              final int totalAerators = int.tryParse(aeratorsController.text) ?? 11;
              
              int approximateWorking = 0;
              if (totalLiveCurrent >= 1.0 && totalAerators > 0) {
                 approximateWorking = (totalLiveCurrent / currentPerAeratorInAmps).round().clamp(0, totalAerators);
              }

              final liveCurrent = "${totalLiveCurrent.toStringAsFixed(2)} A";
              final workingAerators = "$approximateWorking / $totalAerators";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),

                  _InfoCard(
                    title: "Live Total Current",
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
                    bValue: "--", // Fixed to "--" as requested
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

  // Removed dropdown builder
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

                  readOnly: false, // User can now edit this
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
                    hintText: 'e.g., 11',
                    suffixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.edit,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _GradientButton(text: "Apply", onTap: widget.onTap),
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
