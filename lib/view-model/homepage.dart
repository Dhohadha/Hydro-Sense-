import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'package:flutter/material.dart';
import 'package:gf1/view-model/account_screen.dart';

import 'package:gf1/view/screens/notifications_screen.dart';
import 'package:gf1/view/services/device_service.dart';
import 'package:gf1/view/services/mqtt_service.dart';
import 'package:gf1/view/widgets/notification_badge.dart';
import 'pond_monitoring_page.dart';
import 'capacitors.dart';
import '../view/utils/color_constants.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class PondApp extends StatelessWidget {
  const PondApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Poppins',
      ),
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(),
      PondMonitoringPage(),
      CapacitorPage(),
      AccountScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _pages[_currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomKey,
        index: _currentIndex,
        height: 60,
        backgroundColor: AppColors.background,
        color: AppColors.inactiveRedLight,
        buttonBackgroundColor: const Color.fromARGB(60, 0, 198, 168),
        animationDuration: const Duration(milliseconds: 400),
        items: const [
          CurvedNavigationBarItem(
              child: FaIcon(FontAwesomeIcons.fan), label: 'Aeriator'),
          CurvedNavigationBarItem(
              child: Icon(Icons.notifications), label: 'Alerts'),
          CurvedNavigationBarItem(
              child: Icon(Icons.bolt), label: 'Capacitors'),
          CurvedNavigationBarItem(
              child: Icon(Icons.person), label: 'Account'),
        ],
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
enum CommandStatus {
  idle,
  initializing,
  networkError,
}


class _HomePageState extends State<HomePage> {
  bool line1Status = false;
  bool line2Status = false;
  bool line1Loading = false;
  bool line2Loading = false;
Timer? _statusAutoHideTimer;

    CommandStatus _commandStatus = CommandStatus.idle;

String? _statusMessage;

Timer? _commandTimeout;
static const Duration aeratorResponseTimeout =
    Duration(seconds: 100);

bool prevLine1Status = false;
bool prevLine2Status = false;

  String? lastCommandedDeviceId;

late MqttService _mqttService;


// DEVICE CONFIRMATION (used later)
bool line1Confirmed = false;
bool line2Confirmed = false;

// TEMP device id (STEP 2 will improve this)
String? deviceId;
bool deviceReady = false;

@override
void initState() {
  super.initState();

  _mqttService = MqttService();
  _mqttService.onDataReceived = _handleMqttData;
 _restoreLastKnownState();
  _loadDeviceId().then((_) {
    if (deviceReady) {
      _mqttService.connect();
    }
  });
}
Future<void> _restoreLastKnownState() async {
  final (l1, l2) = await DeviceService.loadLastDeviceState();

  setState(() {
    line1Confirmed = l1;
    line2Confirmed = l2;

    line1Status = l1;
    line2Status = l2;
  });

  debugPrint('🔄 Restored last device state');
}
void _autoHideStatusPill() {
  _statusAutoHideTimer?.cancel();

  _statusAutoHideTimer = Timer(const Duration(seconds: 5), () {
    if (!mounted) return;

    setState(() {
      _commandStatus = CommandStatus.idle;
      _statusMessage = null;
    });
  });
}

Future<void> _sendAeratorCommand() async {
  // 1️⃣ CHECK INTERNET FIRST
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
    setState(() {
      _commandStatus = CommandStatus.networkError;
      _statusMessage = "Network issue · Check your internet connection";

      line1Loading = false;
      line2Loading = false;
    });

    _autoHideStatusPill(); // ⏱ auto dismiss after 5s
    return;
  }

  // 2️⃣ CHECK MQTT / DEVICE CONNECTION
  if (!deviceReady || !_mqttService.isConnected) {
    setState(() {
      _commandStatus = CommandStatus.networkError;
      _statusMessage = "Unable to reach device";

      line1Loading = false;
      line2Loading = false;
    });

    _autoHideStatusPill(); // ⏱ auto dismiss after 5s
    return;
  }

  // 3️⃣ SAVE LAST CONFIRMED STATE (FOR ROLLBACK)
  lastCommandedDeviceId = deviceId;
  prevLine1Status = line1Confirmed;
  prevLine2Status = line2Confirmed;

  // 4️⃣ SHOW INITIALIZING (CLOCK-STYLE PILL)
  setState(() {
    _commandStatus = CommandStatus.initializing;
    _statusMessage = "Aerators initializing at field ID $deviceId";
  });

  _autoHideStatusPill(); // ⏱ auto dismiss after 5s

  // 5️⃣ SEND MQTT COMMAND
  final payload = {
    "deviceID": deviceId,
    "relay1": line1Status,
    "relay2": line2Status,
  };

  try {
    _mqttService.publishCommand(payload);
    debugPrint('📤 Sent command to $deviceId');
  } catch (e) {
    // ⚠️ Safety fallback (rare)
    setState(() {
      _commandStatus = CommandStatus.networkError;
      _statusMessage = "Network issue · Unable to send command";

      line1Loading = false;
      line2Loading = false;
    });

    _autoHideStatusPill();
    return;
  }

  // 6️⃣ START DEVICE RESPONSE TIMER
  _startAeratorResponseTimer();
}


void _startAeratorResponseTimer() {
  _commandTimeout?.cancel();

  _commandTimeout = Timer(aeratorResponseTimeout, () {
    debugPrint('⏰ No response from device');

    if (!mounted) return;

    setState(() {
      // 🔄 Rollback UI to last confirmed state
      line1Status = prevLine1Status;
      line2Status = prevLine2Status;

      line1Confirmed = prevLine1Status;
      line2Confirmed = prevLine2Status;

      line1Loading = false;
      line2Loading = false;

      // 🔴 Show floating error pill (NO SnackBar)
      _commandStatus = CommandStatus.networkError;
      _statusMessage = "Device not responding";
    });
  });
}

Future<void> _loadDeviceId() async {
  deviceId = await DeviceService.getDeviceId();

  if (deviceId == null || deviceId!.isEmpty) {
    debugPrint('❌ Device ID not found for user');
    return;
  }

  debugPrint('🔐 Device ID loaded: $deviceId');
  setState(() => deviceReady = true);
}

Future<void> _handleMqttData(Map<String, dynamic> data) async {
  debugPrint('📥 UI Received MQTT Data: $data');

  // Device must be known
  if (!data.containsKey('device_id')) return;

  final incomingDevice = data['device_id'];

  // Accept ONLY the device that this user controls
  if (incomingDevice != deviceId) {
    debugPrint(
      '⏭ Ignored device $incomingDevice (expecting $deviceId)',
    );
    return;
  }

  // Process relay confirmation
if (data.containsKey('relay1_status') &&
    data.containsKey('relay2_status')) {

  _commandTimeout?.cancel();

  final r1 = data['relay1_status'] == 1;
  final r2 = data['relay2_status'] == 1;

  // 🔐 SAVE DEVICE STATE
  await DeviceService.saveLastDeviceState(
    line1: r1,
    line2: r2,
  );

  if (!mounted) return;

  setState(() {
    _commandStatus = CommandStatus.idle;
  _statusMessage = null;
  
    line1Confirmed = r1;
    line2Confirmed = r2;

    // 🔘 UI toggle follows device
    line1Status = r1;
    line2Status = r2;

    line1Loading = false;
    line2Loading = false;
  });
  
  debugPrint('✅ Device state saved & applied');
}

}


@override
void dispose() {
   _statusAutoHideTimer?.cancel(); 
  _commandTimeout?.cancel();
  _mqttService.disconnect();
  super.dispose();
}


Widget _buildStatusPill() {
  if (_commandStatus == CommandStatus.idle || _statusMessage == null) {
    return const SizedBox.shrink();
  }

  final bool isError = _commandStatus == CommandStatus.networkError;

  return Positioned(
    bottom: 90, // 👈 same place as clock app pill
    left: 16,
    right: 16,
    child: Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.wifi_off : Icons.settings,
              size: 18,
              color: isError ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isError ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
        Column(
          children: [
            // Fixed compact App Bar
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                  AppColors.accentSoft.withValues(alpha: 0.8),
                      AppColors.accentSoft.withValues(alpha: 0.5),
                    ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aerator Control',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Smart Aquaculture System',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      NotificationBadge(
                        size: 12,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        
            // Body content - No scroll, everything fits
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey.shade50,
                      Colors.grey.shade100,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildCompactUISection(),
                ),
              ),
            ),
          ],
        ),
         _buildStatusPill(),
        ],
      ),
      
    );
  }

  Widget _buildCompactUISection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [

        // Line 1 aerator card - compact
       AeratorControlCard(
  title: "Line 1 Aerators",
  status: line1Status,
  animStatus: line1Confirmed,   // animation control
  isLoading: line1Loading,
  useGradient: true, // ⭐
  onToggle: () {
  setState(() {
    line1Status = !line1Status; // 🔘 toggle moves immediately
    line1Loading = true;        // ⏳ show loading inside toggle
  });
  _sendAeratorCommand();
},


),

      AeratorControlCard(
  title: "Line 2 Aerators",
status: line2Status,          // toggle position
  animStatus: line2Confirmed,   // animation control
  isLoading: line2Loading,   // ✅ correct variable
  useGradient: false,  // optional: keep Line 1 special
  onToggle: () {
  setState(() {
    line2Status = !line2Status;
    line2Loading = true; 
  });
  _sendAeratorCommand();
},

),



        // Compact Master Control
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
             gradient: LinearGradient(
                    colors: [
                AppColors.accentSoft.withValues(alpha: 0.8),
                    AppColors.accentSoft.withValues(alpha: 0.5),
                  ],
                        begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 58, 102, 183).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
  setState(() {
    bool newState = !(line1Status || line2Status);
    line1Status = newState;
line2Status = newState;
line1Loading = true;
line2Loading = true;

  });
  _sendAeratorCommand();
},

              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.power_settings_new,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Master Control",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  

}

