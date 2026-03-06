import 'package:flutter/material.dart';
import '../view/utils/color_constants.dart';

class CapacitorPage extends StatefulWidget {
  const CapacitorPage({super.key});

  @override
  State<CapacitorPage> createState() => _CapacitorPageState();
}

class _CapacitorPageState extends State<CapacitorPage> {
  final List<Map<String, dynamic>> capacitors = [
    {"name": "Capacitor 1", "status": "Active"},
    {"name": "Capacitor 2", "status": "Inactive"},
    {"name": "Capacitor 3", "status": "Active"},
    {"name": "Capacitor 4", "status": "Inactive"},
    {"name": "Capacitor 5", "status": "Active"},
    {"name": "Capacitor 6", "status": "Active"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header is now part of the main column
            _buildHeader(),
            // The ListView MUST be wrapped in an Expanded widget to avoid render errors
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: capacitors.length,
                itemBuilder: (context, index) {
                  final capacitor = capacitors[index];
                  return FadeInAnimation(
                    delay: index * 0.1,
                    child: CapacitorCard(
                      name: capacitor['name'],
                      status: capacitor['status'],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A custom header widget built directly into the page
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capacitor Status',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color:  Color.fromARGB(255, 0, 0, 0),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check Your Capacitors Status ',
            style: TextStyle(
                fontSize: 16,
                color: AppColors.subtextColor,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class CapacitorCard extends StatelessWidget {
  final String name;
  final String status;

  const CapacitorCard({super.key, required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isActive = status == "Active";
    final Color statusColor =
        isActive ? AppColors.activeGreen : AppColors.inactiveRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
 boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          )
                        ],
        border: Border(
          left: BorderSide(color: statusColor, width: 5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bolt,
            color: statusColor,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A simple reusable animation widget
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final double delay;

  const FadeInAnimation({super.key, required this.child, this.delay = 0.0});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
