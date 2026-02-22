import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pantry_pilot/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders auth actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('New user? Create account'), findsOneWidget);
  });
}
