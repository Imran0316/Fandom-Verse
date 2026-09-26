import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/catalog_docs.dart';
import 'package:fandom_verse/screens/shop/wishlist_screen.dart';

void main() {
  final product = MerchProductDoc(
    id: 'p1',
    name: 'Akatsuki Cloak',
    priceLabel: r'$59',
    sellerUid: 'seller-1',
    sellerName: 'Ramen Apparel',
    emoji: '🧥',
  );

  Future<void> pumpWishlist(
    WidgetTester tester, {
    required Stream<List<String>> ids,
    void Function(MerchProductDoc product)? onOpen,
    void Function(String id)? onRemove,
    void Function(MerchProductDoc product)? onMoveToCart,
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WishlistScreen(
          wishlistStream: ids,
          productsStream: Stream.value([product]),
          onOpenProduct: onOpen,
          onRemove: onRemove,
          onMoveToCart: onMoveToCart,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows wishlisted products with move-to-cart and view',
      (tester) async {
    MerchProductDoc? moved;
    MerchProductDoc? opened;
    await pumpWishlist(
      tester,
      ids: Stream.value(const ['p1']),
      onMoveToCart: (p) => moved = p,
      onOpen: (p) => opened = p,
    );

    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Akatsuki Cloak'), findsOneWidget);
    expect(find.text('Ramen Apparel · \$59'), findsOneWidget);
    expect(find.text('Move to cart'), findsOneWidget);

    await tester.tap(find.text('Move to cart'));
    await tester.pump();
    expect(moved?.id, 'p1');

    await tester.tap(find.text('View'));
    await tester.pump();
    expect(opened?.id, 'p1');
  });

  testWidgets('heart removes the item from the list', (tester) async {
    String? removed;
    await pumpWishlist(
      tester,
      ids: Stream.value(const ['p1']),
      onRemove: (id) => removed = id,
    );

    expect(find.text('Akatsuki Cloak'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();
    expect(removed, 'p1');
  });

  testWidgets('empty wishlist shows the empty state', (tester) async {
    await pumpWishlist(tester, ids: Stream<List<String>>.value(const []));
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('Browse the merch store'), findsOneWidget);
  });

  testWidgets('wishlist is independent of the cart (no cart rows)',
      (tester) async {
    await pumpWishlist(tester, ids: Stream.value(const ['p1']));
    expect(find.text('Proceed to checkout'), findsNothing);
    expect(find.text('Your cart is empty'), findsNothing);
  });
}
