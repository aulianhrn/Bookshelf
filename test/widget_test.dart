// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bookself_/main.dart';

void main() {
  testWidgets('Shows login page when no local user session exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('BookShelf'), findsOneWidget);
    expect(find.text('Selamat Datang Kembali'), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);
  });
}