// ================== COMPACT AERATOR CONTROL CARD ==================

class AeratorControlCard extends StatelessWidget {
  final String title;
  final bool status;
  final bool useGradient;
  final VoidCallback onToggle;
final bool animStatus;
final bool isLoading;


  const AeratorControlCard({
    super.key,
    required this.title,
    required this.status,
    this.useGradient = false,
    required this.onToggle,
    required this.animStatus,
    required this.isLoading,


  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 19,
      shadowColor: status ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: status
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade50,
                    Colors.green.shade100,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade100,
                    Colors.grey.shade200,
                  ],
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Compact title section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: status
                      ? LinearGradient(
                          colors: [
                            const Color.fromARGB(255, 255, 255, 255),
                            const Color.fromARGB(255, 255, 255, 255),
                          ],
                        )
                      : LinearGradient(
                          colors: [
            const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.7),
            const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.3),
          ],
                        ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: status 
                          ? Colors.green.withValues(alpha: 0.25)
                          : const Color.fromARGB(255, 198, 195, 195).withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 0, 0),
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        status ? "● OPERATIONAL" : "○ STANDBY",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color.fromARGB(255, 0, 0, 0),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Compact animation container
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: status
                        ? [
                            Colors.blue.shade100.withValues(alpha: 0.3),
                            Colors.blue.shade200.withValues(alpha: 0.5),
                          ]
                        : [
                            Colors.grey.shade200.withValues(alpha: 0.3),
                            Colors.grey.shade300.withValues(alpha: 0.5),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
child: AeratorAnimation(isOn: animStatus), // ✅ CONFIRMED ONLY
              ),

              const SizedBox(height: 12),

              // Compact status section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: status ? Colors.green : Colors.red,
                                boxShadow: [
                                  BoxShadow(
                                    color: status 
                                        ? Colors.green.withValues(alpha: 0.5)
                                        : Colors.red.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
const SizedBox(width: 6),
_buildStatusText(),
                            // Text(
                            //   status ? "RUNNING" : "STOPPED",
                            //   style: TextStyle(
                            //     fontSize: 14,
                            //     fontWeight: FontWeight.bold,
                            //     color: status ? Colors.green.shade700 : Colors.red.shade700,
                            //     letterSpacing: 0.3,
                            //   ),
                            // ),



                          ],
                          
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            status ? "Oxygen optimal" : "System offline",
                            style: TextStyle(
                              fontSize: 11,
                              color: status ? Colors.green.shade600 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                 Transform.scale(
  scale: 0.9,
  child: SizedBox(
    width: 60,
    height: 34,
    child: GestureDetector(
      onTap: isLoading ? null : onToggle, // 🔒 block spam
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: status ? Colors.green.shade300 : Colors.grey.shade400,
        ),
        child: Align(
          alignment:
              status ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),

            // ✅ LOADER INSIDE CIRCLE POINTER
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                : null,
          ),
        ),
      ),
    ),
  ),
),


                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildStatusText() {
  String statusText;
  Color statusColor;
if (isLoading) {
  statusText = "INITIALIZING";
  statusColor = Colors.orange.shade700;
} else if (status) {
  statusText = "RUNNING";
  statusColor = Colors.green.shade700;
} else {
  statusText = "STOPPED";
  statusColor = Colors.red.shade700;
}


  return Text(
    statusText,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: statusColor,
      letterSpacing: 0.3,
    ),
  );
}

}

