

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gf1/model/water_quality_model.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = "https://www.gfiotsolutions.com/api/data/";
  static const String _updateUrl = "https://www.gfiotsolutions.com/api/users/update";

  Future<String?> _fetchDeviceId() async {
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
      debugPrint("Error fetching deviceId: $e");
    }
    return null;
  }

  /// GET call
  Future<WaterQualityData> fetchWaterQualityData() async {
    try {
      final deviceId = await _fetchDeviceId();
      if (deviceId == null) {
        throw Exception("Device ID not found");
      }

      final url = "$_baseUrl$deviceId";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'ok' && jsonData['data'] != null) {
          return WaterQualityData.fromJson(jsonData);
        } else {
          throw Exception('API returned an error or no data');
        }
      } else {  
        throw Exception('Failed to load data from API');
      }
    } catch (e) {
      throw Exception(
        'Failed to connect. Please check your connection and activate the device.',
      );
    }
  }

  /// PATCH call
  Future<bool> patchUserUpdate({
    required int noAeratorsLine1,
    required int noAeratorsLine2,
    required double perAeratorLine1,
    required double perAeratorLine2,
  }) async {
    try {
      final deviceId = await _fetchDeviceId();
      if (deviceId == null) throw Exception("Device ID not found");

      final body = {
        "deviceId": deviceId,
        "noAeratorsLine1": noAeratorsLine1,
        "noAeratorsLine2": noAeratorsLine2,
        "perAerator_currentLine1": perAeratorLine1,
        "perAerator_currentLine2": perAeratorLine2,
      };

      final response = await http.patch(
        Uri.parse(_updateUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        debugPrint("PATCH Success: ${response.body}");
        return true;
      } else {
        debugPrint("PATCH Failed: ${response.statusCode} ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error in patchUserUpdate: $e");
      return false;
    }
  }
}