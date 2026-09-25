import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/screens/splash/splash_screen.dart';

void main() {
  Opacity ancestorOpacity(WidgetTester tester, Finder target) {
    return tester.widget<Opacity>(
      find.ancestor(of: target, matching: find.byType(Opacity)).first,
    );
  }

  Finder logoImage() {
    return find.byWidgetPredicate((Widget widget) {
      if (widget is! Image || widget.image is! AssetImage) return false;
      final asset = widget.image as AssetImage;
      return asset.assetName.endsWith('splashScreenLogo.png');
    });
  }

  testWidgets('Splash reveals background first, then logo and wordmark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    // Early: backdrop fading in while logo and wordmark are still hidden.
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      ancestorOpacity(tester, find.byType(Image).first).opacity,
      greaterThan(0),
      reason: 'backdrop must appear first',
    );
    expect(ancestorOpacity(tester, logoImage()).opacity, 0);
    expect(ancestorOpacity(tester, find.text('FanVerse')).opacity, 0);

    // Mid-sequence: logo fully revealed and the wordmark fading in.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(
      ancestorOpacity(tester, logoImage()).opacity,
      greaterThan(0.9),
      reason: 'logo must be revealed before the wordmark',
    );
    expect(find.text('FanVerse'), findsOneWidget);
    expect(
      ancestorOpacity(tester, find.text('FanVerse')).opacity,
      greaterThan(0),
      reason: 'wordmark must appear after the logo',
    );

    expect(tester.takeException(), isNull);
  });
}
