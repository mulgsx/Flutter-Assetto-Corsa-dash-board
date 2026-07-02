// Basic smoke test for the AC Dashboard app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:assettodash/main.dart';

void main() {
  testWidgets('ACDashboardApp renders the dashboard shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: ACDashboardApp()));
    await tester.pump();

    expect(find.text('AC Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
