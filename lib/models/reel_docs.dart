import 'package:cloud_firestore/cloud_firestore.dart';

/// A community short video hosted on Cloudinary.
class ReelDoc {
  const ReelDoc({
    required this.id,
    required this.authorUid,
    required this.videoUrl,
    this.authorName = '',
    this.authorAvatarUrl,
    this.caption = '',
    this.communityId,
    this.communityName,
    this.thumbnailUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String caption;
  final String? communityId;
  final String? communityName;
  final String videoUrl;
  final String? thumbnailUrl;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;

  factory ReelDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    return ReelDoc(
      id: doc.id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      caption: (data['caption'] as String?) ?? '',
      communityId: data['communityId'] as String?,
      communityName: data['communityName'] as String?,
      videoUrl: (data['videoUrl'] as String?) ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'caption': caption,
        'communityId': communityId,
        'communityName': communityName,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}

/// A comment on a reel (`reels/{reelId}/comments/{commentId}`).
class ReelCommentDoc {
  const ReelCommentDoc({
    required this.id,
    required this.authorUid,
    this.authorName = '',
    this.authorAvatarUrl,
    this.body = '',
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String body;
  final DateTime? createdAt;

  factory ReelCommentDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    return ReelCommentDoc(
      id: doc.id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      body: (data['body'] as String?) ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
