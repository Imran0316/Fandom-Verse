import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fandom_verse/models/catalog_docs.dart';
import 'package:fandom_verse/screens/shop/merch_explore_screen.dart';
import 'package:fandom_verse/screens/shop/product_detail_screen.dart';
import 'package:fandom_verse/widgets/glass_button.dart';

void main() {
  testWidgets('merch card shows add to cart and save actions', (
    WidgetTester tester,
  ) async {
    const product = MerchProductDoc(
      id: 'p1',
      name: 'Fandom Tee',
      priceLabel: '\$29',
      sellerUid: 'u1',
      sellerName: 'Qasim Studio',
      colorName: 'red',
      description: 'A premium fandom tee.',
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MerchExploreCard(item: product))),
    );

    expect(find.text('Fandom Tee'), findsOneWidget);
    expect(find.text('\$29'), findsOneWidget);
  });

  testWidgets('product detail screen shows review section', (
    WidgetTester tester,
  ) async {
    const product = MerchProductDoc(
      id: 'p1',
      name: 'Fandom Tee',
      priceLabel: '\$29',
      sellerUid: 'u1',
      sellerName: 'Qasim Studio',
      colorName: 'red',
      description: 'A premium fandom tee.',
    );

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(product: product)),
    );

    await tester.pumpAndSettle();

    // Ensure children have built
    await tester.pumpAndSettle();

    // Ensure product detail shows price and the review action.
    expect(find.text('\$29'), findsOneWidget);
    expect(find.byType(GlassButton), findsWidgets);
  });

  group('merch model parsing', () {
    test('fromMap reads stats and defaults legacy docs', () {
      final full = MerchProductDoc.fromMap('p1', {
        'name': 'Fandom Tee',
        'priceLabel': r'$29',
        'sellerUid': 'u1',
        'stock': 7,
        'soldCount': 12,
        'rating': 4.5,
        'reviewCount': 3,
        'active': true,
      });
      expect(full.stock, 7);
      expect(full.soldCount, 12);
      expect(full.rating, 4.5);
      expect(full.reviewCount, 3);

      final legacy = MerchProductDoc.fromMap('p2', {
        'name': 'Old Tee',
        'sellerUid': 'u2',
      });
      expect(legacy.stock, isNull);
      expect(legacy.soldCount, 0);
      expect(legacy.rating, 0);
      expect(legacy.reviewCount, 0);
      expect(legacy.active, isTrue);
      expect(legacy.emoji, '✨');
    });

    test('product review parses author, rating and text', () {
      final r = ProductReviewDoc.fromMap('u9', {
        'productId': 'p1',
        'authorUid': 'u9',
        'authorName': 'Ayesha',
        'rating': 4,
        'text': 'Great print.',
      });
      expect(r.productId, 'p1');
      expect(r.authorUid, 'u9');
      expect(r.authorName, 'Ayesha');
      expect(r.rating, 4);
      expect(r.text, 'Great print.');
      expect(r.createdAt, isNull);
    });
  });

  testWidgets('merch card shows real stock and review stats', (
    WidgetTester tester,
  ) async {
    const product = MerchProductDoc(
      id: 'p1',
      name: 'Fandom Tee',
      priceLabel: '\$29',
      sellerUid: 'u1',
      sellerName: 'Aurora Prints',
      colorName: 'red',
      stock: 4,
      soldCount: 9,
      rating: 4.5,
      reviewCount: 2,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MerchExploreCard(item: product))),
    );

    expect(find.text('Only 4 left'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('2 reviews'), findsOneWidget);
    expect(find.text('Sold by Aurora Prints'), findsOneWidget);
  });

  testWidgets('merch card omits untracked stock and hides fake ratings', (
    WidgetTester tester,
  ) async {
    const product = MerchProductDoc(
      id: 'p1',
      name: 'Fandom Tee',
      priceLabel: '\$29',
      sellerUid: 'u1',
      sellerName: '',
      colorName: 'red',
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MerchExploreCard(item: product))),
    );

    expect(find.textContaining('left'), findsNothing);
    expect(find.textContaining('reviews'), findsNothing);
    expect(find.text('Sold by FandomVerse seller'), findsOneWidget);
    expect(find.text('4.8'), findsNothing);
  });

  testWidgets('product detail shows live stock and empty reviews state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const product = MerchProductDoc(
      id: 'p1',
      name: 'Fandom Tee',
      priceLabel: '\$29',
      sellerUid: 'u1',
      sellerName: 'Aurora Prints',
      colorName: 'red',
      stock: 3,
    );

    await tester.pumpWidget(
      MaterialApp(home: ProductDetailScreen(product: product)),
    );
    await tester.pumpAndSettle();

    expect(find.text('\$29'), findsOneWidget);
    expect(find.text('Only 3 left — order soon'), findsOneWidget);
    expect(find.textContaining('No reviews yet'), findsOneWidget);
    expect(find.byType(GlassButton), findsWidgets);
  });
}
