// import 'dart:math' as math;
// import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
// import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
// import 'package:flutter/material.dart';
// import 'package:gf1/view-model/account_screen.dart';
// import 'package:gf1/view/screens/notifications_screen.dart';
// import 'package:gf1/view/widgets/notification_badge.dart';
// // import 'parameters.dart';
// import 'pond_monitoring_page.dart';
// import 'capacitors.dart';
// import '../view/utils/color_constants.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';


// class PondApp extends StatelessWidget {
//   const PondApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         scaffoldBackgroundColor: AppColors.background,
//         fontFamily: 'Poppins',
//       ),
//       home: const MainNavigationPage(),
//     );
//   }
// }

// class MainNavigationPage extends StatefulWidget {
//   const MainNavigationPage({super.key});

//   @override
//   State<MainNavigationPage> createState() => _MainNavigationPageState();
// }

// class _MainNavigationPageState extends State<MainNavigationPage> {
//   int _currentIndex = 0;
//   final GlobalKey<CurvedNavigationBarState> _bottomKey = GlobalKey();

//   late final List<Widget> _pages;

//   @override
//   void initState() {
//     super.initState();
//     _pages = [
//       HomePage(),
//       // ParametersPage(),
//       PondMonitoringPage(),
//       CapacitorPage(),
//       AccountScreen(),
//     ];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: false,
//       body: _pages[_currentIndex],
//       bottomNavigationBar: CurvedNavigationBar(
//         key: _bottomKey,
//         index: _currentIndex,
//         height: 60,
//         backgroundColor: AppColors.background,
//         color: AppColors.inactiveRedLight,
//         buttonBackgroundColor: const Color.fromARGB(60, 0, 198, 168),
//         animationDuration: const Duration(milliseconds: 400),
//         items: const [
//           CurvedNavigationBarItem(
//               child: FaIcon(FontAwesomeIcons.fan),
//  label: 'Aeriator'),
//           // CurvedNavigationBarItem(
//           //     child: Icon(Icons.analytics), label: 'PMS'),
//           CurvedNavigationBarItem(
//               child: Icon(Icons.notifications), label: 'Alerts'),
//           CurvedNavigationBarItem(
//               child: Icon(Icons.bolt), label: 'Capacitors'),
//           CurvedNavigationBarItem(
//               child: Icon(Icons.person), label: 'Account'),
//         ],
//         onTap: (i) => setState(() => _currentIndex = i),
//       ),
//     );
//   }
// }

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   bool line1Status = false;
//   bool line2Status = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//         SliverAppBar(
//   pinned: true,
//   elevation: 8,
//   backgroundColor: Colors.white, // 🔥 Highlight background
//   shadowColor: Colors.black.withValues(alpha: 0.25),
//   titleSpacing: 20,

//   title: const Text(
//     'Aeriator Control',
//     style: TextStyle(
//       fontWeight: FontWeight.w900,
//       fontSize: 27,
//       color: Colors.black,
//     ),
//   ),

//   actions: [
//     NotificationBadge(
//       size: 14,
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => const NotificationsScreen(),
//           ),
//         );
//       },
//       child: const Icon(
//         Icons.notifications,
//         color: Colors.black, // visible on white
//       ),
//     ),
//     const SizedBox(width: 16),
//   ],

//   // 🔥 Bottom highlight line
//   bottom: PreferredSize(
//     preferredSize: const Size.fromHeight(1),
//     child: Container(
//       height: 1,
//       color: AppColors.accent.withValues(alpha: 0.4),
//     ),
//   ),
// ),


//           SliverToBoxAdapter(
//   child: Container(
//     color: AppColors.background, // 👈 CHANGE THIS to any color you want
//     padding: const EdgeInsets.all(16),
//     child: _buildSecondUISection(),
//   ),
// ),


//         ],
//       ),
//     );
//   }

  
//   Widget _buildSecondUISection() {
//     return Column(
//       children: [
//         // Line 1 aerator card
//         AeratorControlCard(
//           title: "Line 1 Aerators",
//           status: line1Status,
//           onToggle: () {
//             setState(() {
//               line1Status = !line1Status;
//             });
//           },
//         ),

