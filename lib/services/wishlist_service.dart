import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_docs.dart';
import 'auth_service.dart';

/// Fan → Wishlist → product ids. Explicitly separate from both the cart
/// (a purchase queue) and content bookmarks (the Saved shelf): wishlisting
/// never moves money or stock.
class WishlistService {
  WishlistService._();

  static final WishlistService instance = WishlistService._();

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('wishlist');

  /// Product ids the current fan has wishlisted, newest last.
  Stream<List<String>> watchMyProductIds() {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(const []);
    return _col(uid).snapshots().map((s) => s.docs.map((d) => d.id).toList());
  }

  /// Adds or removes [product]. Returns the new saved state.
  Future<bool> toggle(MerchProductDoc product) async {
    final uid = _uid;
    if (!_ready || uid == null) {
      throw StateError('Sign in to save items to your wishlist.');
    }
    final ref = _col(uid).doc(product.id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set({
      'productId': product.id,
      'savedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Future<void> remove(String productId) async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    await _col(uid).doc(productId).delete();
  }
}
