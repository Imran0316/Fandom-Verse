import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/screens/auth/auth_form.dart';

void main() {
  testWidgets('Apple button explains platform support on Android tests',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var success = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthForm(
            initialMode: AuthFormMode.signIn,
            onSuccess: (_) => success = true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.byIcon(Icons.apple_rounded), findsOneWidget);

    await tester.tap(find.text('Apple'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Apple Sign-In is available on iPhone, Mac and the web app.'),
      findsOneWidget,
    );
    expect(success, isFalse);
  });
}
