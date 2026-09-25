import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_docs.dart';
import 'auth_service.dart';

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('communities');

  DocumentReference<Map<String, dynamic>> _doc(String id) => _col.doc(id);

  CollectionReference<Map<String, dynamic>> _members(String communityId) =>
      _doc(communityId).collection('members');

  /* ------------------------------ Communities ----------------------------- */

  Stream<List<CommunityDoc>> watchAll() {
    if (!_ready) return Stream.value(const []);
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map(CommunityDoc.fromDoc).toList(),
        );
  }

  Stream<CommunityDoc?> watch(String communityId) {
    if (!_ready) return Stream.value(null);
    return _doc(communityId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return CommunityDoc.fromDoc(snap);
    });
  }

  Future<CommunityDoc?> fetch(String communityId) async {
    if (!_ready) return null;
    final snap = await _doc(communityId).get();
    if (!snap.exists) return null;
    return CommunityDoc.fromDoc(snap);
  }

  Future<String> create({
    required String name,
    required String description,
    required String ownerUid,
    required String iconName,
    required String colorName,
    String? profileImageUrl,
    String? coverImageUrl,
  }) async {
    if (!_ready) throw StateError('Firebase is not configured yet.');
    final ref = await _col.add({
      'name': name.trim(),
      'description': description.trim(),
      'ownerUid': ownerUid,
      'iconName': iconName,
      'colorName': colorName,
      'memberCount': 1,
      'postCount': 0,
      'profileImageUrl': profileImageUrl,
      'coverImageUrl': coverImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _members(ref.id).doc(ownerUid).set({
      'role': CommunityRole.owner.value,
      'displayName': AuthService.instance.greetingName,
      'avatarUrl': AuthService.instance.currentUser?.photoURL,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateCommunity(
    String id,
    Map<String, dynamic> data,
  ) => _doc(id).set(data, SetOptions(merge: true));

  Future<void> deleteCommunity(String id) => _doc(id).delete();

  /* -------------------------------- Members ------------------------------- */

  Stream<CommunityMemberDoc?> watchMembership(String communityId) {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(null);
    return _members(communityId).doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return CommunityMemberDoc.fromDoc(snap);
    });
  }

  Stream<List<CommunityMemberDoc>> watchMembers(String communityId) {
    if (!_ready) return Stream.value(const []);
    return _members(communityId).orderBy('joinedAt').snapshots().map(
          (s) => s.docs.map(CommunityMemberDoc.fromDoc).toList(),
        );
  }

  /// Communities the current user belongs to (collectionGroup on members).
  Stream<List<CommunityDoc>> watchJoined() {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collectionGroup('members')
        .where(
          'role',
          whereIn: [
            CommunityRole.owner.value,
            CommunityRole.moderator.value,
            CommunityRole.member.value,
          ],
        )
        .snapshots()
        .asyncMap((memberSnap) async {
      final ids = memberSnap.docs
          .where((d) => d.id == uid)
          .map((d) => d.reference.parent.parent!.id)
          .toSet();
      if (ids.isEmpty) return const <CommunityDoc>[];
      final all = await _col.get();
      return all.docs
          .map(CommunityDoc.fromDoc)
          .where((c) => ids.contains(c.id))
          .toList();
    });
  }

  /// Membership docs for the signed-in user across all communities.
  Stream<List<CommunityMemberDoc>> watchMyMemberships() {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collectionGroup('members')
        .where(
          'role',
          whereIn: [
            CommunityRole.owner.value,
            CommunityRole.moderator.value,
            CommunityRole.member.value,
          ],
        )
        .snapshots()
        .map((snap) {
      return snap.docs
          .where((d) => d.id == uid)
          .map(CommunityMemberDoc.fromDoc)
          .toList();
    });
  }

  Future<void> join({
    required String communityId,
    required String displayName,
    String? avatarUrl,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');

    final memberRef = _members(communityId).doc(uid);
    final existing = await memberRef.get();
    if (existing.exists) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.set(memberRef, {
      'role': CommunityRole.member.value,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_doc(communityId), {'memberCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> leave(String communityId) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final member = await _members(communityId).doc(uid).get();
    if (!member.exists) return;
    final role = CommunityRole.fromString(member.data()?['role'] as String?);
    if (role == CommunityRole.owner) {
      throw StateError('Owners cannot leave. Transfer or delete the community.');
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_members(communityId).doc(uid));
    batch.update(_doc(communityId), {'memberCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> setMemberRole(
    String communityId,
    String memberUid,
    CommunityRole role,
  ) => _members(communityId).doc(memberUid).update({'role': role.value});

  Future<void> removeMember(String communityId, String memberUid) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_members(communityId).doc(memberUid));
    batch.update(_doc(communityId), {'memberCount': FieldValue.increment(-1)});
    await batch.commit();
  }
}