// ================== COMPACT REALISTIC AERATOR ANIMATION ==================

class AeratorAnimation extends StatefulWidget {
  final bool isOn;

  const AeratorAnimation({super.key, required this.isOn});

  @override
  State<AeratorAnimation> createState() => _AeratorAnimationState();
}

class _AeratorAnimationState extends State<AeratorAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _splashController;
  late AnimationController _bubbleController;
  late AnimationController _waveController;

  final List<Bubble> _bubbles = [];
  final List<WaterSplash> _splashes = [];
  final List<WaterDroplet> _droplets = [];

  @override
  void initState() {
    super.initState();
      
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _initializeEffects();
  }

  void _initializeEffects() {
    _bubbles.clear();
    for (int i = 0; i < 20; i++) {
      _bubbles.add(Bubble());
    }

    _splashes.clear();
    for (int i = 0; i < 10; i++) {
      _splashes.add(WaterSplash());
    }

    _droplets.clear();
    for (int i = 0; i < 15; i++) {
      _droplets.add(WaterDroplet());
    }
  }

  @override
  void didUpdateWidget(covariant AeratorAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn) {
      _rotationController.repeat();
      _splashController.repeat();
      _bubbleController.repeat();
      _waveController.repeat();
    } else {
      _rotationController.stop();
      _splashController.stop();
      _bubbleController.stop();
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _splashController.dispose();
    _bubbleController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RealisticAeratorPainter(
        _rotationController,
        _splashController,
        _bubbleController,
        _waveController,
        widget.isOn,
        _bubbles,
        _splashes,
        _droplets,
      ),
      child: Container(),
    );
  }
}

