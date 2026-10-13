// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:SabzeeWala/providers/app_state.dart';

import 'package:SabzeeWala/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Set initial mock values for SharedPreferences to prevent hanging in tests
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame with AppState provider.
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: const SabzeeWalaApp(),
      ),
    );

    // Verify that the splash screen loads with the splash image
    expect(find.byType(Image), findsOneWidget);

    // Let the timer run out
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
