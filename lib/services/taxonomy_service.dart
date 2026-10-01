import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/content_docs.dart';
import 'auth_service.dart';

/// Admin-managed reference data for V1 content: fandoms and content
/// categories. Both collections are readable by any signed-in user and
/// writable by admins only (enforced in firestore.rules).
class TaxonomyService {
  TaxonomyService._();

  static final TaxonomyService instance = TaxonomyService._();

  bool get _ready => AuthService.firebaseReady;

  CollectionReference<Map<String, dynamic>> get _fandoms =>
      FirebaseFirestore.instance.collection('fandoms');
  CollectionReference<Map<String, dynamic>> get _categories =>
      FirebaseFirestore.instance.collection('contentCategories');

  /* -------------------------------- Fandoms ------------------------------- */

  Stream<List<FandomDoc>> watchFandoms() {
    if (!_ready) return Stream.value(const []);
    return _fandoms.orderBy('sortOrder').limit(60).snapshots().map(
          (s) => s.docs.map(FandomDoc.fromDoc).toList(),
        );
  }

  Future<void> upsertFandom({
    String? id,
    required String name,
    required String iconName,
    required String colorName,
    String? coverImageUrl,
    int sortOrder = 99,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'iconName': iconName,
      'colorName': colorName,
      'coverImageUrl': coverImageUrl,
      'sortOrder': sortOrder,
    };
    if (id == null || id.isEmpty) {
      await _fandoms.add(data);
    } else {
      await _fandoms.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteFandom(String id) => _fandoms.doc(id).delete();

  /* ------------------------- Content categories -------------------------- */

  Stream<List<ContentCategoryDoc>> watchCategories() {
    if (!_ready) return Stream.value(const []);
    return _categories.orderBy('sortOrder').snapshots().map(
          (s) => s.docs.map(ContentCategoryDoc.fromDoc).toList(),
        );
  }

  Future<void> upsertCategory({
    String? id,
    required String name,
    required String iconName,
    required String colorName,
    int sortOrder = 99,
  }) async {
    final data = <String, dynamic>{
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

  /* --------------------------------- Seed --------------------------------- */

  static const _defaultFandoms = <(String, String, String)>[
    ('Anime', 'anime', 'rose'),
    ('Manga', 'book', 'amber'),
    ('Gaming', 'gaming', 'green'),
    ('Movies & TV', 'movies', 'blue'),
    ('Comics', 'comics', 'purple'),
    ('Music', 'music', 'pink'),
    ('Sports', 'sports', 'cyan'),
    ('Tech', 'tech', 'indigo'),
  ];

  static const _defaultCategories = <(String, String, String)>[
    ('Guides', 'book', 'blue'),
    ('Trivia', 'star', 'amber'),
    ('Characters', 'grid', 'purple'),
    ('World Building', 'explore', 'teal'),
    ('News', 'event', 'red'),
    ('Reviews', 'brush', 'green'),
  ];

  /// Seeds default fandoms + content categories when the collections are empty.
  /// Safe to call repeatedly; only admins can write.
  Future<void> seedDefaultsIfEmpty() async {
    if (!_ready) return;

    final fandomSnap = await _fandoms.limit(1).get();
    if (fandomSnap.docs.isEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < _defaultFandoms.length; i++) {
        final (name, icon, color) = _defaultFandoms[i];
        batch.set(_fandoms.doc(), {
          'name': name,
          'iconName': icon,
          'colorName': color,
          'coverImageUrl': null,
          'sortOrder': i,
        });
      }
      await batch.commit();
    }

    final categorySnap = await _categories.limit(1).get();
    if (categorySnap.docs.isEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < _defaultCategories.length; i++) {
        final (name, icon, color) = _defaultCategories[i];
        batch.set(_categories.doc(), {
          'name': name,
          'iconName': icon,
          'colorName': color,
          'sortOrder': i,
        });
      }
      await batch.commit();
    }
  }
}