//         const SizedBox(height: 20),

//         // Line 2 aerator card
//         AeratorControlCard(
//           title: "Line 2 Aerators",
//           status: line2Status,
//           onToggle: () {
//             setState(() {
//               line2Status = !line2Status;
//             });
//           },
//         ),

//         const SizedBox(height: 20),

//         // Master Control
//         ElevatedButton.icon(
//           onPressed: () {
//             setState(() {
//               bool newState = !(line1Status || line2Status);
//               line1Status = newState;
//               line2Status = newState;
//             });
//           },
//           icon: const Icon(Icons.power_settings_new),
//           label: const Text("Master Control"),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.blue.shade700,
//             foregroundColor: Colors.white,
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // ---------------- BUTTON ----------------

//   Widget _primaryButton(String label) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             AppColors.accent,
//             AppColors.primary,
//           ],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(22),
//         boxShadow: const [
//           BoxShadow(
//             color: Colors.black26,
//             blurRadius: 6,
//             offset: Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 15,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     );
//   }
// }

// // ================== ANIMATION WIDGETS (unchanged UI) ==================

// class AeratorControlCard extends StatelessWidget {
//   final String title;
//   final bool status;
//   final VoidCallback onToggle;

//   const AeratorControlCard({
//     super.key,
//     required this.title,
//     required this.status,
//     required this.onToggle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 6,
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(16),
//           gradient: status
//               ? LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [
//                     Colors.green.shade50,
//                     Colors.green.shade100,
//                   ],
//                 )
//               : null,
//         ),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
//           child: Column(
//             children: [
//               // Title section
//               Container(
//                 width: double.infinity,
//                 padding:
//                     const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
//                 decoration: BoxDecoration(
//                   color: status
//                       ? Colors.green.shade100
//                       : Colors.grey.shade100,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: status
//                         ? Colors.green.shade300
//                         : Colors.grey.shade300,
//                   ),
//                 ),
//                 child: Column(
//                   children: [
//                     Text(
//                       title,
//                       style: TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.bold,
//                         color: status
//                             ? Colors.green.shade800
//                             : Colors.grey.shade800,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 0),
//                     Text(
//                       status ? "OPERATIONAL" : "STANDBY",
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                         color: status
//                             ? Colors.green.shade600
//                             : Colors.grey.shade600,
//                         letterSpacing: 1.0,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 0),

//               SizedBox(
//                 height: 120,
//                 child: AeratorAnimation(isOn: status),
//               ),

//               const SizedBox(height: 50),

