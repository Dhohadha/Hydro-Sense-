// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gf1/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize mock values for plugins
    SharedPreferences.setMockInitialValues({});
    
    // Build our app and trigger a frame.
    // Note: This might require mocks for Firebase/dotenv if they are accessed during build.
    await tester.pumpWidget(const MyApp());

    // Verify that the splash screen or initial layout is present.
    // Since SplashScreen starts with some text/animations, we just verify it doesn't crash here.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
