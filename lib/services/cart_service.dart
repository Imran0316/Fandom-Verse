import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_docs.dart';
import '../models/catalog_docs.dart';
import 'auth_service.dart';

class CartService {
  CartService._();

  static final CartService instance = CartService._();

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _orders =>
      FirebaseFirestore.instance.collection('orders');

  DocumentReference<Map<String, dynamic>> _cartItem(String uid, String id) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart')
          .doc(id);

  CollectionReference<Map<String, dynamic>> _cart(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('cart');

  /* ---------------------------------- Cart --------------------------------- */

  Stream<List<CartItemDoc>> watchCart() {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(const []);
    return _cart(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CartItemDoc.fromDoc).toList());
  }

  Stream<int> watchCartCount() {
    return watchCart().map((items) {
      var n = 0;
      for (final i in items) {
        n += i.quantity;
      }
      return n;
    });
  }

  Future<void> addToCart(MerchProductDoc product, {int qty = 1}) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    if (!product.active) throw StateError('This listing is unavailable.');
    final ref = _cartItem(uid, product.id);
    final snap = await ref.get();
    if (snap.exists) {
      final current = (snap.data()?['quantity'] as num?)?.toInt() ?? 1;
      await ref.update({'quantity': current + qty});
    } else {
      await ref.set({
        'name': product.name,
        'priceLabel': product.priceLabel,
        'priceCents': parsePriceToCents(product.priceLabel),
        'quantity': qty,
        'sellerUid': product.sellerUid,
        'sellerName': product.sellerName,
        'emoji': product.emoji,
        'colorName': product.colorName,
        'imageUrl': product.imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setQuantity(String productId, int qty) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    if (qty <= 0) {
      await removeFromCart(productId);
      return;
    }
    await _cartItem(uid, productId).update({'quantity': qty});
  }

  Future<void> removeFromCart(String productId) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    await _cartItem(uid, productId).delete();
  }

  Future<void> clearCart() async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    final snap = await _cart(uid).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /* --------------------------------- Orders -------------------------------- */

  Stream<List<OrderDoc>> watchMyOrders() {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(const []);
    // Avoid composite index (buyerUid + createdAt) — filter client-side.
    return _orders.orderBy('createdAt', descending: true).snapshots().map((s) {
      final items = s.docs.map(OrderDoc.fromDoc).toList();
      return items.where((o) => o.buyerUid == uid).toList();
    });
  }

  /// Places an order from the current cart, clears cart on success.
  Future<String> checkout({required String shipTo}) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final address = shipTo.trim();
    if (address.length < 8) {
      throw ArgumentError('Enter a full shipping address.');
    }

    final cartSnap = await _cart(uid).get();
    final items = cartSnap.docs.map(CartItemDoc.fromDoc).toList();
    if (items.isEmpty) throw StateError('Your cart is empty.');

    var total = 0;
    for (final i in items) {
      total += i.lineTotalCents;
    }

    final buyerName = AuthService.instance.greetingName;
    final ref = await _orders.add({
      'buyerUid': uid,
      'buyerName': buyerName,
      'items': items
          .map(
            (i) => {
              'productId': i.productId,
              'name': i.name,
              'priceLabel': i.priceLabel,
              'priceCents': i.priceCents,
              'quantity': i.quantity,
              'sellerUid': i.sellerUid,
              'sellerName': i.sellerName,
              'emoji': i.emoji,
              'colorName': i.colorName,
              'imageUrl': i.imageUrl,
            },
          )
          .toList(),
      'totalCents': total,
      'status': OrderStatus.paid.name,
      'shipTo': address,
      'createdAt': FieldValue.serverTimestamp(),
      'paidAt': FieldValue.serverTimestamp(),
    });

    await clearCart();
    return ref.id;
  }
}