//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         status ? "Status: RUNNING" : "Status: STOPPED",
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: status ? Color.fromARGB(255, 74, 131, 205): Colors.red,//   Colors.AppColors.accentSoft.withValues(alpha: 0.6),
 
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         status
//                             ? "Oxygen levels optimal"
//                             : "System offline",
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey.shade600,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Switch(
//                     value: status,
//                     onChanged: (val) => onToggle(),
//                     activeColor: Colors.green,
//                     activeTrackColor: Colors.green.shade200,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class AeratorAnimation extends StatefulWidget {
//   final bool isOn;

//   const AeratorAnimation({super.key, required this.isOn});

//   @override
//   State<AeratorAnimation> createState() => _AeratorAnimationState();
// }

// class _AeratorAnimationState extends State<AeratorAnimation>
//     with TickerProviderStateMixin {
//   late AnimationController _rotationController;
//   late AnimationController _splashController;
//   late AnimationController _bubbleController;

//   final List<Bubble> _bubbles = [];
//   final List<WaterSplash> _splashes = [];

//   @override
//   void initState() {
//     super.initState();

//     // Main rotation animation
//     _rotationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );

//     // Splash animation
//     _splashController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     );

//     // Bubble animation
//     _bubbleController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 3),
//     );

//     _initializeEffects();
//   }

//   void _initializeEffects() {
//     // Initialize bubbles
//     _bubbles.clear();
//     for (int i = 0; i < 15; i++) {
//       _bubbles.add(Bubble());
//     }

//     // Initialize water splashes
//     _splashes.clear();
//     for (int i = 0; i < 8; i++) {
//       _splashes.add(WaterSplash());
//     }
//   }

//   @override
//   void didUpdateWidget(covariant AeratorAnimation oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.isOn) {
//       _rotationController.repeat();
//       _splashController.repeat();
//       _bubbleController.repeat();
//     } else {
//       _rotationController.stop();
//       _splashController.stop();
//       _bubbleController.stop();
//     }
//   }

//   @override
//   void dispose() {
//     _rotationController.dispose();
//     _splashController.dispose();
//     _bubbleController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       painter: RealisticAeratorPainter(
//         _rotationController,
//         _splashController,
//         _bubbleController,
//         widget.isOn,
//         _bubbles,
//         _splashes,
//       ),
//       child: Container(),
//     );
//   }
// }

// class Bubble {
//   late double x;
//   late double y;
//   late double radius;
//   late double speed;
//   late double opacity;
//   late double phase;

//   Bubble() {
//     reset();
//   }

//   void reset() {
//     x = (math.Random().nextDouble() - 0.5) * 100;
//     y = 40 + math.Random().nextDouble() * 20;
//     radius = 2 + math.Random().nextDouble() * 4;
//     speed = 0.5 + math.Random().nextDouble() * 1.5;
//     opacity = 0.3 + math.Random().nextDouble() * 0.4;
//     phase = math.Random().nextDouble() * 2 * math.pi;
//   }

//   void update(double animationValue) {
//     y -= speed;
//     x += math.sin(phase + animationValue * 4) * 0.5;
//     opacity -= 0.008;

//     if (y < -50 || opacity <= 0) {
//       reset();
//     }
//   }
// }

// class WaterSplash {
//   late double angle;
//   late double radius;
//   late double maxRadius;
//   late double opacity;
//   late double speed;

//   WaterSplash() {
//     reset();
//   }

//   void reset() {
//     angle = math.Random().nextDouble() * 2 * math.pi;
//     radius = 30 + math.Random().nextDouble() * 20;
//     maxRadius = radius + 20 + math.Random().nextDouble() * 30;
//     opacity = 0.6 + math.Random().nextDouble() * 0.4;
//     speed = 0.8 + math.Random().nextDouble() * 1.2;
//   }

//   void update() {
//     radius += speed;
//     opacity -= 0.015;

//     if (radius > maxRadius || opacity <= 0) {
//       reset();
//     }
//   }
// }

// class RealisticAeratorPainter extends CustomPainter {
//   final Animation<double> rotationAnimation;
//   final Animation<double> splashAnimation;
//   final Animation<double> bubbleAnimation;
//   final bool isOn;
//   final List<Bubble> bubbles;
//   final List<WaterSplash> splashes;

//   RealisticAeratorPainter(
//     this.rotationAnimation,
//     this.splashAnimation,
//     this.bubbleAnimation,
//     this.isOn,
//     this.bubbles,
//     this.splashes,
//   ) : super(
//           repaint: Listenable.merge(
//             [rotationAnimation, splashAnimation, bubbleAnimation],
//           ),
//         );

//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2 + 10);

//     // Draw water surface
//     _drawWaterSurface(canvas, size, center);

//     if (isOn) {
//       // Draw water splashes
//       _drawWaterSplashes(canvas, center);

//       // Draw bubbles
//       _drawBubbles(canvas, center);
//     }

//     // Draw aerator device
//     _drawAeratorDevice(canvas, center);

//     // Draw rotating paddles/impeller
//     _drawRotatingImpeller(canvas, center);
//   }

//   void _drawWaterSurface(Canvas canvas, Size size, Offset center) {
//     final waterPaint = Paint()
//       ..color = const Color.fromARGB(255, 13, 136, 237).withValues(alpha: 0.3)
//       ..style = PaintingStyle.fill;

//     final path = Path();
//     path.moveTo(0, center.dy + 30);

//     for (double x = 0; x <= size.width; x += 5) {
//       double wave = math.sin((x / 20) + (rotationAnimation.value * 8)) * 2;
//       if (isOn) {
//         wave += math.sin((x / 10) + (splashAnimation.value * 12)) * 1.5;
//       }
//       path.lineTo(x, center.dy + 30 + wave);
//     }

//     path.lineTo(size.width, size.height);
//     path.lineTo(0, size.height);
//     path.close();

//     canvas.drawPath(path, waterPaint);
//   }

//   void _drawWaterSplashes(Canvas canvas, Offset center) {
//     for (var splash in splashes) {
//       splash.update();

//       final splashPaint = Paint()
//         ..color = Colors.blue.shade300.withValues(alpha: splash.opacity * 0.6)
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2 + (splash.opacity * 10);

//       final splashX = center.dx + math.cos(splash.angle) * splash.radius;
//       final splashY = center.dy + math.sin(splash.angle) * splash.radius * 0.3;

//       canvas.drawArc(
//         Rect.fromCircle(center: Offset(splashX, splashY), radius: 8),
//         splash.angle - 0.3,
//         0.6,
//         false,
//         splashPaint,
//       );

//       if (splash.opacity > 0.3) {
//         final dropletPaint = Paint()
//           ..color = Colors.blue.shade400.withValues(alpha: splash.opacity)
//           ..style = PaintingStyle.fill;

//         canvas.drawCircle(
//           Offset(splashX, splashY - 5),
//           1.5,
//           dropletPaint,
//         );
//       }
//     }
//   }

//   void _drawBubbles(Canvas canvas, Offset center) {
//     for (var bubble in bubbles) {
//       bubble.update(bubbleAnimation.value);

//       if (bubble.opacity > 0) {
//         final bubblePaint = Paint()
//           ..color = Colors.white.withValues(alpha: bubble.opacity)
//           ..style = PaintingStyle.fill;

//         final bubbleStroke = Paint()
//           ..color = Colors.blue.shade200.withValues(alpha: bubble.opacity * 0.5)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 0.5;

//         final bubbleCenter = Offset(
//           center.dx + bubble.x,
//           center.dy + bubble.y,
//         );

//         canvas.drawCircle(bubbleCenter, bubble.radius, bubblePaint);
//         canvas.drawCircle(bubbleCenter, bubble.radius, bubbleStroke);

//         final highlightPaint = Paint()
//           ..color = Colors.white.withValues(alpha: bubble.opacity * 0.8)
//           ..style = PaintingStyle.fill;

//         canvas.drawCircle(
//           Offset(
//             bubbleCenter.dx - bubble.radius * 0.3,
//             bubbleCenter.dy - bubble.radius * 0.3,
//           ),
//           bubble.radius * 0.3,
//           highlightPaint,
//         );
//       }
//     }
//   }

//   void _drawAeratorDevice(Canvas canvas, Offset center) {
//     final housingPaint = Paint()..style = PaintingStyle.fill;

//     housingPaint.color = Colors.grey.shade700;
//     final housingRect =
//         Rect.fromCenter(center: center, width: 120, height: 45);
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(housingRect, const Radius.circular(8)),
//       housingPaint,
//     );

//     housingPaint.color = Colors.grey.shade500;
//     final highlightRect = Rect.fromCenter(
//       center: Offset(center.dx, center.dy - 8),
//       width: 110,
//       height: 12,
//     );
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(highlightRect, const Radius.circular(4)),
//       housingPaint,
//     );

//     final boltPaint = Paint()
//       ..color = Colors.grey.shade800
//       ..style = PaintingStyle.fill;

//     canvas.drawCircle(Offset(center.dx - 45, center.dy), 4, boltPaint);
//     canvas.drawCircle(Offset(center.dx + 45, center.dy), 4, boltPaint);
//   }

//  void _drawRotatingImpeller(Canvas canvas, Offset center) {
//     final double angle = rotationAnimation.value * 2 * math.pi;
//     const int numBlades = 6;  // Changed to 6 blades
//     const double bladeRadius = 40;
//     const double bladeLength = 40;
//     const double bladeWidth = 20;

//     // Draw the central hub (larger for aerator style)
//     final hubPaint = Paint()
//       ..color = Colors.grey.shade700
//       ..style = PaintingStyle.fill;
//     canvas.drawCircle(center, 15, hubPaint);

//     // Draw the blades
//     for (int i = 0; i < numBlades; i++) {
//       double bladeAngle = angle + (i * 2 * math.pi / numBlades);  // Even spacing with 6 blades

//       canvas.save();
//       canvas.translate(center.dx, center.dy);
//       canvas.rotate(bladeAngle);
      
//       // ⭐ ADD EXTRA ROTATION TO CHANGE BLADE FACING (45 degrees)
//       canvas.rotate(math.pi / 10);  // This rotates each blade 45 degrees!

//       // Main blade paint (yellow/orange like in the photo)
//       final bladePaint = Paint()
//         ..color = isOn ? Colors.orange.shade600 : Colors.orange.shade700
//         ..style = PaintingStyle.fill;

//       // Blade outline
//       final outlinePaint = Paint()
//         ..color = Colors.orange.shade800
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 1.5;

//       // Draw rectangular paddle blade
//       final bladeRect = RRect.fromRectAndRadius(
//         Rect.fromLTWH(
//           15,  // Start from hub edge - maintains distance from center
//           -bladeWidth / 2,
//           bladeLength,
//           bladeWidth,
//         ),
//         const Radius.circular(2),
//       );

//       canvas.drawRRect(bladeRect, bladePaint);
//       canvas.drawRRect(bladeRect, outlinePaint);

//       // Add perforations/holes pattern like in the photo
//       final holePaint = Paint()
//         ..color = Colors.black.withValues(alpha: 0.3)
//         ..style = PaintingStyle.fill;

//       // Draw grid of small holes
//       for (double x = 20; x < 15 + bladeLength - 5; x += 6) {
//         for (double y = -bladeWidth / 2 + 4; y < bladeWidth / 2 - 2; y += 6) {
//           canvas.drawCircle(Offset(x, y), 1.5, holePaint);
//         }
//       }

//       // Add supporting struts (the cross-bracing visible in photo)
//       final strutPaint = Paint()
//         ..color = Colors.orange.shade800
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2;

//       // Diagonal strut from hub to blade
//       canvas.drawLine(
//         Offset(12, -2),
//         Offset(20, -bladeWidth / 2 + 2),
//         strutPaint,
//       );
      
//       canvas.drawLine(
//         Offset(12, 2),
//         Offset(20, bladeWidth / 2 - 2),
//         strutPaint,
//       );

//       // Add 3D depth effect
//       if (isOn) {
//         // Shadow on bottom edge
//         final shadowPaint = Paint()
//           ..color = Colors.black.withValues(alpha: 0.25)
//           ..style = PaintingStyle.fill;

//         final shadowRect = Rect.fromLTWH(
//           15,
//           bladeWidth / 2 - 2,
//           bladeLength,
//           2,
//         );
//         canvas.drawRect(shadowRect, shadowPaint);

//         // Highlight on top edge
//         final highlightPaint = Paint()
//           ..color = Colors.orange.shade400.withValues(alpha: 0.6)
//           ..style = PaintingStyle.fill;

//         final highlightRect = Rect.fromLTWH(
//           15,
//           -bladeWidth / 2,
//           bladeLength,
//           2,
//         );
//         canvas.drawRect(highlightRect, highlightPaint);
//       }

//       canvas.restore();

//       // Motion blur effect when spinning
//       if (isOn) {
//         final blurPaint = Paint()
//           ..color = Colors.orange.shade400.withValues(alpha: 0.15)
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = bladeWidth;

//         canvas.drawArc(
//           Rect.fromCircle(center: center, radius: bladeRadius),
//           bladeAngle - 0.15,
//           0.3,
//           false,
//           blurPaint,
//         );
//       }
//     }

//     // Draw outer ring support (visible in photo)
    
    

//     // Center bolt detail
//     final centerBoltPaint = Paint()
//       ..color = Colors.grey.shade800
//       ..style = PaintingStyle.fill;
//     canvas.drawCircle(center, 8, centerBoltPaint);
    
//     // Bolt shine
//     final boltHighlight = Paint()
//       ..color = Colors.grey.shade500
//       ..style = PaintingStyle.fill;
//     canvas.drawCircle(center.translate(-2, -2), 3, boltHighlight);
//   }
//   @override
//   bool shouldRepaint(covariant RealisticAeratorPainter oldDelegate) => true;
// }



