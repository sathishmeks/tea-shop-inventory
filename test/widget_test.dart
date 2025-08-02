// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_shop_inventory/core/themes/app_theme.dart';
import 'package:tea_shop_inventory/core/constants/app_constants.dart';

void main() {
  test('App constants are properly defined', () {
    expect(AppConstants.appName, 'Tea Shop Inventory');
    expect(AppConstants.appVersion, '1.0.0');
    expect(AppConstants.roleAdmin, 'admin');
    expect(AppConstants.roleStaff, 'staff');
  });

  testWidgets('App theme is properly configured', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(child: Text('Test')),
        ),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
  });
}
