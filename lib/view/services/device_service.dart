import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {

  // 🔐 EXISTING METHOD (KEEP)
  static Future<String?> getDeviceId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data()?['deviceId'] as String?;
      }
    } catch (e) {
      debugPrint('❗ Error fetching deviceId: $e');
    }

    return null;
  }

  // =================== NEW CODE BELOW ===================

  static const _line1Key = 'last_line1_state';
  static const _line2Key = 'last_line2_state';

  /// Save confirmed device relay state
  static Future<void> saveLastDeviceState({
    required bool line1,
    required bool line2,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_line1Key, line1);
    await prefs.setBool(_line2Key, line2);
  }

  /// Load last known device relay state
  static Future<(bool, bool)> loadLastDeviceState() async {
    final prefs = await SharedPreferences.getInstance();

    final l1 = prefs.getBool(_line1Key) ?? false;
    final l2 = prefs.getBool(_line2Key) ?? false;

    return (l1, l2);
  }
}
