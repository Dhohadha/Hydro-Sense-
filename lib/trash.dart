import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() {
  runApp(const AeratorApp());
}

class AeratorApp extends StatelessWidget {
  const AeratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pond Aerator Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AeratorHomePage(),
    );
  }
}

class AeratorHomePage extends StatefulWidget {
  const AeratorHomePage({super.key});

  @override
  State<AeratorHomePage> createState() => _AeratorHomePageState();
}

class _AeratorHomePageState extends State<AeratorHomePage> {
  // USER switch state
  bool line1Status = false;
  bool line2Status = false;

  // DEVICE confirmed (animation ONLY)
  bool line1Confirmed = false;
  bool line2Confirmed = false;

  String deviceId = "";
  final TextEditingController _deviceIdController = TextEditingController();

  late MqttServerClient client;

  // ---------------------- PUBLISH ----------------------
  void _publishStatus() {
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      final message = jsonEncode({
        "deviceID": deviceId,
        "relay1": line1Status,
        "relay2": line2Status,
      });

      final builder = MqttClientPayloadBuilder();
      builder.addString(message);

      client.publishMessage('PMS/cmd', MqttQos.atMostOnce, builder.payload!);
      debugPrint('📤 Published: $message');
    } else {
      debugPrint('⚠ MQTT not connected, cannot publish');
    }
  }

  @override
  void initState() {
    super.initState();
    _deviceIdController.text = deviceId;
    _connectMQTT();
  }

  Future<void> _connectMQTT() async {
    client = MqttServerClient(
      'broker.emqx.io',
      'flutter_aerator_client_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.logging(on: false);

    client.onConnected = () => debugPrint('✅ Connected to MQTT broker');
    client.onDisconnected = () => debugPrint('❌ Disconnected');
    client.onSubscribed = (topic) => debugPrint('📡 Subscribed to $topic');

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
          'flutter_aerator_${DateTime.now().millisecondsSinceEpoch}',
        )
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Connection failed: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.subscribe('PMS/data', MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        final recMess = messages[0].payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        debugPrint('📥 Received: $payload');
        _handleMQTTMessage(payload);
      });
    } else {
      debugPrint('❗ Connection failed: ${client.connectionStatus}');
      client.disconnect();
    }
  }

  // -------------- DEVICE FEEDBACK (CONFIRMS animation) --------------
  void _handleMQTTMessage(String message) {
    try {
      final data = jsonDecode(message);

      if (data['device_id'] == deviceId) {
        setState(() {
          // ONLY animation uses confirmed values
          line1Confirmed = (data['relay1_status'] == 1);
          line2Confirmed = (data['relay2_status'] == 1);
        });
      }
    } catch (e) {
      debugPrint('❗ Error parsing message: $e');
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    client.disconnect();
    super.dispose();
  }

  // ----------- USER BUTTONS (instant UI, publish) -----------
  void toggleLine1() {
    setState(() => line1Status = !line1Status);
    _publishStatus();
  }

  void toggleLine2() {
    setState(() => line2Status = !line2Status);
    _publishStatus();
  }

  void toggleAll() {
    setState(() {
      final newStatus = !(line1Status && line2Status);
      line1Status = newStatus;
      line2Status = newStatus;
    });
    _publishStatus();
  }

  void _updateDeviceId() {
    if (_deviceIdController.text.trim().isNotEmpty) {
      setState(() => deviceId = _deviceIdController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device ID updated to: $deviceId'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pond Aerator Controller"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              _buildDeviceIdInput(),
              const SizedBox(height: 20),

              // Line 1
              AeratorControlCard(
                title: "Line 1 Aerators",
                status: line1Status,           // switch/UI state
                animStatus: line1Confirmed,    // animation follows device
                onToggle: toggleLine1,
                headerColor: Colors.orange.shade100,
              ),

              const SizedBox(height: 10),

              // Line 2
              AeratorControlCard(
                title: "Line 2 Aerators",
                status: line2Status,
                animStatus: line2Confirmed,
                onToggle: toggleLine2,
                headerColor: Colors.orange.shade100,
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: toggleAll,
                icon: const Icon(Icons.power_settings_new),
                label: const Text("Master Control"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIdInput() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: "Device ID",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _updateDeviceId,
              child: const Text("Enter"),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- CARD (UI SAME — animation uses animStatus) ----------
class AeratorControlCard extends StatelessWidget {
  final String title;
  final bool status;
  final bool animStatus;   // NEW: device-confirmed animation flag
  final VoidCallback onToggle;
  final Color headerColor;

  const AeratorControlCard({
    super.key,
    required this.title,
    required this.status,
    required this.animStatus,
    required this.onToggle,
    required this.headerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: status
              ? LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      status ? "OPERATIONAL" : "STANDBY",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 👉 animation uses DEVICE CONFIRM ONLY
              SizedBox(height: 120, child: AeratorAnimation(isOn: animStatus)),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    status ? "Status: RUNNING" : "Status: STOPPED",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: status ? Colors.green : Colors.red,
                    ),
                  ),
                  Switch(
                    value: status,
                    onChanged: (_) => onToggle(),
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.green.shade200,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Aerator Animation (unchanged) ----------
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

  final List<Bubble> _bubbles = [];
  final List<WaterSplash> _splashes = [];

  @override
  void initState() {
    super.initState();
    _rotationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _splashController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _bubbleController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));

    _initializeEffects();
  }

  void _initializeEffects() {
    _bubbles.clear();
    for (int i = 0; i < 15; i++) { _bubbles.add(Bubble()); }

    _splashes.clear();
    for (int i = 0; i < 8; i++) { _splashes.add(WaterSplash()); }
  }

  @override
  void didUpdateWidget(covariant AeratorAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isOn) {
      _rotationController.repeat();
      _splashController.repeat();
      _bubbleController.repeat();
    } else {
      _rotationController.stop();
      _splashController.stop();
      _bubbleController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _splashController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RealisticAeratorPainter(
        _rotationController,
        _splashController,
        _bubbleController,
        widget.isOn,
        _bubbles,
        _splashes,
      ),
      child: Container(),
    );
  }
}

// ----- bubble + splash + painter (UNCHANGED) -----

class Bubble {
  late double x, y, radius, speed, opacity, phase;

  Bubble() {
    reset();
  }

  void reset() {
    x = (math.Random().nextDouble() - 0.5) * 100;
    y = 40 + math.Random().nextDouble() * 20;
    radius = 2 + math.Random().nextDouble() * 4;
    speed = 0.5 + math.Random().nextDouble() * 1.5;
    opacity = 0.3 + math.Random().nextDouble() * 0.4;
    phase = math.Random().nextDouble() * 2 * math.pi;
  }

  void update(double v) {
    y -= speed;
    x += math.sin(phase + v * 4) * 0.5;
    opacity -= 0.008;
    if (y < -50 || opacity <= 0) reset();
  }
}

class WaterSplash {
  late double angle, radius, maxRadius, opacity, speed;

  WaterSplash() {
    reset();
  }

  void reset() {
    angle = math.Random().nextDouble() * 2 * math.pi;
    radius = 30 + math.Random().nextDouble() * 20;
    maxRadius = radius + 20 + math.Random().nextDouble() * 30;
    opacity = 0.6 + math.Random().nextDouble() * 0.4;
    speed = 0.8 + math.Random().nextDouble() * 1.2;
  }

  void update() {
    radius += speed;
    opacity -= 0.015;
    if (radius > maxRadius || opacity <= 0) reset();
  }
}

class RealisticAeratorPainter extends CustomPainter {
  final Animation<double> rotation, splash, bubble;
  final bool isOn;
  final List<Bubble> bubbles;
  final List<WaterSplash> splashes;

  RealisticAeratorPainter(
    this.rotation,
    this.splash,
    this.bubble,
    this.isOn,
    this.bubbles,
    this.splashes,
  ) : super(repaint: Listenable.merge([rotation, splash, bubble]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 20);

    _drawWaterSurface(canvas, size, center);

    if (isOn) {
      for (var s in splashes) { s.update(); }
      for (var b in bubbles) { b.update(bubble.value); }

      _drawSplashes(canvas, center);
      _drawBubbles(canvas, center);
    }

    _drawDevice(canvas, center);
    _drawImpeller(canvas, center);
  }

  void _drawWaterSurface(Canvas c, Size s, Offset center) {
    final paint =
        Paint()
          ..color = Colors.blue.shade200.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

    final path = Path()..moveTo(0, center.dy + 30);

    for (double x = 0; x <= s.width; x += 5) {
      double wave = math.sin((x / 20) + (rotation.value * 8)) * 2;
      if (isOn) wave += math.sin((x / 10) + (splash.value * 12)) * 1.5;
      path.lineTo(x, center.dy + 30 + wave);
    }

    path
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();

    c.drawPath(path, paint);
  }

  void _drawSplashes(Canvas c, Offset center) {
    for (var s in splashes) {
      final paint =
          Paint()
            ..color = Colors.blue.shade300.withValues(alpha: s.opacity * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + (s.opacity * 3);

      final sx = center.dx + math.cos(s.angle) * s.radius;
      final sy = center.dy + math.sin(s.angle) * s.radius * 0.3;

      c.drawArc(
        Rect.fromCircle(center: Offset(sx, sy), radius: 8),
        s.angle - 0.3,
        0.6,
        false,
        paint,
      );
    }
  }

  void _drawBubbles(Canvas c, Offset center) {
    for (var b in bubbles) {
      final fill =
          Paint()..color = Colors.white.withValues(alpha: b.opacity);
      final ring =
          Paint()
            ..color = Colors.blue.shade200.withValues(alpha: b.opacity * 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5;

      final o = Offset(center.dx + b.x, center.dy + b.y);
      c.drawCircle(o, b.radius, fill);
      c.drawCircle(o, b.radius, ring);
    }
  }

  void _drawDevice(Canvas c, Offset center) {
    final paint = Paint()..color = Colors.grey.shade700;
    final rect = Rect.fromCenter(center: center, width: 120, height: 45);
    c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
  }

  void _drawImpeller(Canvas c, Offset center) {
    final angle = rotation.value * 2 * math.pi;
    const blades = 6;
    const radius = 45;

    c.drawCircle(
      center,
      12,
      Paint()..color = Colors.grey.shade600,
    );

    for (int i = 0; i < blades; i++) {
      final a = angle + (i * 2 * math.pi / blades);
      final bx = center.dx + radius * math.cos(a);
      final by = center.dy + radius * math.sin(a);

      final p =
          Paint()
            ..color = isOn ? Colors.blue.shade500 : Colors.grey.shade500;

      c.save();
      c.translate(bx, by);
      c.rotate(a + math.pi / 2);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 8, height: 20), p);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}




// this is 
// secrets folder -- key.json file 

// {
//   "type": "service_account",
//   "project_id": "pond-management-system-d6d04",
//   "private_key_id": "71fed57100e03d3b801aee2e3d3bfab2a15cb60f",
//   "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDSiW7qVRS8orba\naOzSiackRboslHQL2xQ81xREk0+Vs+Z4x/xzyu4Y0JxhmfocQTroLRVYA2zomAo/\na74GITXpyVUiqav2kC9lUWkkdcLG8EDjJ2jsgRONMjAqVD9vO6VzU0lukRJWXnnj\n3Fs4a1MkkXLNoeKxAhIR403vbhQTkTO4UKoXi3pXjm+SeA4p3UGhpyDE93IrBlNN\nVyF8uFWuSLQN4FnqXz7tFYhKNCCAGLVEsrahUmy5EP+240N2SOSMuinUZjYbuRsF\nw1Il7+ZbRgVksJzrlfQU7e5r22K75DCd6xdSRvy6SQw97XiAZb/QMD7Xwcg70Olh\nH3k2oD8HAgMBAAECggEAaJ8A7hOffWnCQeC4Jpte4oh/zp1q2WVhtiYPHVCy0KqY\nUdbXXdcu4EfyHhI9FoNXuX6Fx7nUCfVbyk5JHJSuTOHOm64DFUBrPQbqn8KhKujC\n5d50pmoyBA03oCFDcIwMWLW/nOEcYq0KFzAuaGf05gwdJ5BVrS5hOmBhHyTtdxbf\nB5mUdfJa9dTnctUGMlN4RhaRYZLcm6XtUl4XjmbMaGiqjqecdZfF2V95ZIzCPJjV\nq6q6kWhLsVy2qc9kj/7M4jwcysWtjJ3k1ZvzRAcCpZPx8m7upRqlhmSu69qFVp4D\nNfSYlPIhZ8j15Rgsptk6VuYYyaBOhtJejCWOmZVGOQKBgQDoqRslPt42uiYYx6gZ\nvktyylySxzcIry/2MUMeTsWayQY/X2QCrUitlNMxzg40v4XFz87yvjcnxtdu39Rh\nYoJ4alLppA57qi0kLcC8LWeof7cl9GybAwayMk3im3ZHDUCSXNsvPIeIDh07Ux8H\n3PyDGjMnNe/7lUNbQWbcvBA8iwKBgQDnqCyAkObsV/2an9uOlPN0+xEMwIXHC71D\nwa057O3ruYWgOjlv83yGkQrb1X/thKKroWDTzdQhCIPBShdouG5B7g8PploZhkOc\nUtvthAzGoSf60H9c9XbwcKanj+TwB9DzyXBynDEmgZg5y2L2X16hrkohO3LbQTqn\nNBJb6uaq9QKBgQDS9YLHotmahe9FSMQDk6iVzSdjb39XQIIcmU5ijMpgLyabD8N/\nKeBchDV7U3tOGNsTIfpj4FXim0l8HzhTlR74UHAdqcP4HbYQt+uqtQDop+VJZPeV\nFolbyoEUmCIHCt0h2VBk5F1/4ExhHl1ko9vShE8dnqqbVBxfAk5il6OhQQKBgAmR\njb0FvzQV8li3r6b1ChVT5YFkVmJBXuD0mAYjfjRVZmqW3RZ9tTANv6gS6oTSDLIQ\nKWK2RsPSiTarq8ncjFlWzvJziZcyT4qedY0a/jgaIf+fKxOY4//Md2XGcMtlV0Eq\nmeVyBCm2Aqaoev74M310KIW04eqiiByt7vAzBLIdAoGAVVE7IBlzbcqu6YNKvabS\nCX3h/lQ87Cb/bx/CdFDhZc3OZXropqPgkq588z8OasTqYJuCZvpKLpryKbDKfSEh\n2d+5sQ0LbmBEneTrttEJHeObOWQL6xENybthIynuX2PthhkVkyt+HWLUqj54s9sr\nhfwFQMlCADsDYV+QjvJ7suI=\n-----END PRIVATE KEY-----\n",
//   "client_email": "firebase-adminsdk-fbsvc@pond-management-system-d6d04.iam.gserviceaccount.com",
//   "client_id": "110350427290835580034",
//   "auth_uri": "https://accounts.google.com/o/oauth2/auth",
//   "token_uri": "https://oauth2.googleapis.com/token",
//   "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
//   "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40pond-management-system-d6d04.iam.gserviceaccount.com",
//   "universe_domain": "googleapis.com"
// }


// .env file 


// PROJECT_ID=pond-management-system-d6d04
// PATH_TO_SECRET=secrets/key.json
