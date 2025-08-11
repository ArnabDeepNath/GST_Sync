// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gspappv2/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
        MyApp(prefs: prefs)); // Verify that the app title is displayed
    expect(find.text('GSP'), findsOneWidget);

    // Verify that main menu items are present
    expect(find.text('Parties'), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('GST Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