class Bubble {
  late double x, y, radius, speed, opacity, phase, wobble;

  Bubble() { reset(); }

  void reset() {
    x = (math.Random().nextDouble() - 0.5) * 100;
    y = 40 + math.Random().nextDouble() * 20;
    radius = 2 + math.Random().nextDouble() * 4;
    speed = 0.8 + math.Random().nextDouble() * 1.5;
    opacity = 0.4 + math.Random().nextDouble() * 0.5;
    phase = math.Random().nextDouble() * 2 * math.pi;
    wobble = 0.3 + math.Random().nextDouble() * 0.6;
  }

  void update(double animationValue) {
    y -= speed;
    x += math.sin(phase + animationValue * 6) * wobble;
    opacity -= 0.006;
    radius += 0.02;
    if (y < -50 || opacity <= 0) reset();
  }
}

class WaterSplash {
  late double angle, radius, maxRadius, opacity, speed, height;

  WaterSplash() { reset(); }

  void reset() {
    angle = math.Random().nextDouble() * 10 * math.pi;
    radius = 30 + math.Random().nextDouble() * 20;
    maxRadius = radius + 25 + math.Random().nextDouble() * 30;
    opacity = 0.7 + math.Random().nextDouble() * 0.3;
    speed = 1.0 + math.Random().nextDouble() * 1.3;
    height = math.Random().nextDouble() * 12;
  }

