import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswaphub/screens/auth/login_screen.dart';

void main() {
  testWidgets('Forgot password dialog opens, cancels, and re-opens cleanly', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Tap forgot password to open dialog
    final forgotBtn = find.text('Forgot Password?');
    expect(forgotBtn, findsOneWidget);
    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);

    // 2. Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsNothing);

    // 3. Re-open cleanly to ensure no lingering dependents
    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsOneWidget);

    // 4. Test validation error when empty
    await tester.tap(find.text('Send Link'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);

    // 5. Dismiss with Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Password'), findsNothing);
  });
}
