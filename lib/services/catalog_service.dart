import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_docs.dart';
import 'auth_service.dart';

class CatalogService {
  CatalogService._();

  static final CatalogService instance = CatalogService._();

  bool get _ready => AuthService.firebaseReady;

  CollectionReference<Map<String, dynamic>> get _categories =>
      FirebaseFirestore.instance.collection('categories');
  CollectionReference<Map<String, dynamic>> get _events =>
      FirebaseFirestore.instance.collection('events');
  CollectionReference<Map<String, dynamic>> get _merch =>
      FirebaseFirestore.instance.collection('merch');

  /* ------------------------------ Categories ------------------------------ */

  Stream<List<FandomCategoryDoc>> watchCategories() {
    if (!_ready) return Stream.value(const []);
    return _categories
        .orderBy('sortOrder')
        .snapshots()
        .map((s) => s.docs.map(FandomCategoryDoc.fromDoc).toList());
  }

  Future<void> upsertCategory({
    String? id,
    required String name,
    required String iconName,
    required String colorName,
    int sortOrder = 0,
  }) async {
    final data = {
      'name': name.trim(),
      'iconName': iconName,
      'colorName': colorName,
      'sortOrder': sortOrder,
    };
    if (id == null || id.isEmpty) {
      await _categories.add(data);
    } else {
      await _categories.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteCategory(String id) => _categories.doc(id).delete();

  Future<void> seedCategoriesIfEmpty() async {
    if (!_ready) return;
    final snap = await _categories.limit(1).get();
    if (snap.docs.isNotEmpty) return;
    const defaults = [
      ('Anime & Manga', 'anime', 'rose', 0),
      ('Gaming', 'gaming', 'green', 1),
      ('Movies & TV', 'movies', 'blue', 2),
      ('Comics', 'comics', 'amber', 3),
      ('K-Pop', 'kpop', 'purple', 4),
    ];
    final batch = FirebaseFirestore.instance.batch();
    for (final (name, icon, color, order) in defaults) {
      final ref = _categories.doc();
      batch.set(ref, {
        'name': name,
        'iconName': icon,
        'colorName': color,
        'sortOrder': order,
      });
    }
    await batch.commit();
  }

  /* -------------------------------- Events -------------------------------- */

  Stream<List<FandomEventDoc>> watchEvents() {
    if (!_ready) return Stream.value(const []);
    return _events
        .orderBy('startAt')
        .snapshots()
        .map((s) => s.docs.map(FandomEventDoc.fromDoc).toList());
  }

  Future<void> upsertEvent({
    String? id,
    required String title,
    required String city,
    required String dateLabel,
    required String iconName,
    required String colorName,
    String? coverImageUrl,
    DateTime? startAt,
    String? ticketUrl,
  }) async {
    final ticket = (ticketUrl ?? '').trim();
    final data = {
      'title': title.trim(),
      'city': city.trim(),
      'dateLabel': dateLabel.trim(),
      'iconName': iconName,
      'colorName': colorName,
      'coverImageUrl': coverImageUrl,
      'startAt': startAt != null ? Timestamp.fromDate(startAt) : null,
      'ticketUrl': ticket.isEmpty ? null : ticket,
    };
    if (id == null || id.isEmpty) {
      await _events.add(data);
    } else {
      await _events.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteEvent(String id) => _events.doc(id).delete();

  /* --------------------------------- Merch -------------------------------- */

  Stream<List<MerchProductDoc>> watchMerch({bool activeOnly = true}) {
    if (!_ready) return Stream.value(const []);
    Query<Map<String, dynamic>> q = _merch.orderBy(
      'createdAt',
      descending: true,
    );
    // Firestore can't combine orderBy + where cheaply without index;
    // filter active in memory for simplicity on small catalogs.
    return q.snapshots().map((s) {
      final items = s.docs.map(MerchProductDoc.fromDoc).toList();
      return activeOnly ? items.where((m) => m.active).toList() : items;
    });
  }

  Stream<List<MerchProductDoc>> watchSellerMerch(String sellerUid) {
    if (!_ready) return Stream.value(const []);
    // Equality + orderBy needs a composite index; sort/filter client-side
    // so the seller dashboard works without console setup.
    return _merch.orderBy('createdAt', descending: true).snapshots().map((s) {
      final items = s.docs.map(MerchProductDoc.fromDoc).toList();
      return items.where((m) => m.sellerUid == sellerUid).toList();
    });
  }

  /// Live single product (rating / stock / sold counts update in place).
  /// Emits null when signed out or the product no longer exists.
  Stream<MerchProductDoc?> watchMerchProduct(String productId) {
    if (!_ready) return Stream<MerchProductDoc?>.value(null);
    return _merch.doc(productId).snapshots().map(
          (d) => d.exists ? MerchProductDoc.fromDoc(d) : null,
        );
  }

  Future<void> createMerch({
    required String name,
    required String priceLabel,
    required String sellerUid,
    required String sellerName,
    String emoji = '✨',
    String colorName = 'red',
    String description = '',
    String? imageUrl,
    int? stock,
  }) async {
    await _merch.add({
      'name': name.trim(),
      'priceLabel': priceLabel.trim(),
      'sellerUid': sellerUid,
      'sellerName': sellerName,
      'emoji': emoji,
      'colorName': colorName,
      'description': description.trim(),
      'imageUrl': imageUrl,
      'active': true,
      'stock': stock,
      'soldCount': 0,
      'rating': 0.0,
      'reviewCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMerch(String id, Map<String, dynamic> data) =>
      _merch.doc(id).set(data, SetOptions(merge: true));

  Future<void> setMerchActive(String id, bool active) =>
      _merch.doc(id).update({'active': active});

  Future<void> deleteMerch(String id) => _merch.doc(id).delete();

  /* -------------------------------- Reviews -------------------------------- */

  /// Reviews for a product, newest first (subcollection — no index needed).
  Stream<List<ProductReviewDoc>> watchReviews(String productId) {
    if (!_ready) return Stream.value(const []);
    return _merch
        .doc(productId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ProductReviewDoc.fromDoc).toList());
  }

  /// One review per user per product (doc id = author uid). After writing,
  /// re-reads the review set and rewrites the product's aggregate
  /// `rating` / `reviewCount` — the only fields non-owners may update.
  Future<void> addReview({
    required String productId,
    required int rating,
    required String text,
  }) async {
    if (!_ready) throw StateError('Sign in required.');
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required.');
    final stars = rating.clamp(1, 5).toInt();
    final authorName = AuthService.instance.greetingName;

    final reviewRef = _merch.doc(productId).collection('reviews').doc(uid);
    await reviewRef.set(
      ProductReviewDoc(
        id: uid,
        productId: productId,
        authorUid: uid,
        authorName: authorName.isEmpty ? 'Fan' : authorName,
        rating: stars,
        text: text.trim(),
      ).toMap(),
    );

    final snap =
        await _merch.doc(productId).collection('reviews').get();
    var sum = 0;
    var count = 0;
    for (final d in snap.docs) {
      final r = (d.data()['rating'] as num?)?.toInt() ?? 0;
      if (r >= 1 && r <= 5) {
        sum += r;
        count++;
      }
    }
    await _merch.doc(productId).update({
      'rating': count == 0 ? 0.0 : sum / count,
      'reviewCount': count,
    });
  }
}