  void update() {
    radius += speed;
    opacity -= 0.012;
    height -= 0.3;
    if (radius > maxRadius || opacity <= 0) reset();
  }
}

class WaterDroplet {
  late double x, y, vx, vy, opacity, size;

  WaterDroplet() { reset(); }

  void reset() {
    double angle = math.Random().nextDouble() * 2 * math.pi;
    double velocity = 2 + math.Random().nextDouble() * 2.5;
    x = 0; y = 0;
    vx = math.cos(angle) * velocity;
    vy = math.sin(angle) * velocity - 2;
    opacity = 0.6 + math.Random().nextDouble() * 0.4;
    size = 1.5 + math.Random().nextDouble() * 2;
  }

  void update() {
    x += vx; y += vy;
    vy += 0.15;
    opacity -= 0.015;
    if (y > 50 || opacity <= 0 || x.abs() > 80) reset();
  }
}

class RealisticAeratorPainter extends CustomPainter {
  final Animation<double> rotationAnimation;
  final Animation<double> splashAnimation;
  final Animation<double> bubbleAnimation;
  final Animation<double> waveAnimation;
  final bool isOn;
  final List<Bubble> bubbles;
  final List<WaterSplash> splashes;
  final List<WaterDroplet> droplets;

  RealisticAeratorPainter(
    this.rotationAnimation,
    this.splashAnimation,
    this.bubbleAnimation,
    this.waveAnimation,
    this.isOn,
    this.bubbles,
    this.splashes,
    this.droplets,
  ) : super(
          repaint: Listenable.merge([
            rotationAnimation,
            splashAnimation,
            bubbleAnimation,
            waveAnimation,
          ]),
        );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 12);

    _drawWaterSurface(canvas, size, center);

    if (isOn) {
      _drawWaterDroplets(canvas, center);
      _drawWaterSplashes(canvas, center);
      _drawBubbles(canvas, center);
      _drawFoamEffect(canvas, center);
    }

    _drawAeratorDevice(canvas, center);
    _drawRotatingImpeller(canvas, center);
  }

  void _drawWaterSurface(Canvas canvas, Size size, Offset center) {
    final waterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isOn
            ? [
                Colors.blue.shade300.withValues(alpha: 0.4),
                Colors.blue.shade500.withValues(alpha: 0.6),
              ]
            : [
                Colors.blue.shade200.withValues(alpha: 0.2),
                Colors.blue.shade300.withValues(alpha: 0.3),
              ],
      ).createShader(Rect.fromLTWH(0, center.dy + 15, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, center.dy + 28);

    for (double x = 0; x <= size.width; x += 3) {
      double wave = 0;
      if (isOn) {
        wave += math.sin((x / 25) + (waveAnimation.value * 10)) * 2.5;
        wave += math.sin((x / 15) + (splashAnimation.value * 15)) * 1.5;
      } else {
        wave = math.sin((x / 30)) * 0.4;
      }
      path.lineTo(x, center.dy + 28 + wave);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, waterPaint);

    if (isOn) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      
      final highlightPath = Path();
      highlightPath.moveTo(0, center.dy + 28);
      
      for (double x = 0; x <= size.width; x += 3) {
        double wave = math.sin((x / 25) + (waveAnimation.value * 10)) * 2.5;
        highlightPath.lineTo(x, center.dy + 28 + wave);
      }
      canvas.drawPath(highlightPath, highlightPaint);
    }
  }

  void _drawWaterDroplets(Canvas canvas, Offset center) {
    for (var droplet in droplets) {
      droplet.update();
      if (droplet.opacity > 0) {
        final dropletPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: droplet.opacity * 0.8),
              Colors.blue.shade300.withValues(alpha: droplet.opacity * 0.6),
            ],
          ).createShader(Rect.fromCircle(
            center: Offset(center.dx + droplet.x, center.dy + droplet.y),
            radius: droplet.size,
          ));

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx + droplet.x, center.dy + droplet.y),
            width: droplet.size * 2,
            height: droplet.size * 3,
          ),
          dropletPaint,
        );
        
        canvas.drawCircle(
          Offset(
            center.dx + droplet.x - droplet.size * 0.3,
            center.dy + droplet.y - droplet.size * 0.5,
          ),
          droplet.size * 0.4,
          Paint()..color = Colors.white.withValues(alpha: droplet.opacity * 0.6),
        );
      }
    }
  }

  void _drawWaterSplashes(Canvas canvas, Offset center) {
    for (var splash in splashes) {
      splash.update();
      if (splash.opacity > 0) {
        final splashX = center.dx + math.cos(splash.angle) * splash.radius;
        final splashY = center.dy + math.sin(splash.angle) * splash.radius * 0.4 - splash.height;

        final splashPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: splash.opacity * 0.7),
              Colors.blue.shade300.withValues(alpha: splash.opacity * 0.5),
            ],
          ).createShader(Rect.fromCircle(center: Offset(splashX, splashY), radius: 12))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 + (splash.opacity * 6)
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: Offset(splashX, splashY), radius: 10),
          splash.angle - 0.4,
          0.8,
          false,
          splashPaint,
        );

        if (splash.opacity > 0.4) {
          final particlePaint = Paint()
            ..color = Colors.blue.shade200.withValues(alpha: splash.opacity * 0.8);

          for (int i = 0; i < 3; i++) {
            final pa = splash.angle + (i - 1) * 0.3;
            canvas.drawCircle(
              Offset(splashX + math.cos(pa) * 6, splashY + math.sin(pa) * 6),
              1.5,
              particlePaint,
            );
          }
        }
      }
    }
  }

  void _drawBubbles(Canvas canvas, Offset center) {
    for (var bubble in bubbles) {
      bubble.update(bubbleAnimation.value);
      if (bubble.opacity > 0) {
        final bc = Offset(center.dx + bubble.x, center.dy + bubble.y);

        final bubblePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: bubble.opacity * 0.9),
              Colors.blue.shade100.withValues(alpha: bubble.opacity * 0.7),
              Colors.blue.shade300.withValues(alpha: bubble.opacity * 0.3),
            ],
          ).createShader(Rect.fromCircle(center: bc, radius: bubble.radius));

        canvas.drawCircle(bc, bubble.radius, bubblePaint);
        canvas.drawCircle(
          bc,
          bubble.radius,
          Paint()
            ..color = Colors.blue.shade400.withValues(alpha: bubble.opacity * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );

        canvas.drawCircle(
          bc.translate(-bubble.radius * 0.3, -bubble.radius * 0.3),
          bubble.radius * 0.4,
          Paint()..color = Colors.white.withValues(alpha: bubble.opacity),
        );
      }
    }
  }

  void _drawFoamEffect(Canvas canvas, Offset center) {
    final foamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (int i = 0; i < 25; i++) {
      final angle = (i / 25) * 2 * math.pi + splashAnimation.value * 2;
      final radius = 25 + math.sin(angle * 3 + splashAnimation.value * 5) * 8;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius * 0.3,
        ),
        1.5 + math.sin(angle * 5),
        foamPaint,
      );
    }
  }

  void _drawAeratorDevice(Canvas canvas, Offset center) {
    final housingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.grey.shade600, Colors.grey.shade800],
      ).createShader(Rect.fromCenter(center: center, width: 100, height: 38))
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 120, height: 38),
        const Radius.circular(8),
      ),
      housingPaint,
    );

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.grey.shade400.withValues(alpha: 0.8), Colors.grey.shade600.withValues(alpha: 0.4)],
      ).createShader(Rect.fromCenter(center: Offset(center.dx, center.dy - 8), width: 90, height: 12));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 8), width: 90, height: 12),
        const Radius.circular(5),
      ),
      highlightPaint,
    );

    final boltPaint = Paint();
    for (var pos in [
      Offset(center.dx - 40, center.dy),
      Offset(center.dx + 40, center.dy),
      Offset(center.dx - 28, center.dy + 12),
      Offset(center.dx + 28, center.dy + 12),
    ]) {
      canvas.drawCircle(pos.translate(0.8, 0.8), 4, Paint()..color = Colors.black.withValues(alpha: 0.3));
      boltPaint.color = Colors.grey.shade900;
      canvas.drawCircle(pos, 4, boltPaint);
      boltPaint.color = Colors.grey.shade700;
      canvas.drawCircle(pos.translate(-0.8, -0.8), 1.5, boltPaint);
    }
  }

  void _drawRotatingImpeller(Canvas canvas, Offset center) {
    final double angle = rotationAnimation.value * 2 * math.pi;
    const int numBlades = 6;
    const double bladeLength = 38.0;
    const double bladeWidth = 16.0;

    if (isOn) {
      for (int ring = 0; ring < 3; ring++) {
        canvas.drawCircle(
          center,
          32 + ring * 6,
          Paint()
            ..color = Colors.orange.shade400.withValues(alpha: 0.06 - ring * 0.015)
            ..style = PaintingStyle.stroke
            ..strokeWidth = bladeWidth + ring * 4
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + ring * 1.5),
        );
      }
    }

    for (int i = 0; i < numBlades; i++) {
      final bladeAngle = angle + (i * 2 * math.pi / numBlades);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(bladeAngle);
      canvas.rotate(math.pi / 10);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(14, -bladeWidth / 2 + 1.5, bladeLength, bladeWidth),
          const Radius.circular(2.5),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      final bladePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isOn
              ? [Colors.orange.shade500, Colors.orange.shade700, Colors.orange.shade800]
              : [Colors.orange.shade600, Colors.orange.shade800, Colors.orange.shade900],
        ).createShader(Rect.fromLTWH(12, -bladeWidth / 2, bladeLength, bladeWidth));

      final bladeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(12, -bladeWidth / 2, bladeLength, bladeWidth),
        const Radius.circular(2.5),
      );

      canvas.drawRRect(bladeRect, bladePaint);
      canvas.drawRRect(
        bladeRect,
        Paint()
          ..color = Colors.orange.shade900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final holePaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
      for (double x = 18; x < 12 + bladeLength - 5; x += 6) {
        for (double y = -bladeWidth / 2 + 4; y < bladeWidth / 2 - 2; y += 6) {
          canvas.drawCircle(Offset(x, y), 1.5, holePaint);
        }
      }

      canvas.drawRect(
        Rect.fromLTWH(12, -bladeWidth / 2, bladeLength, 2.5),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              Colors.orange.shade300.withValues(alpha: isOn ? 0.7 : 0.4),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(12, -bladeWidth / 2, bladeLength, 2.5)),
      );

      final strutPaint = Paint()
        ..color = Colors.orange.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(10, -2.5), Offset(18, -bladeWidth / 2 + 2.5), strutPaint);
      canvas.drawLine(Offset(10, 2.5), Offset(18, bladeWidth / 2 - 2.5), strutPaint);

      canvas.drawRect(
        Rect.fromLTWH(12, bladeWidth / 2 - 1.5, bladeLength, 1.5),
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      );

      canvas.restore();
    }

    canvas.drawCircle(
      center,
      14,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.grey.shade500, Colors.grey.shade700, Colors.grey.shade900],
        ).createShader(Rect.fromCircle(center: center, radius: 14)),
    );

    canvas.drawCircle(
      center.translate(-3, -3),
      7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.4),
            Colors.grey.shade400.withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center.translate(-3, -3), radius: 7)),
    );

    canvas.drawCircle(
      center,
      8,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.grey.shade600, Colors.grey.shade900],
        ).createShader(Rect.fromCircle(center: center, radius: 8)),
    );

    canvas.drawCircle(
      center.translate(-1.5, -1.5),
      3,
      Paint()..color = Color(0xFF52525b),
    );

    if (isOn) {
      canvas.drawCircle(
        Offset(center.dx + math.cos(angle) * 6, center.dy + math.sin(angle) * 6),
        1.5,
        Paint()..color = Colors.red.shade600,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RealisticAeratorPainter oldDelegate) => true;
}