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

  Stream<List<FandomEventDoc>> watchEvents({bool activeOnly = true}) {
    if (!_ready) return Stream.value(const []);
    return _events.limit(200).snapshots().map((s) {
      final events = s.docs.map(FandomEventDoc.fromDoc).where((event) {
        return event.title.trim().isNotEmpty && (!activeOnly || event.isActive);
      }).toList();
      events.sort((a, b) {
        final aDate = a.startAt ?? DateTime(9999);
        final bDate = b.startAt ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });
      return events;
    });
  }

  Stream<List<FandomEventDoc>> watchUpcomingEvents() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return watchEvents().map(
      (events) => events
          .where(
            (event) =>
                event.startAt != null && !event.startAt!.isBefore(startOfToday),
          )
          .toList(),
    );
  }

  Stream<List<FandomEventDoc>> searchEvents(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return watchUpcomingEvents();
    return watchUpcomingEvents().map(
      (events) => events.where((event) {
        return [
          event.title,
          event.description,
          event.city,
          event.venue,
          event.address,
          event.eventType,
        ].any((value) => value.toLowerCase().contains(normalized));
      }).toList(),
    );
  }

  Future<FandomEventDoc?> fetchEvent(String id) async {
    if (!_ready || id.isEmpty) return null;
    final snapshot = await _events.doc(id).get();
    if (!snapshot.exists) return null;
    return FandomEventDoc.fromDoc(snapshot);
  }

  Future<void> upsertEvent({
    String? id,
    required String title,
    required String city,
    String dateLabel = '',
    String iconName = 'event',
    String colorName = 'red',
    String? coverImageUrl,
    required DateTime startAt,
    DateTime? endAt,
    String description = '',
    String eventType = 'Other',
    String venue = '',
    String address = '',
    required double latitude,
    required double longitude,
    String? ticketUrl,
    String organizer = '',
    bool isActive = true,
  }) async {
    final cleanTitle = title.trim();
    final cleanCity = city.trim();
    final cleanVenue = venue.trim();
    if (cleanTitle.length < 2) {
      throw const FormatException('Enter an event title.');
    }
    if (cleanCity.isEmpty) {
      throw const FormatException('Enter a city.');
    }
    if (cleanVenue.isEmpty) {
      throw const FormatException('Enter a venue.');
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw const FormatException('Latitude must be between -90 and 90.');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw const FormatException('Longitude must be between -180 and 180.');
    }
    if (endAt != null && !endAt.isAfter(startAt)) {
      throw const FormatException('End time must be after the start time.');
    }
    final cleanTicketUrl = ticketUrl?.trim();
    if (cleanTicketUrl != null && cleanTicketUrl.isNotEmpty) {
      final uri = Uri.tryParse(cleanTicketUrl);
      if (uri == null ||
          !uri.hasAuthority ||
          !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
        throw const FormatException('Enter a valid http or https ticket URL.');
      }
    }
    final cleanImageUrl = coverImageUrl?.trim();
    final event = FandomEventDoc(
      id: id ?? '',
      title: cleanTitle,
      city: cleanCity,
      dateLabel: dateLabel.trim().isNotEmpty
          ? dateLabel.trim()
          : _eventDateLabel(startAt),
      iconName: iconName,
      colorName: colorName,
      coverImageUrl: cleanImageUrl,
      description: description.trim(),
      eventType: eventType.trim().isEmpty ? 'Other' : eventType.trim(),
      venue: cleanVenue,
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
      startAt: startAt,
      endAt: endAt,
      ticketUrl: cleanTicketUrl?.isEmpty == true ? null : cleanTicketUrl,
      organizer: organizer.trim(),
      isActive: isActive,
    );
    final data = event.toMap();
    if (id == null || id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
    } else {
      data.remove('createdAt');
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (id == null || id.isEmpty) {
      await _events.add(data);
    } else {
      await _events.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteEvent(String id) => _events.doc(id).delete();

  String _eventDateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

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
    return _merch
        .doc(productId)
        .snapshots()
        .map((d) => d.exists ? MerchProductDoc.fromDoc(d) : null);
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

    final snap = await _merch.doc(productId).collection('reviews').get();
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
