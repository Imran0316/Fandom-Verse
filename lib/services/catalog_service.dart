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
    return _categories.orderBy('sortOrder').snapshots().map(
          (s) => s.docs.map(FandomCategoryDoc.fromDoc).toList(),
        );
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
    return _events.orderBy('startAt').snapshots().map(
          (s) => s.docs.map(FandomEventDoc.fromDoc).toList(),
        );
  }

  Future<void> upsertEvent({
    String? id,
    required String title,
    required String city,
    required String dateLabel,
    required String iconName,
    required String colorName,
    DateTime? startAt,
  }) async {
    final data = {
      'title': title.trim(),
      'city': city.trim(),
      'dateLabel': dateLabel.trim(),
      'iconName': iconName,
      'colorName': colorName,
      'startAt': startAt != null ? Timestamp.fromDate(startAt) : null,
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
    Query<Map<String, dynamic>> q = _merch.orderBy('createdAt', descending: true);
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

  Future<void> createMerch({
    required String name,
    required String priceLabel,
    required String sellerUid,
    required String sellerName,
    String emoji = '✨',
    String colorName = 'red',
    String description = '',
    String? imageUrl,
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMerch(String id, Map<String, dynamic> data) =>
      _merch.doc(id).set(data, SetOptions(merge: true));

  Future<void> setMerchActive(String id, bool active) =>
      _merch.doc(id).update({'active': active});

  Future<void> deleteMerch(String id) => _merch.doc(id).delete();
}
