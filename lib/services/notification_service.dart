import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/streams.dart';
import '../models/notification_docs.dart';
import 'auth_service.dart';

/// Notification center for Fandom Verse.
/// In-app notifications live under `users/{uid}/notifications`, while FCM is used
/// for push delivery and deep links on mobile devices.
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

  static String followId(String actorUid) => 'follow_$actorUid';

  DocumentReference<Map<String, dynamic>> docFor(
    String recipientUid, {
    String? id,
  }) => id == null ? _for(recipientUid).doc() : _for(recipientUid).doc(id);

  Future<void> initialize() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && _uid != null) {
        await _registerDeviceToken(token);
      }
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FCM foreground message received: ${message.messageId}');
      });
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('FCM app opened via notification: ${message.data}');
      });
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Initial FCM message: ${initialMessage.data}');
      }
    } catch (error) {
      debugPrint('NotificationService.initialize failed: $error');
    }
  }

  static Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
    debugPrint('FCM background message: ${message.data}');
  }

  Future<void> _registerDeviceToken(String token) async {
    final uid = _uid;
    if (uid == null || !_ready) return;
    final deviceId = 'android';
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId);
    await ref.set({
      'token': token,
      'platform': 'android',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> data({
    required String recipientUid,
    required String actorUid,
    required String actorName,
    String? actorAvatarUrl,
    required String type,
    String? title,
    String? body,
    String? imageUrl,
    String? postId,
    String? commentId,
    String? communityId,
    String? communityName,
    String? preview,
    String? targetType,
    String? targetId,
    String? contentId,
    String? fandomId,
    String? priority,
    Map<String, dynamic>? data,
  }) {
    return {
      'recipientUid': recipientUid,
      'actorUid': actorUid,
      'actorName': actorName,
      'actorAvatarUrl': actorAvatarUrl,
      'type': type,
      'title': title ?? 'Fandom Verse',
      'body': body ?? preview ?? 'New activity',
      'imageUrl': imageUrl,
      'postId': postId,
      'commentId': commentId,
      'communityId': communityId,
      'communityName': communityName,
      'preview': preview ?? body,
      'targetType': targetType,
      'targetId': targetId,
      'contentId': contentId,
      'fandomId': fandomId,
      'priority': priority ?? 'normal',
      'data': data ?? const {},
      'read': false,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String _contentNotificationId(String contentId, String userId) =>
      'content_${contentId}_$userId';

  String _communityNotificationId(
    String communityId,
    String userId,
    String eventKey,
  ) => 'community_${communityId}_${eventKey}_$userId';

  Future<void> notifyPublishedContent({
    required String contentId,
    required String title,
    required String body,
    required String fandomId,
    String? imageUrl,
    String? fandomName,
  }) async {
    if (!_ready || contentId.isEmpty || fandomId.isEmpty) return;
    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('selectedFandoms', arrayContains: fandomId)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    var writes = 0;
    for (final user in users.docs) {
      final uid = user.id;
      final prefs =
          (user.data()['notificationPreferences'] as Map?) ?? const {};
      final pushEnabled = (prefs['pushEnabled'] as bool?) ?? true;
      final contentEnabled = (prefs['contentEnabled'] as bool?) ?? true;
      final fandomEnabled = (prefs['fandomEnabled'] as bool?) ?? true;
      if (!pushEnabled || !contentEnabled || !fandomEnabled) continue;
      final docId = _contentNotificationId(contentId, uid);
      batch.set(
        _for(uid).doc(docId),
        data(
          recipientUid: uid,
          actorUid: 'system',
          actorName: 'Fandom Verse',
          type: NotificationType.fandomContent.value,
          title: fandomName != null && fandomName.isNotEmpty
              ? 'New $fandomName update'
              : 'New fandom update',
          body: body,
          imageUrl: imageUrl,
          targetType: NotificationTargetType.content.name,
          targetId: contentId,
          contentId: contentId,
          fandomId: fandomId,
          priority: 'normal',
          data: {'contentId': contentId, 'fandomId': fandomId},
        ),
      );
      writes++;
    }
    if (writes > 0) {
      await batch.commit();
    }
  }

  Future<void> notifyCommunityAnnouncement({
    required String communityId,
    required String eventKey,
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    if (!_ready || communityId.isEmpty) return;
    final members = await FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    var writes = 0;
    for (final member in members.docs) {
      final uid = member.id;
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final prefs =
          (profile.data()?['notificationPreferences'] as Map?) ?? const {};
      final pushEnabled = (prefs['pushEnabled'] as bool?) ?? true;
      final communityEnabled = (prefs['communityEnabled'] as bool?) ?? true;
      if (!pushEnabled || !communityEnabled) continue;
      batch.set(
        _for(uid).doc(_communityNotificationId(communityId, uid, eventKey)),
        data(
          recipientUid: uid,
          actorUid: 'system',
          actorName: 'Community Update',
          type: NotificationType.communityAnnouncement.value,
          title: title,
          body: body,
          imageUrl: imageUrl,
          communityId: communityId,
          targetType: NotificationTargetType.community.name,
          targetId: communityId,
          fandomId: null,
          priority: 'normal',
          data: {'communityId': communityId, 'eventKey': eventKey},
        ),
      );
      writes++;
    }
    if (writes > 0) {
      await batch.commit();
    }
  }

  Future<void> notifyAdminAnnouncement({
    required String title,
    required String body,
    String? imageUrl,
    List<String>? recipientUids,
  }) async {
    if (!_ready) return;
    final recipients =
        recipientUids ??
        (await FirebaseFirestore.instance.collection('users').get()).docs
            .map((d) => d.id)
            .toList();
    final batch = FirebaseFirestore.instance.batch();
    var writes = 0;
    for (final uid in recipients) {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final prefs =
          (profile.data()?['notificationPreferences'] as Map?) ?? const {};
      final pushEnabled = (prefs['pushEnabled'] as bool?) ?? true;
      final announcementEnabled =
          (prefs['announcementEnabled'] as bool?) ?? true;
      if (!pushEnabled || !announcementEnabled) continue;
      batch.set(
        _for(uid).doc('admin_${DateTime.now().millisecondsSinceEpoch}_$uid'),
        data(
          recipientUid: uid,
          actorUid: 'system',
          actorName: 'Fandom Verse',
          type: NotificationType.adminAnnouncement.value,
          title: title,
          body: body,
          imageUrl: imageUrl,
          targetType: NotificationTargetType.announcement.name,
          targetId: 'platform',
          priority: 'high',
          data: {'kind': 'adminAnnouncement'},
        ),
      );
      writes++;
    }
    if (writes > 0) {
      await batch.commit();
    }
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

  Stream<int> watchUnreadCount() {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(0);
    return _for(
      uid,
    ).where('read', isEqualTo: false).snapshots().map((s) => s.docs.length);
  }

  Future<void> markRead(String id) async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    try {
      await _for(uid).doc(id).update({'read': true, 'isRead': true});
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
      batch.update(_for(uid).doc(n.id), {'read': true, 'isRead': true});
    }
    try {
      await batch.commit();
    } catch (_) {
      // Best effort — unread badges reconcile from the stream.
    }
  }
}
