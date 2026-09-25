import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../models/post_docs.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/post_service.dart';
import '../../widgets/expandable_text.dart';
import '../../widgets/gif_picker.dart';
import '../../widgets/image_viewer.dart';
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
  String? _commentImageUrl;
  bool _uploadingCommentMedia = false;
  StreamSubscription<bool>? _likeSub;
  StreamSubscription<bool>? _repostSub;

  @override
  void initState() {
    super.initState();
    final pid = widget.post.id;
    _likeSub = PostService.instance.watchLiked(pid).listen((v) {
      if (mounted && _liked != v) setState(() => _liked = v);
    });
    _repostSub = PostService.instance.watchReposted(pid).listen((v) {
      if (mounted && _reposted != v) setState(() => _reposted = v);
    });
  }

  @override
  void dispose() {
    _likeSub?.cancel();
    _repostSub?.cancel();
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
    if (text.isEmpty && _commentImageUrl == null) return;
    setState(() => _sendingComment = true);
    try {
      await PostService.instance.addComment(
        widget.post.id,
        text,
        imageUrl: _commentImageUrl,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
      );
      _commentController.clear();
      _commentImageUrl = null;
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

  Future<void> _pickCommentImage() async {
    if (_uploadingCommentMedia) return;
    setState(() => _uploadingCommentMedia = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'comment',
      );
      if (url != null && mounted) setState(() => _commentImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ImageUploadService.friendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCommentMedia = false);
    }
  }

  Future<void> _pickCommentGif() async {
    if (_uploadingCommentMedia) return;
    setState(() => _uploadingCommentMedia = true);
    try {
      final url = await GifPicker.show(context);
      if (url != null && mounted) setState(() => _commentImageUrl = url);
    } finally {
      if (mounted) setState(() => _uploadingCommentMedia = false);
    }
  }

  void _share() {
    final post = widget.post;
    final text = post.body.trim().isNotEmpty
        ? post.body.trim()
        : (post.imageUrl ?? '');
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post copied to clipboard')),
      );
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
          if (post.body.isNotEmpty) ...[
            ExpandableText(
              text: post.body,
              maxLines: 2,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => openImageViewer(context, post.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 260,
                  child: Image.network(
                    post.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress ==
                            null
                        ? child
                        : Container(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white30,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
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
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: _share,
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
                    for (final c in comments) _CommentTile(comment: c),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  if (_commentImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Image.network(
                                _commentImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Attachment ready',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _commentImageUrl = null),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
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
                              borderSide:
                                  const BorderSide(color: AppColors.accent),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap:
                            _uploadingCommentMedia ? null : _pickCommentGif,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.14),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            'GIF',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _uploadingCommentMedia
                            ? null
                            : _pickCommentImage,
                        child: LiquidGlassPill(
                          radius: 999,
                          blur: 12,
                          padding: const EdgeInsets.all(8),
                          child: _uploadingCommentMedia
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                )
                              : const Icon(
                                  Icons.image_outlined,
                                  size: 17,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _sendingComment ? null : _sendComment,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Center(
                            child: _sendingComment
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final PostCommentDoc comment;

  @override
  Widget build(BuildContext context) {
    final c = comment;
    final initial = (c.authorName.isNotEmpty
            ? c.authorName.characters.first
            : '?')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: c.authorAvatarUrl?.isNotEmpty == true
                ? Image.network(
                    c.authorAvatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
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
                if (c.body.isNotEmpty)
                  ExpandableText(
                    text: c.body,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => openImageViewer(context, c.imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 190,
                        height: 140,
                        child: Image.network(
                          c.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.white.withValues(alpha: 0.06),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white30,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
