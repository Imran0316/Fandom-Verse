import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/cart_docs.dart';
import 'package:fandom_verse/screens/shop/cart_screen.dart';
import 'package:fandom_verse/screens/shop/checkout_screen.dart';

void main() {
  const items = [
    CartItemDoc(
      productId: 'p1',
      name: 'Fandom Tee',
      priceLabel: r'$29',
      priceCents: 2900,
      quantity: 2,
    ),
  ];

  Widget wrap(Widget home) => MaterialApp(
        home: home,
        routes: {
          '/checkout': (_) => CheckoutScreen(
                cartStream: Stream.value(items),
              ),
        },
      );

  Future<void> tallView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('cart shows summary and proceeds to checkout', (
    WidgetTester tester,
  ) async {
    await tallView(tester);
    await tester.pumpWidget(wrap(CartScreen(cartStream: Stream.value(items))));
    await tester.pumpAndSettle();

    expect(find.text('Your cart'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Fandom Tee'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('PKR 58'), findsWidgets);
    expect(find.text('Proceed to checkout'), findsOneWidget);

    await tester.tap(find.text('Proceed to checkout'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.text('Checkout'), findsWidgets);
    expect(find.text('DELIVER TO'), findsOneWidget);
    expect(find.text('ORDER SUMMARY'), findsOneWidget);
    expect(find.text('2× Fandom Tee'), findsOneWidget);
    expect(find.text('PAYMENT METHOD'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.text('Card payment'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Place order · PKR 58'), findsOneWidget);
  });

  testWidgets('checkout validates address before placing an order', (
    WidgetTester tester,
  ) async {
    await tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(cartStream: Stream.value(items)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Place order · PKR 58'));
    await tester.pump();

    expect(
      find.textContaining('Enter a full delivery address'),
      findsOneWidget,
    );
    expect(find.byType(CheckoutScreen), findsOneWidget);
  });

  testWidgets('checkout shows empty state with no place-order button', (
    WidgetTester tester,
  ) async {
    await tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(cartStream: Stream.value(const <CartItemDoc>[])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing to check out'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.textContaining('Place order'), findsNothing);
  });

  testWidgets('cart empty state offers browsing again', (
    WidgetTester tester,
  ) async {
    await tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(cartStream: Stream.value(const <CartItemDoc>[])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cart is empty'), findsOneWidget);
    expect(find.text('Browse merch'), findsOneWidget);
    expect(find.text('Proceed to checkout'), findsNothing);
  });
}
