import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gf1/view-model/auth/registration_screen.dart';
import 'package:gf1/view-model/homepage.dart';
import 'package:gf1/view/services/monitoring_service.dart'; // <-- IMPORT THE NEW SERVICE
import 'package:gf1/view/services/notification_services.dart';
import 'phone_login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _checkIfUserExists(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint("Error checking user existence: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              heightFactor: 10,
              child: Center(
                child: Image.asset(
                  "assets/loading.gif",
                  width: 1000,
                  height: 800,
                ),
              ),
            );
          }

          if (snapshot.hasData) {
            final user = snapshot.data!;
            return FutureBuilder<bool>(
              future: _checkIfUserExists(user.uid),
              builder: (context, userExistsSnapshot) {
                if (userExistsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    heightFactor: 10,
                    child: Center(
                      child: Image.asset(
                        "assets/loading.gif",
                        width: 500,
                        height: 300,
                      ),
                    ),
                  );
                }

                if (userExistsSnapshot.hasData &&
                    userExistsSnapshot.data == true) {
                  // --- USER IS FULLY LOGGED IN: START THE SERVICE ---
                  MonitoringService().start();
                  NotificationServices.ensureTokenSynced();
                  return MainNavigationPage();
                } else {
                  // --- USER ISN'T REGISTERED: STOP THE SERVICE ---
                  MonitoringService().stop();
                  return RegistrationScreen(
                    phoneNumber: user.phoneNumber ?? 'N/A',
                  );
                }
              },
            );
          } else {
            // --- USER IS NOT LOGGED IN: STOP THE SERVICE ---
            MonitoringService().stop();
            return const PhoneNumberPage();
          }
        },
      ),
    );
  }
}
