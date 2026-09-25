import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/streams.dart';
import '../models/notification_docs.dart';
import '../models/post_docs.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class PostService {
  PostService._();

  static final PostService instance = PostService._();

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('posts');

  DocumentReference<Map<String, dynamic>> _doc(String postId) => _col.doc(postId);

  /// Short excerpt stored on notifications (keeps docs small).
  String _snippet(String? text, {int max = 90}) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return '';
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

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
    if (!_ready) return onceStream(const []);
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PostDoc.fromDoc).toList());
  }

  Stream<List<PostDoc>> watchCommunityFeed(String communityId, {int limit = 40}) {
    if (!_ready) return onceStream(const []);
    // Avoid composite index (communityId + createdAt) — filter client-side.
    return _col.orderBy('createdAt', descending: true).limit(limit * 3).snapshots().map((s) {
      final items = s.docs.map(PostDoc.fromDoc).toList();
      return items.where((p) => p.communityId == communityId).take(limit).toList();
    });
  }

  /// Posts by one author (profile page). Client-side filter avoids a
  /// composite index on authorUid + createdAt.
  Stream<List<PostDoc>> watchAuthorPosts(String authorUid, {int limit = 40}) {
    if (!_ready) return onceStream(const []);
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit * 3)
        .snapshots()
        .map((s) {
          final items = s.docs.map(PostDoc.fromDoc).toList();
          return items.where((p) => p.authorUid == authorUid).take(limit).toList();
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
      final postSnap = await _doc(postId).get();
      final post = postSnap.data();
      batch.set(ref, {'uid': uid, 'at': FieldValue.serverTimestamp()});
      batch.update(_doc(postId), {'likeCount': FieldValue.increment(1)});
      final authorUid = post?['authorUid'] as String?;
      if (authorUid != null && authorUid.isNotEmpty && authorUid != uid) {
        batch.set(
          NotificationService.instance.docFor(authorUid),
          NotificationService.instance.data(
            recipientUid: authorUid,
            actorUid: uid,
            actorName: AuthService.instance.greetingName,
            actorAvatarUrl: AuthService.instance.currentUser?.photoURL,
            type: NotificationKind.postLiked.value,
            postId: postId,
            communityId: post?['communityId'] as String?,
            communityName: post?['communityName'] as String?,
            preview: _snippet(post?['body'] as String?),
          ),
        );
      }
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
    if (!_ready) return onceStream(const []);
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
    final postSnap = await _doc(postId).get();
    final post = postSnap.data();
    final batch = FirebaseFirestore.instance.batch();
    final ref = _comments(postId).doc();
    batch.set(ref, {
      'authorUid': uid,
      'authorName': authorName ?? AuthService.instance.greetingName,
      'authorAvatarUrl': authorAvatarUrl,
      'body': text,
      'imageUrl': imageUrl,
      'likeCount': 0,
      'replyCount': 0,
      'reactions': <String, int>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_doc(postId), {'commentCount': FieldValue.increment(1)});
    final authorUid = post?['authorUid'] as String?;
    if (authorUid != null && authorUid.isNotEmpty && authorUid != uid) {
      batch.set(
        NotificationService.instance.docFor(authorUid),
        NotificationService.instance.data(
          recipientUid: authorUid,
          actorUid: uid,
          actorName: authorName ?? AuthService.instance.greetingName,
          actorAvatarUrl: authorAvatarUrl ??
              AuthService.instance.currentUser?.photoURL,
          type: NotificationKind.postCommented.value,
          postId: postId,
          commentId: ref.id,
          communityId: post?['communityId'] as String?,
          communityName: post?['communityName'] as String?,
          preview: _snippet(text),
        ),
      );
    }
    await batch.commit();
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_comments(postId).doc(commentId));
    batch.update(_doc(postId), {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  /* --------------------------- Comment actions --------------------------- */

  /// Emojis offered by the reaction picker.
  static const List<String> reactionEmojis = ['❤️', '🔥', '😂', '👏', '😮'];

  Future<void> toggleCommentLike(String postId, String commentId) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final commentRef = _comments(postId).doc(commentId);
    final likeRef = commentRef.collection('likes').doc(uid);
    final snap = await likeRef.get();
    final batch = FirebaseFirestore.instance.batch();
    if (snap.exists) {
      batch.delete(likeRef);
      batch.update(commentRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {'uid': uid, 'at': FieldValue.serverTimestamp()});
      batch.update(commentRef, {'likeCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<bool> hasLikedComment(String postId, String commentId) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    final snap = await _comments(postId)
        .doc(commentId)
        .collection('likes')
        .doc(uid)
        .get();
    return snap.exists;
  }

  Future<String?> getCommentReaction(String postId, String commentId) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    final snap = await _comments(postId)
        .doc(commentId)
        .collection('reactions')
        .doc(uid)
        .get();
    return snap.data()?['emoji'] as String?;
  }

  /// Sets (or clears with `emoji == null`) the caller's single reaction on a
  /// comment and keeps the `reactions` tally on the comment doc in sync.
  Future<void> reactToComment(
    String postId,
    String commentId,
    String? emoji,
  ) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final commentRef = _comments(postId).doc(commentId);
    final reactionRef = commentRef.collection('reactions').doc(uid);

    final mySnap = await reactionRef.get();
    final current = mySnap.data()?['emoji'] as String?;
    if (current == emoji) return;

    final commentSnap = await commentRef.get();
    final reactions = Map<String, dynamic>.from(
      (commentSnap.data()?['reactions'] as Map?) ?? const {},
    );

    final batch = FirebaseFirestore.instance.batch();
    final update = <String, dynamic>{};

    if (current != null) {
      final count = (reactions[current] as num?)?.toInt() ?? 0;
      if (count <= 1) {
        update['reactions.$current'] = FieldValue.delete();
      } else {
        update['reactions.$current'] = FieldValue.increment(-1);
      }
      batch.delete(reactionRef);
    }
    if (emoji != null) {
      update['reactions.$emoji'] = FieldValue.increment(1);
      batch.set(reactionRef, {
        'uid': uid,
        'emoji': emoji,
        'at': FieldValue.serverTimestamp(),
      });
    }
    if (update.isEmpty) return;
    batch.update(commentRef, update);
    await batch.commit();
  }

  Future<void> addReply(
    String postId,
    String commentId,
    String body, {
    String? imageUrl,
    String? authorName,
    String? authorAvatarUrl,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) throw StateError('Sign in required.');
    final text = body.trim();
    if (text.isEmpty && imageUrl == null) return;
    final commentRef = _comments(postId).doc(commentId);
    final commentSnap = await commentRef.get();
    final postSnap = await _doc(postId).get();
    final post = postSnap.data();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(commentRef.collection('replies').doc(), {
      'authorUid': uid,
      'authorName': authorName ?? AuthService.instance.greetingName,
      'authorAvatarUrl': authorAvatarUrl,
      'body': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(commentRef, {'replyCount': FieldValue.increment(1)});
    final commentAuthor = commentSnap.data()?['authorUid'] as String?;
    if (commentAuthor != null && commentAuthor.isNotEmpty && commentAuthor != uid) {
      batch.set(
        NotificationService.instance.docFor(commentAuthor),
        NotificationService.instance.data(
          recipientUid: commentAuthor,
          actorUid: uid,
          actorName: authorName ?? AuthService.instance.greetingName,
          actorAvatarUrl: authorAvatarUrl ??
              AuthService.instance.currentUser?.photoURL,
          type: NotificationKind.commentReplied.value,
          postId: postId,
          commentId: commentId,
          communityId: post?['communityId'] as String?,
          communityName: post?['communityName'] as String?,
          preview: _snippet(text),
        ),
      );
    }
    await batch.commit();
  }

  Stream<List<PostCommentDoc>> watchReplies(
    String postId,
    String commentId, {
    int limit = 50,
  }) {
    if (!_ready) return onceStream(const []);
    return _comments(postId)
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PostCommentDoc.fromDoc).toList());
  }

  Future<void> deleteReply(String postId, String commentId, String replyId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_comments(postId).doc(commentId).collection('replies').doc(replyId));
    batch.update(
      _comments(postId).doc(commentId),
      {'replyCount': FieldValue.increment(-1)},
    );
    await batch.commit();
  }
}
