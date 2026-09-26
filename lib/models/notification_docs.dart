import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  contentPublished('contentPublished'),
  fandomContent('fandomContent'),
  communityAnnouncement('communityAnnouncement'),
  adminAnnouncement('adminAnnouncement'),
  system('system'),
  postLiked('post_liked'),
  postCommented('post_commented'),
  commentReplied('comment_replied'),
  followRequested('follow_requested'),
  unknown('');

  const NotificationType(this.value);

  final String value;

  static NotificationType fromString(String? raw) {
    switch (raw) {
      case 'contentPublished':
        return NotificationType.contentPublished;
      case 'fandomContent':
        return NotificationType.fandomContent;
      case 'communityAnnouncement':
        return NotificationType.communityAnnouncement;
      case 'adminAnnouncement':
        return NotificationType.adminAnnouncement;
      case 'post_liked':
        return NotificationType.postLiked;
      case 'post_commented':
        return NotificationType.postCommented;
      case 'comment_replied':
        return NotificationType.commentReplied;
      case 'follow_requested':
        return NotificationType.followRequested;
      case 'system':
      case 'unknown':
      default:
        return NotificationType.system;
    }
  }
}

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

enum NotificationTargetType {
  content,
  community,
  announcement,
  profile,
  system,
}

/// One entry in `users/{uid}/notifications`.
/// The app now supports content/community/admin notifications while keeping
/// the older social notification payloads readable for compatibility.
class NotificationDoc {
  const NotificationDoc({
    required this.id,
    required this.recipientUid,
    required this.actorUid,
    this.actorName = '',
    this.actorAvatarUrl,
    this.type = '',
    this.title,
    this.body,
    this.imageUrl,
    this.postId,
    this.commentId,
    this.communityId,
    this.communityName,
    this.preview,
    this.targetType,
    this.targetId,
    this.contentId,
    this.fandomId,
    this.priority,
    this.data = const {},
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String recipientUid;
  final String actorUid;
  final String actorName;
  final String? actorAvatarUrl;
  final String type;
  final String? title;
  final String? body;
  final String? imageUrl;
  final String? postId;
  final String? commentId;
  final String? communityId;
  final String? communityName;
  final String? preview;
  final NotificationTargetType? targetType;
  final String? targetId;
  final String? contentId;
  final String? fandomId;
  final String? priority;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? createdAt;

  NotificationType get notificationType => NotificationType.fromString(type);
  NotificationKind get kind => NotificationKind.fromString(type);
  bool get isRead => read;

  String get effectiveTitle => title ?? _fallbackTitle;
  String get effectiveBody => body ?? preview ?? _fallbackBody;

  String get _fallbackTitle {
    switch (notificationType) {
      case NotificationType.contentPublished:
        return 'New discovery';
      case NotificationType.fandomContent:
        return 'New fandom update';
      case NotificationType.communityAnnouncement:
        return 'Community update';
      case NotificationType.adminAnnouncement:
        return 'Fandom Verse update';
      case NotificationType.system:
        return 'Fandom Verse';
      case NotificationType.postLiked:
        return 'Someone liked your post';
      case NotificationType.postCommented:
        return 'Someone commented';
      case NotificationType.commentReplied:
        return 'Someone replied';
      case NotificationType.followRequested:
        return 'New follow request';
      case NotificationType.unknown:
        return 'Activity';
    }
  }

  String get _fallbackBody {
    switch (notificationType) {
      case NotificationType.contentPublished:
        return 'A new story has been published.';
      case NotificationType.fandomContent:
        return 'Fresh fandom content is now live.';
      case NotificationType.communityAnnouncement:
        return 'A community update is waiting for you.';
      case NotificationType.adminAnnouncement:
        return 'There is an important platform update.';
      case NotificationType.system:
        return 'Check out what is new.';
      case NotificationType.postLiked:
        return 'Your post gained a new reaction.';
      case NotificationType.postCommented:
        return 'A new comment was added to your post.';
      case NotificationType.commentReplied:
        return 'A reply was posted to your comment.';
      case NotificationType.followRequested:
        return 'A fan wants to follow you.';
      case NotificationType.unknown:
        return 'There is new activity.';
    }
  }

  factory NotificationDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    final rawType = data['targetType'] ?? data['type'];
    final rawTargetType = data['targetType'] as String?;
    NotificationTargetType? targetType;
    switch (rawTargetType) {
      case 'content':
        targetType = NotificationTargetType.content;
        break;
      case 'community':
        targetType = NotificationTargetType.community;
        break;
      case 'announcement':
        targetType = NotificationTargetType.announcement;
        break;
      case 'profile':
        targetType = NotificationTargetType.profile;
        break;
      default:
        targetType = null;
    }

    return NotificationDoc(
      id: doc.id,
      recipientUid: (data['recipientUid'] as String?) ?? '',
      actorUid: (data['actorUid'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? '',
      actorAvatarUrl: data['actorAvatarUrl'] as String?,
      type: (data['type'] as String?) ?? rawType ?? '',
      title: data['title'] as String?,
      body: data['body'] as String?,
      imageUrl: data['imageUrl'] as String?,
      postId: data['postId'] as String?,
      commentId: data['commentId'] as String?,
      communityId:
          (data['communityId'] as String?) ?? (data['communityId'] as String?),
      communityName: data['communityName'] as String?,
      preview: (data['preview'] as String?) ?? data['body'] as String?,
      targetType: targetType,
      targetId: data['targetId'] as String?,
      contentId: (data['contentId'] as String?) ?? data['postId'] as String?,
      fandomId: data['fandomId'] as String?,
      priority: data['priority'] as String?,
      data: Map<String, dynamic>.from(data['data'] as Map? ?? const {}),
      read: (data['read'] as bool?) ?? (data['isRead'] as bool?) ?? false,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
