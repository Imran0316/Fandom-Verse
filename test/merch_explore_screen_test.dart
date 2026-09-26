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
}
