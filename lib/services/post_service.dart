import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post_docs.dart';
import 'auth_service.dart';

class PostService {
  PostService._();

  static final PostService instance = PostService._();

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('posts');

  DocumentReference<Map<String, dynamic>> _doc(String postId) => _col.doc(postId);

  CollectionReference<Map<String, dynamic>> _likes(String postId) =>
      _doc(postId).collection('likes');
  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _doc(postId).collection('comments');
  CollectionReference<Map<String, dynamic>> _reposts(String postId) =>
      _doc(postId).collection('reposts');

  DocumentReference<Map<String, dynamic>> _community(String communityId) =>
      FirebaseFirestore.instance.collection('communities').doc(communityId);

  /* --------------------------------- Feed --------------------------------- */

  Stream<List<PostDoc>> watchFeed({int limit = 40}) {
    if (!_ready) return Stream.value(const []);
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PostDoc.fromDoc).toList());
  }

  Stream<List<PostDoc>> watchCommunityFeed(String communityId, {int limit = 40}) {
    if (!_ready) return Stream.value(const []);
    // Avoid composite index (communityId + createdAt) — filter client-side.
    return _col.orderBy('createdAt', descending: true).limit(limit * 3).snapshots().map((s) {
      final items = s.docs.map(PostDoc.fromDoc).toList();
      return items.where((p) => p.communityId == communityId).take(limit).toList();
    });
  }

  Future<void> createPost({
    required String body,
    String? communityId,
    String? communityName,
    String? authorName,
    String? authorAvatarUrl,
    String? imageUrl,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final text = body.trim();
    if (text.isEmpty && imageUrl == null) {
      throw ArgumentError('Post cannot be empty.');
    }
    final ref = _col.doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(ref, {
      'authorUid': uid,
      'authorName': authorName ?? AuthService.instance.greetingName,
      'authorAvatarUrl': authorAvatarUrl,
      'body': text,
      'communityId': communityId,
      'communityName': communityName,
      'likeCount': 0,
      'commentCount': 0,
      'repostCount': 0,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (communityId != null && communityId.isNotEmpty) {
      batch.update(_community(communityId), {
        'postCount': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  Future<void> deletePost(String postId) async {
    final snap = await _doc(postId).get();
    final communityId = snap.data()?['communityId'] as String?;
    if (communityId == null || communityId.isEmpty) {
      await _doc(postId).delete();
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_doc(postId));
    batch.update(_community(communityId), {
      'postCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<void> adminDeletePost(String postId) => deletePost(postId);

  /* -------------------------------- Actions ------------------------------- */

  Stream<bool> watchLiked(String postId) {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(false);
    return _likes(postId).doc(uid).snapshots().map((s) => s.exists);
  }

  Stream<bool> watchReposted(String postId) {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(false);
    return _reposts(postId).doc(uid).snapshots().map((s) => s.exists);
  }

  Future<void> toggleLike(String postId) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final ref = _likes(postId).doc(uid);
    final snap = await ref.get();
    final batch = FirebaseFirestore.instance.batch();
    if (snap.exists) {
      batch.delete(ref);
      batch.update(_doc(postId), {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(ref, {'uid': uid, 'at': FieldValue.serverTimestamp()});
      batch.update(_doc(postId), {'likeCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<void> toggleRepost(String postId) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final ref = _reposts(postId).doc(uid);
    final snap = await ref.get();
    final batch = FirebaseFirestore.instance.batch();
    if (snap.exists) {
      batch.delete(ref);
      batch.update(_doc(postId), {'repostCount': FieldValue.increment(-1)});
    } else {
      batch.set(ref, {'uid': uid, 'at': FieldValue.serverTimestamp()});
      batch.update(_doc(postId), {'repostCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  /* ------------------------------- Comments ------------------------------- */

  Stream<List<PostCommentDoc>> watchComments(String postId) {
    if (!_ready) return Stream.value(const []);
    return _comments(postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PostCommentDoc.fromDoc).toList());
  }

  Future<void> addComment(
    String postId,
    String body, {
    String? imageUrl,
    String? authorName,
    String? authorAvatarUrl,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final text = body.trim();
    if (text.isEmpty && imageUrl == null) return;
    final batch = FirebaseFirestore.instance.batch();
    final ref = _comments(postId).doc();
    batch.set(ref, {
      'authorUid': uid,
      'authorName': authorName ?? AuthService.instance.greetingName,
      'authorAvatarUrl': authorAvatarUrl,
      'body': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_doc(postId), {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_comments(postId).doc(commentId));
    batch.update(_doc(postId), {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }
}
