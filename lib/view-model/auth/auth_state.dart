import 'package:flutter/material.dart';
import 'package:gf1/view-model/homepage.dart';
import 'package:gf1/view/services/monitoring_service.dart'; // <-- IMPORT THE NEW SERVICE
import 'package:gf1/view/services/notification_services.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Auth bypass for testing: navigate directly to dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MonitoringService().start();
      NotificationServices.ensureTokenSynced();
    });

    return const MainNavigationPage();
  }
}
