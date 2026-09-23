import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';

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
}
