import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/notification_docs.dart';
import '../../services/notification_service.dart';
import '../../services/stream_cache.dart';
import '../../services/user_service.dart';
import '../content/content_detail_screen.dart';

/// Real activity feed: likes, comments and replies on your posts, plus
/// follow requests (accept / decline inline). Rows are live; tapping a
/// row marks it read and jumps to the content it came from.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _items = StreamCache<List<NotificationDoc>>(
    () => NotificationService.instance.watch(),
  );
  final Set<String> _busyIds = {};

  String _timeLabel(DateTime? at) {
    if (at == null) return 'now';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${at.month}/${at.day}/${at.year}';
  }

  String _actionText(NotificationDoc n) {
    if (n.title != null && n.title!.isNotEmpty) return n.title!;
    final name = n.actorName.isEmpty ? 'Fandom Verse' : n.actorName;
    switch (n.notificationType) {
      case NotificationType.contentPublished:
      case NotificationType.fandomContent:
        return 'New $name update';
      case NotificationType.communityAnnouncement:
        return 'Community update';
      case NotificationType.adminAnnouncement:
        return 'Platform update';
      case NotificationType.system:
        return 'Fandom Verse';
      case NotificationType.postLiked:
        return '$name liked your post';
      case NotificationType.postCommented:
        return '$name commented on your post';
      case NotificationType.commentReplied:
        return '$name replied to your comment';
      case NotificationType.followRequested:
        return '$name requested to follow you';
      case NotificationType.unknown:
        return 'Activity update';
    }
  }

  Future<void> _accept(NotificationDoc n) async {
    if (_busyIds.contains(n.id)) return;
    setState(() => _busyIds.add(n.id));
    try {
      await UserService.instance.acceptFollowRequest(n.actorUid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(n.id));
    }
  }

  Future<void> _decline(NotificationDoc n) async {
    if (_busyIds.contains(n.id)) return;
    setState(() => _busyIds.add(n.id));
    try {
      await UserService.instance.declineFollowRequest(n.actorUid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(n.id));
    }
  }

  void _open(NotificationDoc n) {
    NotificationService.instance.markRead(n.id);
    if (n.kind == NotificationKind.followRequested) {
      Navigator.pushNamed(context, AppRoutes.followRequests);
      return;
    }
    if ((n.targetType ?? NotificationTargetType.system) ==
            NotificationTargetType.content ||
        n.contentId != null && n.contentId!.isNotEmpty) {
      final contentId = n.contentId ?? n.targetId;
      if (contentId != null && contentId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          AppRoutes.contentDetail,
          arguments: ContentDetailArgs(contentId: contentId),
        );
        return;
      }
    }
    if (n.communityId != null && n.communityId!.isNotEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.communityDetail,
        arguments: n.communityId,
      );
      return;
    }
    if (n.targetType == NotificationTargetType.announcement ||
        n.notificationType == NotificationType.adminAnnouncement) {
      Navigator.pushNamed(context, AppRoutes.dashboard);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<List<NotificationDoc>>(
            stream: _items(),
            builder: (context, snap) {
              final items = snap.data ?? const <NotificationDoc>[];
              final unread = items.where((n) => !n.read).length;
              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            TextButton(
                              onPressed: () => NotificationService.instance
                                  .markAllRead(items),
                              child: const Text(
                                'Mark all read',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? _empty()
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) =>
                                  _tile(context, items[i]),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: Colors.white24,
              size: 46,
            ),
            SizedBox(height: 14),
            Text(
              "You're all caught up",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'New fandom discoveries and community updates land here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, NotificationDoc n) {
    final busy = _busyIds.contains(n.id);
    final isFollow = n.kind == NotificationKind.followRequested;
    return GestureDetector(
      onTap: () => _open(n),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: n.read
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.primary.withValues(alpha: 0.12),
          border: Border.all(
            color: n.read
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(n),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _actionText(n),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if ((n.preview ?? n.effectiveBody).isNotEmpty &&
                      !isFollow) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.effectiveBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _timeLabel(n.createdAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isFollow)
              busy
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _miniButton(label: 'Accept', onTap: () => _accept(n)),
                        const SizedBox(height: 6),
                        _miniButton(
                          label: 'Decline',
                          onTap: () => _decline(n),
                          ghost: true,
                        ),
                      ],
                    )
            else if (!n.read)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniButton({
    required String label,
    required VoidCallback onTap,
    bool ghost = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: ghost
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
                ),
          color: ghost ? Colors.white.withValues(alpha: 0.07) : null,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ghost ? Colors.white70 : Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _avatar(NotificationDoc n) {
    final initial = n.actorName.isNotEmpty
        ? n.actorName.characters.first.toUpperCase()
        : '?';
    final icon = switch (n.notificationType) {
      NotificationType.contentPublished => Icons.new_releases_rounded,
      NotificationType.fandomContent => Icons.explore_rounded,
      NotificationType.communityAnnouncement => Icons.groups_rounded,
      NotificationType.adminAnnouncement => Icons.campaign_rounded,
      NotificationType.system => Icons.notifications_rounded,
      NotificationType.postLiked => Icons.favorite_rounded,
      NotificationType.postCommented => Icons.mode_comment_rounded,
      NotificationType.commentReplied => Icons.reply_rounded,
      NotificationType.followRequested => Icons.person_add_alt_1_rounded,
      NotificationType.unknown => Icons.notifications_rounded,
    };
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.primary.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: n.actorAvatarUrl?.isNotEmpty == true
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  n.actorAvatarUrl!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14141C),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 11, color: Colors.white),
                  ),
                ),
              ],
            )
          : Center(child: Icon(icon, color: Colors.white, size: 19)),
    );
  }
}
