import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/post_docs.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../widgets/liquid_glass.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onChanged,
    this.showCommunityChip = true,
  });

  final PostDoc post;
  final VoidCallback? onChanged;
  final bool showCommunityChip;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _liked = false;
  bool _reposted = false;
  bool _showComments = false;
  final _commentController = TextEditingController();
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    final pid = widget.post.id;
    PostService.instance.watchLiked(pid).listen((v) {
      if (mounted && _liked != v) setState(() => _liked = v);
    });
    PostService.instance.watchReposted(pid).listen((v) {
      if (mounted && _reposted != v) setState(() => _reposted = v);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _timeLabel(DateTime? at) {
    if (at == null) return 'now';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${at.month}/${at.day}/${at.year}';
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await PostService.instance.addComment(
        widget.post.id,
        text,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
      );
      _commentController.clear();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isSelf =
        post.authorUid == AuthService.instance.currentUser?.uid;
    final isAdminSelf = isSelf; // delete own post; admin delete via panel

    return LiquidGlass(
      radius: 18,
      blur: 22,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (post.authorUid.isEmpty) return;
                  Navigator.pushNamed(
                    context,
                    '/user-profile',
                    arguments: post.authorUid,
                  );
                },
                child: Hero(
                  tag: 'avatar-${post.authorUid}-${post.id}',
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: post.authorAvatarUrl?.isNotEmpty == true
                        ? Image.network(
                            post.authorAvatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 20),
                          )
                        : Center(
                            child: Text(
                              (post.authorName.isNotEmpty
                                      ? post.authorName.characters.first
                                      : '?')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName.isEmpty ? 'Fan' : post.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _timeLabel(post.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showCommunityChip &&
                  post.communityName != null &&
                  post.communityName!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.primary.withValues(alpha: 0.25),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    post.communityName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (isAdminSelf)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  color: const Color(0xFF1A1A22),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A22),
                          title: const Text(
                            'Delete post?',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'This cannot be undone.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Color(0xFFFF6B6B)),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await PostService.instance.deletePost(post.id);
                        widget.onChanged?.call();
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ActionChip(
                icon: _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likeCount}',
                active: _liked,
                activeColor: AppColors.primary,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await PostService.instance.toggleLike(post.id);
                    widget.onChanged?.call();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentCount}',
                onTap: () => setState(() => _showComments = !_showComments),
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.repeat_rounded,
                label: '${post.repostCount}',
                active: _reposted,
                activeColor: const Color(0xFF10B981),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await PostService.instance.toggleRepost(post.id);
                    widget.onChanged?.call();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
              ),
            ],
          ),
          if (_showComments) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            StreamBuilder<List<PostCommentDoc>>(
              stream: PostService.instance.watchComments(post.id),
              builder: (context, snap) {
                final comments = snap.data ?? const <PostCommentDoc>[];
                if (comments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.white38, fontSize: 12.5),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final c in comments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  (c.authorName.isNotEmpty
                                          ? c.authorName.characters.first
                                          : '?')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.authorName.isEmpty ? 'Fan' : c.authorName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    c.body,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendingComment ? null : _sendComment,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                  ),
                  icon: _sendingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? AppColors.primary) : Colors.white60;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
