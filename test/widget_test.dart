import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bond/shared/theme/app_theme.dart';

void main() {
  // Layer 1 smoke test: the theme builds and a trivial app renders.
  // Full widget tests arrive with auth + couple-linking.
  testWidgets('App renders with the BOND theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: Text('BOND'))),
      ),
    );

    expect(find.text('BOND'), findsOneWidget);
  });
}
