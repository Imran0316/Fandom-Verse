import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationKind {
  postLiked('post_liked'),
  postCommented('post_commented'),
  commentReplied('comment_replied'),
  followRequested('follow_requested'),
  unknown('');

  const NotificationKind(this.value);

  final String value;

  static NotificationKind fromString(String? raw) =>
      NotificationKind.values.firstWhere(
        (k) => k.value == raw,
        orElse: () => NotificationKind.unknown,
      );
}

/// One entry in `users/{uid}/notifications` — created by the actor who
/// triggered it (like / comment / reply / follow request) and managed
/// only by the recipient.
class NotificationDoc {
  const NotificationDoc({
    required this.id,
    required this.recipientUid,
    required this.actorUid,
    this.actorName = '',
    this.actorAvatarUrl,
    this.type = '',
    this.postId,
    this.commentId,
    this.communityId,
    this.communityName,
    this.preview,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String recipientUid;
  final String actorUid;
  final String actorName;
  final String? actorAvatarUrl;
  final String type;
  final String? postId;
  final String? commentId;
  final String? communityId;
  final String? communityName;
  final String? preview;
  final bool read;
  final DateTime? createdAt;

  NotificationKind get kind => NotificationKind.fromString(type);

  factory NotificationDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    return NotificationDoc(
      id: doc.id,
      recipientUid: (data['recipientUid'] as String?) ?? '',
      actorUid: (data['actorUid'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? '',
      actorAvatarUrl: data['actorAvatarUrl'] as String?,
      type: (data['type'] as String?) ?? '',
      postId: data['postId'] as String?,
      commentId: data['commentId'] as String?,
      communityId: data['communityId'] as String?,
      communityName: data['communityName'] as String?,
      preview: data['preview'] as String?,
      read: (data['read'] as bool?) ?? false,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
