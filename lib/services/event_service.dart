import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_docs.dart';
import 'auth_service.dart';
import 'catalog_service.dart';

/// Repository for the full event flow: browsing, detail, and RSVP toggling.
class EventService {
  EventService._();

  static final EventService instance = EventService._();

  bool get _ready => AuthService.firebaseReady;

  CollectionReference<Map<String, dynamic>> get _events =>
      FirebaseFirestore.instance.collection('events');

  /// All events, newest start date first.
  Stream<List<FandomEventDoc>> watchAll() {
    return CatalogService.instance.watchEvents();
  }

  /// Upcoming events: startAt in the future, closest first.
  Stream<List<FandomEventDoc>> watchUpcoming() {
    return CatalogService.instance.watchUpcomingEvents();
  }

  /// Search across title / city / description / location label.
  Stream<List<FandomEventDoc>> search(String query) {
    return CatalogService.instance.searchEvents(query);
  }

  Future<FandomEventDoc?> getById(String id) {
    return CatalogService.instance.fetchEvent(id);
  }

  Future<bool> hasRsvped(String eventId) async {
    if (!_ready) return false;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;
    final snapshot = await _events
        .doc(eventId)
        .collection('rsvps')
        .doc(uid)
        .get();
    return snapshot.exists;
  }

  /// Toggle the current user's RSVP on an event. Increments/decrements the
  /// event's `rsvpCount` by exactly ±1 per Firestore rules (counterOnly).
  Future<bool> toggleRsvp(String eventId) async {
    if (!_ready) return false;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return false;

    final eventRef = _events.doc(eventId);
    final rsvpRef = eventRef.collection('rsvps').doc(uid);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      if (!eventSnapshot.exists ||
          (eventSnapshot.data()?['isActive'] as bool? ?? true) == false) {
        throw StateError('This event is no longer available.');
      }
      final rsvpSnapshot = await transaction.get(rsvpRef);
      final currentCount =
          (eventSnapshot.data()?['rsvpCount'] as num?)?.toInt() ?? 0;
      if (rsvpSnapshot.exists) {
        transaction.delete(rsvpRef);
        transaction.update(eventRef, {
          'rsvpCount': currentCount > 0 ? currentCount - 1 : 0,
        });
        return false;
      }
      transaction.set(rsvpRef, {
        'eventId': eventId,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(eventRef, {'rsvpCount': currentCount + 1});
      return true;
    });
  }
}
