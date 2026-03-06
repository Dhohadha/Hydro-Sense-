import 'package:flutter/material.dart';
import 'package:gf1/view/utils/color_constants.dart';


class ParameterCard extends StatefulWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Gradient gradient;

  const ParameterCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.gradient,
  });

  @override
  State<ParameterCard> createState() => _ParameterCardState();
}

class _ParameterCardState extends State<ParameterCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  // Helper function to determine the indicator color based on the value.
  // These are example thresholds and should be adjusted to your specific needs.
  Color _getIndicatorColor(String title, double value) {
    switch (title) {
      case 'pH Level':
        if (value >= 6.5 && value <= 8.5) return AppColors.green;
        if (value >= 6.0 && value <= 9.0) return Colors.orangeAccent;
        return AppColors.red;
      case 'Temperature':
        if (value >= 20 && value <= 30) return AppColors.green;
        if (value >= 15 && value <= 35) return Colors.orangeAccent;
        return AppColors.red;
      case 'TDS':
        if (value < 500) return AppColors.green;
        if (value < 1000) return Colors.orangeAccent;
        return AppColors.red;
      default:
        // Return a transparent color if no specific logic applies
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double numericValue = double.tryParse(widget.value) ?? 0.0;
    final statusColor = _getIndicatorColor(widget.title, numericValue);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              // A subtle shadow that changes color based on the value's status
              BoxShadow(
                color: statusColor.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
              // A standard darker shadow for depth
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with a styled background
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 28, color: AppColors.white),
                ),

                // This Expanded widget takes up all available vertical space,
                // pushing the content below it to the bottom of the card.
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Ensures the column only takes needed space
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // FittedBox prevents horizontal overflow by scaling the text down
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                widget.value,
                                style: const TextStyle(
                                  fontSize: 20, // Adjusted for better fit
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  widget.unit,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
