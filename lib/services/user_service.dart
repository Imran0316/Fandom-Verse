import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/follow_docs.dart';
import '../models/notification_docs.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  static const String collection = 'users';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(collection);

  DocumentReference<Map<String, dynamic>> docFor(String uid) =>
      _col.doc(uid);

  Future<bool> get _ready async {
    if (!AuthService.firebaseReady) return false;
    return true;
  }

  Future<UserProfile?> fetch(String uid) async {
    if (!await _ready) return null;
    final snap = await docFor(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromDoc(snap);
  }

  /// Creates the users/{uid} doc on first sign-in / sign-up.
  /// Safe to call every time — will not downgrade an existing role.
  /// Never throws: auth succeeds even if Firestore is offline/disabled.
  Future<UserProfile?> ensureProfile(User user) async {
    if (!await _ready) return null;
    try {
      final ref = docFor(user.uid);
      final snap = await ref.get();
      if (snap.exists) {
        return UserProfile.fromDoc(snap);
      }

      final fallbackName = (user.displayName != null &&
              user.displayName!.trim().isNotEmpty)
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Fan');

      final profile = UserProfile(
        uid: user.uid,
        name: fallbackName,
        email: user.email ?? '',
        role: UserRole.fan,
        createdAt: DateTime.now(),
      );

      await ref.set(profile.toMap());
      return profile;
    } catch (_) {
      return null;
    }
  }

  /// Fiverr-style self-serve upgrade: fan → seller. No admin approval.
  /// Admins are never created through this path.
  Future<UserProfile> upgradeToSeller({
    required String uid,
    required String shopName,
    String? bio,
  }) async {
    if (!await _ready) {
      throw StateError('Firebase is not configured yet.');
    }
    final name = shopName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Shop name is required.');
    }

    final ref = docFor(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Profile not found. Sign in again.');
    }

    final current = UserProfile.fromDoc(snap);
    if (current.isAdmin || current.isSeller) {
      return current;
    }
    if (current.role != UserRole.fan) {
      throw StateError('Only fan accounts can upgrade to seller.');
    }

    final update = <String, dynamic>{
      'role': UserRole.seller.value,
      'shopName': name,
    };
    final cleanedBio = bio?.trim();
    if (cleanedBio != null && cleanedBio.isNotEmpty) {
      update['bio'] = cleanedBio;
    }
    await ref.update(update);

    return current.copyWith(role: UserRole.seller, shopName: name, bio: bio);
  }

  Future<void> updateProfile(
    String uid, {
    String? name,
    String? bio,
    String? avatarUrl,
    List<String>? selectedFandoms,
  }) async {
    if (!await _ready) return;
    final data = <String, dynamic>{};
    final cleanedName = name?.trim();
    if (cleanedName != null && cleanedName.isNotEmpty) {
      data['name'] = cleanedName;
    }
    if (bio != null) data['bio'] = bio.trim();
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (selectedFandoms != null) data['selectedFandoms'] = selectedFandoms;
    if (data.isEmpty) return;
    await docFor(uid).update(data);
  }

  /// Promote / demote. Firestore rules enforce the caller is an admin
  /// (self-serve fan → seller is handled by [upgradeToSeller]).
  Future<void> setRole(String uid, UserRole role) async {
    if (!await _ready) return;
    await docFor(uid).update({'role': role.value});
  }

  /// UI helper: current signed-in profile (does not cache).
  Future<UserProfile?> currentProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;
    return fetch(user.uid);
  }

  Stream<UserProfile?> watch(String uid) {
    if (!AuthService.firebaseReady) {
      return Stream.value(null);
    }
    return docFor(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromDoc(snap);
    });
  }

  Stream<UserProfile?> watchCurrent() {
    final user = AuthService.instance.currentUser;
    if (user == null) return Stream.value(null);
    return watch(user.uid);
  }

  /// Admin console: all profiles ordered by signup.
  Stream<List<UserProfile>> watchAll() {
    if (!AuthService.firebaseReady) {
      return Stream.value(const []);
    }
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(UserProfile.fromDoc).toList(),
        );
  }

  Future<int> countCollection(String name) async {
    if (!await _ready) return 0;
    final agg = await FirebaseFirestore.instance
        .collection(name)
        .count()
        .get();
    return agg.count ?? 0;
  }

  /* ------------------------------ Follow system ------------------------------ */

  CollectionReference<Map<String, dynamic>> _followersOf(String uid) =>
      _col.doc(uid).collection('followers');

  CollectionReference<Map<String, dynamic>> _followingOf(String uid) =>
      _col.doc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> _requestsOf(String uid) =>
      _col.doc(uid).collection('followRequests');

  Future<String?> _requireUid() async {
    if (!await _ready) return null;
    return AuthService.instance.currentUser?.uid;
  }

  /// Viewer → target: creates a pending follow request on the target's doc
  /// and drops a follow-request notification in their inbox (same batch —
  /// deterministic `follow_{actor}` id, so a resend upserts, never dups).
  Future<void> sendFollowRequest(String targetUid) async {
    final myUid = await _requireUid();
    if (myUid == null) throw StateError('Sign in required.');
    if (myUid == targetUid) return;
    final me = await fetch(myUid);
    final at = FieldValue.serverTimestamp();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_requestsOf(targetUid).doc(myUid), {
      'uid': myUid,
      'displayName': me?.name ?? '',
      'avatarUrl': me?.avatarUrl,
      'bio': me?.bio,
      'at': at,
    });
    batch.set(
      NotificationService.instance.docFor(
        targetUid,
        id: NotificationService.followId(myUid),
      ),
      NotificationService.instance.data(
        recipientUid: targetUid,
        actorUid: myUid,
        actorName: me?.name ?? '',
        actorAvatarUrl: me?.avatarUrl,
        type: NotificationKind.followRequested.value,
      ),
    );
    await batch.commit();
  }

  /// Viewer → target: withdraws a request the viewer sent (and the
  /// notification that came with it).
  Future<void> cancelFollowRequest(String targetUid) async {
    final myUid = await _requireUid();
    if (myUid == null) throw StateError('Sign in required.');
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_requestsOf(targetUid).doc(myUid));
    batch.delete(NotificationService.instance.docFor(
      targetUid,
      id: NotificationService.followId(myUid),
    ));
    await batch.commit();
  }

  /// Target → viewer: accepts an inbound request. One batch writes both
  /// edge mirrors, bumps both counters (followerCount on self, and the
  /// other user's followingCount — the ±1 exception in the rules), and
  /// clears the follow-request notification.
  Future<void> acceptFollowRequest(String fromUid) async {
    final myUid = await _requireUid();
    if (myUid == null) throw StateError('Sign in required.');
    final request =
        (await _requestsOf(myUid).doc(fromUid).get()).data() ?? const {};
    final me = await fetch(myUid);
    final at = FieldValue.serverTimestamp();

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_requestsOf(myUid).doc(fromUid));
    batch.delete(NotificationService.instance.docFor(
      myUid,
      id: NotificationService.followId(fromUid),
    ));
    batch.set(_followersOf(myUid).doc(fromUid), {
      'uid': fromUid,
      'displayName': (request['displayName'] as String?) ?? '',
      'avatarUrl': request['avatarUrl'],
      'at': at,
    });
    batch.set(_followingOf(fromUid).doc(myUid), {
      'uid': myUid,
      'displayName': me?.name ?? '',
      'avatarUrl': me?.avatarUrl,
      'at': at,
    });
    batch.update(docFor(myUid), {'followerCount': FieldValue.increment(1)});
    batch.update(docFor(fromUid), {'followingCount': FieldValue.increment(1)});
    await batch.commit();
  }

  /// Target → viewer: declines an inbound request (and its notification).
  Future<void> declineFollowRequest(String fromUid) async {
    final myUid = await _requireUid();
    if (myUid == null) throw StateError('Sign in required.');
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_requestsOf(myUid).doc(fromUid));
    batch.delete(NotificationService.instance.docFor(
      myUid,
      id: NotificationService.followId(fromUid),
    ));
    await batch.commit();
  }

  /// Viewer → target: removes both edge mirrors and both counters.
  Future<void> unfollow(String targetUid) async {
    final myUid = await _requireUid();
    if (myUid == null) throw StateError('Sign in required.');
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_followersOf(targetUid).doc(myUid));
    batch.delete(_followingOf(myUid).doc(targetUid));
    batch.update(docFor(myUid), {'followingCount': FieldValue.increment(-1)});
    batch.update(docFor(targetUid), {'followerCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  /// One-shot checks backing the profile Follow button (no live listeners
  /// for relationships — the button refreshes after each action).
  Future<bool> isFollowing(String targetUid) async {
    final myUid = await _requireUid();
    if (myUid == null || myUid == targetUid) return false;
    return (await _followingOf(myUid).doc(targetUid).get()).exists;
  }

  Future<bool> hasPendingRequestTo(String targetUid) async {
    final myUid = await _requireUid();
    if (myUid == null || myUid == targetUid) return false;
    return (await _requestsOf(targetUid).doc(myUid).get()).exists;
  }

  Future<bool> hasIncomingRequestFrom(String targetUid) async {
    final myUid = await _requireUid();
    if (myUid == null || myUid == targetUid) return false;
    return (await _requestsOf(myUid).doc(targetUid).get()).exists;
  }

  /// Pending inbound requests for the caller (newest first) — inbox screen
  /// and the badge on your own profile.
  Stream<List<FollowDoc>> watchFollowRequests() {
    final myUid = AuthService.instance.currentUser?.uid;
    if (!AuthService.firebaseReady || myUid == null) {
      return Stream.value(const []);
    }
    return _requestsOf(myUid)
        .orderBy('at', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FollowDoc.fromDoc).toList());
  }
}
