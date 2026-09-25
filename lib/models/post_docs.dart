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
    this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String body;
  final String? imageUrl;
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
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'body': body,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
