import 'package:cloud_firestore/cloud_firestore.dart';

class PostDoc {
  const PostDoc({
    required this.id,
    required this.authorUid,
    this.authorName = '',
    this.authorAvatarUrl,
    this.body = '',
    this.communityId,
    this.communityName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.repostCount = 0,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String body;
  final String? communityId;
  final String? communityName;
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final String? imageUrl;
  final DateTime? createdAt;

  factory PostDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    return PostDoc(
      id: doc.id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      body: (data['body'] as String?) ?? '',
      communityId: data['communityId'] as String?,
      communityName: data['communityName'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      repostCount: (data['repostCount'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'body': body,
        'communityId': communityId,
        'communityName': communityName,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'repostCount': repostCount,
        'imageUrl': imageUrl,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}

class PostCommentDoc {
  const PostCommentDoc({
    required this.id,
    required this.authorUid,
    this.authorName = '',
    this.authorAvatarUrl,
    this.body = '',
    this.imageUrl,
    this.likeCount = 0,
    this.replyCount = 0,
    this.reactions = const {},
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String body;
  final String? imageUrl;
  final int likeCount;

  /// Nested replies (posts/{postId}/comments/{commentId}/replies).
  final int replyCount;

  /// Emoji → tally, e.g. {'\u{1F525}': 2}. Stored on the comment doc so the
  /// counts ride along with the existing comments stream (no extra listeners).
  final Map<String, int> reactions;
  final DateTime? createdAt;

  factory PostCommentDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    return PostCommentDoc(
      id: doc.id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      body: (data['body'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      reactions: _intMap(data['reactions']),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'body': body,
        'imageUrl': imageUrl,
        'likeCount': likeCount,
        'replyCount': replyCount,
        'reactions': reactions,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

Map<String, int> _intMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.key is String && e.value is num)
        e.key as String: (e.value as num).toInt(),
  };
}
