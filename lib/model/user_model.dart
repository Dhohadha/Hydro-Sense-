import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String phoneNumber;
  final String location;
  final String pondArea;
  final int numberOfAerators;
  final double noAeratorsLine1;
  final double noAeratorsLine2;
  final double perAeratorCurrentLine1;
  final double perAeratorCurrentLine2;
  final double aeratorRating;
  final String guardianNumber1;
  final String? guardianNumber2; // Optional
  final String? deviceId;
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.phoneNumber,
    required this.location,
    required this.pondArea,
    required this.numberOfAerators,
    required this.aeratorRating,
    required this.guardianNumber1,
    this.guardianNumber2,
    required this.createdAt,
    required this.deviceId,
    this.noAeratorsLine1 = 0.0,
    this.noAeratorsLine2 = 0.0,
    this.perAeratorCurrentLine1 = 0.0,
    this.perAeratorCurrentLine2 = 0.0,
  });

  /// Factory constructor to create a UserModel from a Firestore document.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError("Missing data for UserModel from document: ${doc.id}");
    }
    return UserModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'No Name',
      phoneNumber: data['phoneNumber'] ?? 'No Phone',
      location: data['location'] ?? 'No Location',
      pondArea: data['pondArea'] ?? 'N/A',
      numberOfAerators: data['numberOfAerators'] ?? 0,
      aeratorRating: (data['aeratorRating'] as num?)?.toDouble() ?? 0.0,
      guardianNumber1: data['guardianNumber1'] ?? 'N/A',
      guardianNumber2: data['guardianNumber2'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      deviceId: data['deviceId'] ?? 'N/A',
      noAeratorsLine1: (data['noAeratorsLine1'] as num?)?.toDouble() ?? 0.0,
      noAeratorsLine2: (data['noAeratorsLine2'] as num?)?.toDouble() ?? 0.0,
      perAeratorCurrentLine1: (data['perAerator_currentLine1'] as num?)?.toDouble() ?? 0.0,
      perAeratorCurrentLine2: (data['perAerator_currentLine2'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Method to convert UserModel instance to a map for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'phoneNumber': phoneNumber,
      'location': location,
      'pondArea': pondArea,
      'numberOfAerators': numberOfAerators,
      'aeratorRating': aeratorRating,
      'guardianNumber1': guardianNumber1,
      'guardianNumber2': guardianNumber2,
      'createdAt': createdAt,
      'deviceId': deviceId,
      'noAeratorsLine1': noAeratorsLine1,
      'noAeratorsLine2': noAeratorsLine2,
      'perAerator_currentLine1': perAeratorCurrentLine1,
      'perAerator_currentLine2': perAeratorCurrentLine2,
    };
  }
}