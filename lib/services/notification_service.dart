import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/streams.dart';
import '../models/notification_docs.dart';
import 'auth_service.dart';

/// Activity notifications stored at `users/{uid}/notifications`.
///
/// Writes happen inside other services' batches (a like, comment, reply or
/// follow request commits atomically together with its notification). This
/// service owns the stream, read-state management, and the batch-friendly
/// payload builder.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _for(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

  /// Deterministic id for follow-request notifications: resending the
  /// request upserts the same doc, and accept / decline / cancel can just
  /// delete it by name.
  static String followId(String actorUid) => 'follow_$actorUid';

  DocumentReference<Map<String, dynamic>> docFor(
    String recipientUid, {
    String? id,
  }) =>
      id == null ? _for(recipientUid).doc() : _for(recipientUid).doc(id);

  /// Batch-friendly notification payload. `actorUid` must be the caller
  /// (rules enforce it) — never build one for someone else's action.
  Map<String, dynamic> data({
    required String recipientUid,
    required String actorUid,
    required String actorName,
    String? actorAvatarUrl,
    required String type,
    String? postId,
    String? commentId,
    String? communityId,
    String? communityName,
    String? preview,
  }) {
    return {
      'recipientUid': recipientUid,
      'actorUid': actorUid,
      'actorName': actorName,
      'actorAvatarUrl': actorAvatarUrl,
      'type': type,
      'postId': postId,
      'commentId': commentId,
      'communityId': communityId,
      'communityName': communityName,
      'preview': preview,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Stream<List<NotificationDoc>> watch({int limit = 50}) {
    final uid = _uid;
    if (!_ready || uid == null) return onceStream(const []);
    return _for(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(NotificationDoc.fromDoc).toList());
  }

  Future<void> markRead(String id) async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    try {
      await _for(uid).doc(id).update({'read': true});
    } catch (_) {
      // Offline / rules — the next stream emission reconciles.
    }
  }

  Future<void> markAllRead(List<NotificationDoc> items) async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    final unread = items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(_for(uid).doc(n.id), {'read': true});
    }
    try {
      await batch.commit();
    } catch (_) {
      // Best effort — unread badges reconcile from the stream.
    }
  }
}
